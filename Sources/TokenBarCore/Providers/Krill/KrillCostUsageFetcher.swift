#if os(macOS)
import Foundation

/// Builds TokenBar's Cost chart data from Krill's internal request-log stats API.
///
/// Krill exposes exact aggregate cost/tokens for a requested range, plus an
/// adaptive trend series. It does not currently expose a cheap per-model cost
/// breakdown. Keep this fetcher deliberately lightweight: one rolling-range
/// request for 30-day totals/chart trend, plus one today request so the Today
/// number remains calendar-day accurate without paginating raw logs.
public enum KrillCostUsageFetcher: Sendable {
    private static let historyDays = 30

    public static func loadTokenSnapshot(now: Date = Date()) async throws -> CostUsageTokenSnapshot {
        guard let jwt = await MainActor.run(
            resultType: String?.self,
            body: { KrillJWTManager.shared.getStoredJWT() })
        else {
            throw KrillAPIError.missingJWT
        }

        let report = try await self.loadDailyReport(jwt: jwt, now: now)
        return CostUsageFetcher.tokenSnapshot(from: report, now: now)
    }

    static func loadDailyReport(jwt: String, now: Date = Date()) async throws -> CostUsageDailyReport {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)
        let sinceStart = calendar.date(
            byAdding: .day,
            value: -(Self.historyDays - 1),
            to: todayStart) ?? todayStart

        async let rollingStatsResponse = KrillAPIClient.fetchStats(
            jwt: jwt,
            startTime: sinceStart,
            endTime: now)
        async let todayStatsResponse = KrillAPIClient.fetchStats(
            jwt: jwt,
            startTime: todayStart,
            endTime: now)

        let (rollingResponse, todayResponse) = try await (rollingStatsResponse, todayStatsResponse)
        guard let rollingStats = rollingResponse.data else {
            return CostUsageDailyReport(data: [], summary: nil)
        }

        var entries = self.entries(from: rollingStats.trend ?? [], calendar: calendar)
        if entries.isEmpty,
           let fallback = self.entry(dayStart: sinceStart, stats: rollingStats, calendar: calendar)
        {
            entries.append(fallback)
        }

        if let todayStats = todayResponse.data,
           let todayEntry = self.entry(dayStart: todayStart, stats: todayStats, calendar: calendar)
        {
            entries.removeAll { $0.date == todayEntry.date }
            entries.append(todayEntry)
        }

        entries.sort { $0.date < $1.date }

        return CostUsageDailyReport(
            data: entries,
            summary: self.summary(from: rollingStats) ?? self.summary(from: entries))
    }

    static func entry(
        dayStart: Date,
        stats: KrillStatsResponse.KrillStatsData,
        calendar: Calendar = .current) -> CostUsageDailyReport.Entry?
    {
        let cost = self.doubleValue(stats.total_cost_usd)
        let totalTokens = stats.total_tokens
        let requestCount = stats.total_requests ?? 0

        guard requestCount > 0 || (totalTokens ?? 0) > 0 || (cost ?? 0) > 0 else {
            return nil
        }

        return CostUsageDailyReport.Entry(
            date: self.dayKey(for: dayStart, calendar: calendar),
            inputTokens: stats.input_tokens,
            outputTokens: stats.output_tokens,
            cacheReadTokens: stats.cache_read_input_tokens,
            cacheCreationTokens: stats.cache_creation_input_tokens,
            totalTokens: totalTokens,
            costUSD: cost,
            modelsUsed: nil,
            modelBreakdowns: nil)
    }

    static func entries(
        from trend: [KrillStatsResponse.KrillStatsData.KrillTrendBucket],
        calendar: Calendar = .current) -> [CostUsageDailyReport.Entry]
    {
        struct BucketTotals {
            var requestCount = 0
            var totalTokens = 0
            var sawTokens = false
            var costUSD = 0.0
            var sawCost = false
        }

        var totalsByDay: [String: BucketTotals] = [:]
        for bucket in trend {
            guard let bucketStart = bucket.bucket_start,
                  let date = self.date(from: bucketStart)
            else { continue }

            let tokens = bucket.total_tokens
            let cost = self.doubleValue(bucket.total_cost_usd)
            let requestCount = bucket.request_count ?? 0
            guard requestCount > 0 || (tokens ?? 0) > 0 || (cost ?? 0) > 0 else {
                continue
            }

            let key = self.dayKey(for: date, calendar: calendar)
            var totals = totalsByDay[key] ?? BucketTotals()
            totals.requestCount += requestCount
            if let tokens {
                totals.totalTokens += tokens
                totals.sawTokens = true
            }
            if let cost {
                totals.costUSD += cost
                totals.sawCost = true
            }
            totalsByDay[key] = totals
        }

        return totalsByDay.keys.sorted().compactMap { key in
            guard let totals = totalsByDay[key] else { return nil }
            return CostUsageDailyReport.Entry(
                date: key,
                inputTokens: nil,
                outputTokens: nil,
                cacheReadTokens: nil,
                cacheCreationTokens: nil,
                totalTokens: totals.sawTokens ? totals.totalTokens : nil,
                costUSD: totals.sawCost ? totals.costUSD : nil,
                modelsUsed: nil,
                modelBreakdowns: nil)
        }
    }

    private static func summary(from stats: KrillStatsResponse.KrillStatsData) -> CostUsageDailyReport.Summary? {
        let cost = self.doubleValue(stats.total_cost_usd)
        guard (stats.total_requests ?? 0) > 0
            || (stats.total_tokens ?? 0) > 0
            || (cost ?? 0) > 0
        else {
            return nil
        }

        return CostUsageDailyReport.Summary(
            totalInputTokens: stats.input_tokens,
            totalOutputTokens: stats.output_tokens,
            cacheReadTokens: stats.cache_read_input_tokens,
            cacheCreationTokens: stats.cache_creation_input_tokens,
            totalTokens: stats.total_tokens,
            totalCostUSD: cost)
    }

    private static func summary(from entries: [CostUsageDailyReport.Entry]) -> CostUsageDailyReport.Summary? {
        guard !entries.isEmpty else { return nil }

        return CostUsageDailyReport.Summary(
            totalInputTokens: self.sum(entries.map(\.inputTokens)),
            totalOutputTokens: self.sum(entries.map(\.outputTokens)),
            cacheReadTokens: self.sum(entries.map(\.cacheReadTokens)),
            cacheCreationTokens: self.sum(entries.map(\.cacheCreationTokens)),
            totalTokens: self.sum(entries.map(\.totalTokens)),
            totalCostUSD: self.sumDoubles(entries.map(\.costUSD)))
    }

    private static func sum(_ values: [Int?]) -> Int? {
        var total = 0
        var sawValue = false
        for value in values {
            guard let value else { continue }
            total += value
            sawValue = true
        }
        return sawValue ? total : nil
    }

    private static func sumDoubles(_ values: [Double?]) -> Double? {
        var total = 0.0
        var sawValue = false
        for value in values {
            guard let value else { continue }
            total += value
            sawValue = true
        }
        return sawValue ? total : nil
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            comps.year ?? 1970,
            comps.month ?? 1,
            comps.day ?? 1)
    }

    private static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func doubleValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
#endif
