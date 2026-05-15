#if os(macOS)
import Foundation

/// Builds TokenBar's Cost chart data from Krill's internal request-log stats API.
///
/// Krill exposes exact aggregate cost/tokens for a requested range, plus an
/// adaptive trend series. The normal history path stays lightweight: one
/// rolling-range request for 30-day totals/chart trend, plus one today request
/// so the Today number remains calendar-day accurate. Today's hover details use
/// Krill's aggregate model-stats endpoint first, then fall back to capped raw-log
/// pagination only if that endpoint is unavailable.
public enum KrillCostUsageFetcher: Sendable {
    private static let historyDays = 30
    private static let todayBreakdownPageSize = 100
    private static let todayBreakdownMaxPages = 80
    private static let todayBreakdownCacheTTL: TimeInterval = 10 * 60
    private static let historicalBreakdownCacheTTL: TimeInterval = 6 * 60 * 60
    private static let modelBreakdownCache = KrillModelBreakdownCache()

    private static var todayBreakdownMaxItems: Int {
        self.todayBreakdownPageSize * self.todayBreakdownMaxPages
    }

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

    public static func loadModelBreakdowns(
        dayKey: String,
        now: Date = Date(),
        calendar: Calendar = .current) async throws -> [CostUsageDailyReport.ModelBreakdown]?
    {
        guard let jwt = await MainActor.run(
            resultType: String?.self,
            body: { KrillJWTManager.shared.getStoredJWT() })
        else {
            throw KrillAPIError.missingJWT
        }

        return try await self.loadModelBreakdowns(
            jwt: jwt,
            dayKey: dayKey,
            now: now,
            calendar: calendar)
    }

    static func loadModelBreakdowns(
        jwt: String,
        dayKey: String,
        now: Date = Date(),
        calendar: Calendar = .current) async throws -> [CostUsageDailyReport.ModelBreakdown]?
    {
        guard let range = self.dayRange(for: dayKey, now: now, calendar: calendar) else { return nil }
        let ttl = calendar.isDate(range.startTime, inSameDayAs: now)
            ? self.todayBreakdownCacheTTL
            : self.historicalBreakdownCacheTTL
        if let cached = await self.modelBreakdownCache.lookup(dayKey: dayKey, now: now, ttl: ttl) {
            return cached.breakdowns
        }

        let breakdowns = try await self.fetchTodayModelBreakdowns(
            jwt: jwt,
            startTime: range.startTime,
            endTime: range.endTime)
        let result = self.nonEmptyBreakdowns(breakdowns)
        await self.modelBreakdownCache.store(dayKey: dayKey, now: now, breakdowns: result)
        return result
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

        if let todayStats = todayResponse.data {
            let modelBreakdowns = await self.todayModelBreakdowns(
                jwt: jwt,
                dayStart: todayStart,
                now: now,
                stats: todayStats,
                calendar: calendar)
            if let todayEntry = self.entry(
                dayStart: todayStart,
                stats: todayStats,
                calendar: calendar,
                modelBreakdowns: modelBreakdowns)
            {
                entries.removeAll { $0.date == todayEntry.date }
                entries.append(todayEntry)
            }
        }

        entries.sort { $0.date < $1.date }

        return CostUsageDailyReport(
            data: entries,
            summary: self.summary(from: rollingStats) ?? self.summary(from: entries))
    }

    static func entry(
        dayStart: Date,
        stats: KrillStatsResponse.KrillStatsData,
        calendar: Calendar = .current,
        modelBreakdowns: [CostUsageDailyReport.ModelBreakdown]? = nil) -> CostUsageDailyReport.Entry?
    {
        let cost = self.doubleValue(stats.total_cost_usd)
        let totalTokens = stats.total_tokens
        let requestCount = stats.total_requests ?? 0

        guard requestCount > 0 || (totalTokens ?? 0) > 0 || (cost ?? 0) > 0 else {
            return nil
        }

        let breakdowns = self.nonEmptyBreakdowns(modelBreakdowns)
        return CostUsageDailyReport.Entry(
            date: self.dayKey(for: dayStart, calendar: calendar),
            inputTokens: stats.input_tokens,
            outputTokens: stats.output_tokens,
            cacheReadTokens: stats.cache_read_input_tokens,
            cacheCreationTokens: stats.cache_creation_input_tokens,
            totalTokens: totalTokens,
            costUSD: cost,
            modelsUsed: breakdowns?.map(\.modelName).sorted(),
            modelBreakdowns: breakdowns)
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

    static func fetchTodayModelBreakdowns(
        jwt: String,
        startTime: Date,
        endTime: Date,
        expectedRequestCount: Int? = nil) async throws -> [CostUsageDailyReport.ModelBreakdown]?
    {
        if let modelStatsBreakdowns = try? await self.fetchModelStatsBreakdowns(
            jwt: jwt,
            startTime: startTime,
            endTime: endTime)
        {
            return modelStatsBreakdowns
        }

        if let expectedRequestCount,
           expectedRequestCount > self.todayBreakdownMaxItems
        {
            return nil
        }

        var logs: [KrillRequestLogsResponse.KrillRequestLog] = []
        logs.reserveCapacity(min(expectedRequestCount ?? 0, self.todayBreakdownMaxItems))

        for page in 1...self.todayBreakdownMaxPages {
            let response = try await KrillAPIClient.fetchRequestLogs(
                jwt: jwt,
                startTime: startTime,
                endTime: endTime,
                page: page,
                pageSize: self.todayBreakdownPageSize)
            guard let data = response.data else { return nil }

            if let total = data.total,
               total > self.todayBreakdownMaxItems
            {
                return nil
            }

            let items = data.items ?? []
            logs.append(contentsOf: items)

            let serverPageSize = max(data.page_size ?? self.todayBreakdownPageSize, 1)
            if items.isEmpty { break }
            if let total = data.total,
               logs.count >= total
            {
                break
            }
            if items.count < serverPageSize { break }
            if page == self.todayBreakdownMaxPages { return nil }
        }

        return self.nonEmptyBreakdowns(self.modelBreakdowns(from: logs))
    }

    static func fetchModelStatsBreakdowns(
        jwt: String,
        startTime: Date,
        endTime: Date) async throws -> [CostUsageDailyReport.ModelBreakdown]?
    {
        let response = try await KrillAPIClient.fetchModelStats(
            jwt: jwt,
            startTime: startTime,
            endTime: endTime)
        guard response.success,
              let items = response.data?.items
        else { return nil }

        return self.nonEmptyBreakdowns(self.modelBreakdowns(from: items))
    }

    static func modelBreakdowns(
        from modelStats: [KrillModelStatsResponse.KrillModelStat]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        let breakdowns = modelStats.compactMap { item -> CostUsageDailyReport.ModelBreakdown? in
            guard let modelName = item.model?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !modelName.isEmpty,
                  item.total_tokens != nil || item.total_cost_usd != nil
            else { return nil }

            return CostUsageDailyReport.ModelBreakdown(
                modelName: modelName,
                costUSD: item.total_cost_usd,
                totalTokens: item.total_tokens)
        }

        return self.sortedBreakdowns(breakdowns)
    }

    static func modelBreakdowns(
        from logs: [KrillRequestLogsResponse.KrillRequestLog]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        struct ModelTotals {
            var totalTokens = 0
            var sawTokens = false
            var costUSD = 0.0
            var sawCost = false
        }

        var totalsByModel: [String: ModelTotals] = [:]
        for log in logs {
            guard let modelName = self.modelName(from: log) else { continue }
            let tokens = self.totalTokens(from: log)
            let cost = self.costUSD(from: log)
            guard tokens != nil || cost != nil else { continue }

            var totals = totalsByModel[modelName] ?? ModelTotals()
            if let tokens {
                totals.totalTokens += tokens
                totals.sawTokens = true
            }
            if let cost {
                totals.costUSD += cost
                totals.sawCost = true
            }
            totalsByModel[modelName] = totals
        }

        return self.sortedBreakdowns(totalsByModel.map { modelName, totals in
            CostUsageDailyReport.ModelBreakdown(
                modelName: modelName,
                costUSD: totals.sawCost ? totals.costUSD : nil,
                totalTokens: totals.sawTokens ? totals.totalTokens : nil)
        })
    }

    private static func sortedBreakdowns(
        _ breakdowns: [CostUsageDailyReport.ModelBreakdown]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        breakdowns.sorted { lhs, rhs in
            let lhsCost = lhs.costUSD ?? -1
            let rhsCost = rhs.costUSD ?? -1
            if lhsCost != rhsCost { return lhsCost > rhsCost }

            let lhsTokens = lhs.totalTokens ?? -1
            let rhsTokens = rhs.totalTokens ?? -1
            if lhsTokens != rhsTokens { return lhsTokens > rhsTokens }

            return lhs.modelName > rhs.modelName
        }
    }

    private static func todayModelBreakdowns(
        jwt: String,
        dayStart: Date,
        now: Date,
        stats: KrillStatsResponse.KrillStatsData,
        calendar: Calendar) async -> [CostUsageDailyReport.ModelBreakdown]?
    {
        let key = self.dayKey(for: dayStart, calendar: calendar)
        if let cached = await self.modelBreakdownCache.lookup(
            dayKey: key,
            now: now,
            ttl: self.todayBreakdownCacheTTL)
        {
            return cached.breakdowns
        }

        do {
            let breakdowns = try await self.fetchTodayModelBreakdowns(
                jwt: jwt,
                startTime: dayStart,
                endTime: now,
                expectedRequestCount: stats.total_requests)
            let result = self.nonEmptyBreakdowns(breakdowns)
            await self.modelBreakdownCache.store(dayKey: key, now: now, breakdowns: result)
            return result
        } catch {
            await self.modelBreakdownCache.store(dayKey: key, now: now, breakdowns: nil)
            return nil
        }
    }

    private static func nonEmptyBreakdowns(
        _ breakdowns: [CostUsageDailyReport.ModelBreakdown]?) -> [CostUsageDailyReport.ModelBreakdown]?
    {
        guard let breakdowns, !breakdowns.isEmpty else { return nil }
        return breakdowns
    }

    private static func modelName(from log: KrillRequestLogsResponse.KrillRequestLog) -> String? {
        for candidate in [log.actual_model, log.original_model] {
            guard let value = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty
            else { continue }
            return value
        }
        return nil
    }

    private static func totalTokens(from log: KrillRequestLogsResponse.KrillRequestLog) -> Int? {
        if let totalTokens = log.total_tokens { return totalTokens }

        var total = 0
        var sawValue = false
        for value in [
            log.input_tokens,
            log.output_tokens,
            log.cache_read_input_tokens,
            log.cache_creation_input_tokens,
            log.reasoning_tokens,
        ] {
            guard let value else { continue }
            total += value
            sawValue = true
        }
        return sawValue ? total : nil
    }

    private static func costUSD(from log: KrillRequestLogsResponse.KrillRequestLog) -> Double? {
        if let cost = log.cost_usd { return cost }

        var total = 0.0
        var sawValue = false
        for value in [log.plan_cost_usd, log.credit_cost_usd] {
            guard let value else { continue }
            total += value
            sawValue = true
        }
        return sawValue ? total : nil
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

    static func dayRange(
        for dayKey: String,
        now: Date,
        calendar: Calendar = .current) -> (startTime: Date, endTime: Date)?
    {
        let parts = dayKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let startTime = calendar.date(from: components) else { return nil }
        guard startTime <= now else { return nil }
        guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: startTime) else {
            return nil
        }
        let endTime = calendar.isDate(startTime, inSameDayAs: now) ? now : nextDayStart
        guard endTime > startTime else { return nil }
        return (startTime, endTime)
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

private struct KrillModelBreakdownCacheEntry: Sendable {
    let dayKey: String
    let storedAt: Date
    let breakdowns: [CostUsageDailyReport.ModelBreakdown]?
}

private actor KrillModelBreakdownCache {
    private var entries: [String: KrillModelBreakdownCacheEntry] = [:]

    func lookup(dayKey: String, now: Date, ttl: TimeInterval) -> KrillModelBreakdownCacheEntry? {
        guard let entry = self.entries[dayKey],
              now.timeIntervalSince(entry.storedAt) < ttl
        else {
            return nil
        }
        return entry
    }

    func store(
        dayKey: String,
        now: Date,
        breakdowns: [CostUsageDailyReport.ModelBreakdown]?)
    {
        self.entries[dayKey] = KrillModelBreakdownCacheEntry(
            dayKey: dayKey,
            storedAt: now,
            breakdowns: breakdowns)
    }
}
#endif
