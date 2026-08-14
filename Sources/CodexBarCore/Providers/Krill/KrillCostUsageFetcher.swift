import Foundation

public enum KrillCostUsageFetcher {
    public static func loadTokenSnapshot(
        jwt: String,
        now: Date = Date(),
        historyDays: Int = 30,
        calendar: Calendar = .current,
        transport: any ProviderHTTPTransport = ProviderHTTPClient.shared) async throws -> CostUsageTokenSnapshot
    {
        try KrillJWT.validated(jwt, now: now)
        let days = self.clampedHistoryDays(historyDays)
        let report = try await self.loadDailyReport(
            jwt: jwt,
            now: now,
            historyDays: days,
            calendar: calendar,
            transport: transport)
        return CostUsageFetcher.tokenSnapshot(
            from: report,
            now: now,
            historyDays: days,
            calendar: calendar,
            credentialScopeFingerprint: KrillJWT.credentialFingerprint(jwt))
    }

    static func loadDailyReport(
        jwt: String,
        now: Date,
        historyDays: Int,
        calendar: Calendar,
        transport: any ProviderHTTPTransport) async throws -> CostUsageDailyReport
    {
        let days = self.clampedHistoryDays(historyDays)
        let todayStart = calendar.startOfDay(for: now)
        let sinceStart = calendar.date(byAdding: .day, value: -(days - 1), to: todayStart) ?? todayStart
        let client = KrillAPIClient(transport: transport)

        let rollingResponse = try await client.fetchStats(jwt: jwt, startTime: sinceStart, endTime: now)
        try Task.checkCancellation()
        let todayResponse = try await client.fetchStats(jwt: jwt, startTime: todayStart, endTime: now)
        try Task.checkCancellation()

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
            let modelBreakdowns = try await self.bestEffortTodayModelBreakdowns(
                jwt: jwt,
                dayStart: todayStart,
                now: now,
                client: client)
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

    static func clampedHistoryDays(_ value: Int) -> Int {
        min(365, max(1, value))
    }

    static func entry(
        dayStart: Date,
        stats: KrillStatsResponse.DataPayload,
        calendar: Calendar = .current,
        modelBreakdowns: [CostUsageDailyReport.ModelBreakdown]? = nil) -> CostUsageDailyReport.Entry?
    {
        let requestCount = stats.totalRequests ?? 0
        guard requestCount > 0 || (stats.totalTokens ?? 0) > 0 || (stats.totalCostUSD ?? 0) > 0 else {
            return nil
        }
        let breakdowns = self.nonEmpty(modelBreakdowns)
        return CostUsageDailyReport.Entry(
            date: self.dayKey(for: dayStart, calendar: calendar),
            inputTokens: stats.inputTokens,
            outputTokens: stats.outputTokens,
            cacheReadTokens: stats.cacheReadInputTokens,
            cacheCreationTokens: stats.cacheCreationInputTokens,
            totalTokens: stats.totalTokens,
            requestCount: stats.totalRequests,
            costUSD: stats.totalCostUSD,
            modelsUsed: breakdowns?.map(\.modelName).sorted(),
            modelBreakdowns: breakdowns)
    }

    static func entries(
        from trend: [KrillStatsResponse.DataPayload.TrendBucket],
        calendar: Calendar = .current) -> [CostUsageDailyReport.Entry]
    {
        struct Totals {
            var requestCount = 0
            var totalTokens = 0
            var sawTokens = false
            var costUSD = 0.0
            var sawCost = false
        }

        var totalsByDay: [String: Totals] = [:]
        for bucket in trend {
            guard let rawDate = bucket.bucketStart,
                  let date = self.date(from: rawDate)
            else { continue }
            let requests = bucket.requestCount ?? 0
            guard requests > 0 || (bucket.totalTokens ?? 0) > 0 || (bucket.totalCostUSD ?? 0) > 0 else {
                continue
            }

            let key = self.dayKey(for: date, calendar: calendar)
            var totals = totalsByDay[key] ?? Totals()
            totals.requestCount += requests
            if let tokens = bucket.totalTokens {
                totals.totalTokens += tokens
                totals.sawTokens = true
            }
            if let cost = bucket.totalCostUSD {
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
                totalTokens: totals.sawTokens ? totals.totalTokens : nil,
                requestCount: totals.requestCount,
                costUSD: totals.sawCost ? totals.costUSD : nil,
                modelsUsed: nil,
                modelBreakdowns: nil)
        }
    }

    static func modelBreakdowns(
        from items: [KrillModelStatsResponse.Item]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        self.sorted(items.compactMap { item in
            guard let name = self.cleaned(item.model),
                  item.totalTokens != nil || item.totalCostUSD != nil || item.requestCount != nil
            else { return nil }
            return CostUsageDailyReport.ModelBreakdown(
                modelName: name,
                costUSD: item.totalCostUSD,
                totalTokens: item.totalTokens,
                requestCount: item.requestCount)
        })
    }

    private static func bestEffortTodayModelBreakdowns(
        jwt: String,
        dayStart: Date,
        now: Date,
        client: KrillAPIClient) async throws -> [CostUsageDailyReport.ModelBreakdown]?
    {
        do {
            let response = try await client.fetchModelStats(
                jwt: jwt,
                startTime: dayStart,
                endTime: now)
            return self.nonEmpty(self.modelBreakdowns(from: response.data?.items ?? []))
        } catch {
            try KrillCancellation.propagate(error)
            return nil
        }
    }

    private static func summary(from stats: KrillStatsResponse.DataPayload) -> CostUsageDailyReport.Summary? {
        guard (stats.totalRequests ?? 0) > 0 || (stats.totalTokens ?? 0) > 0 || (stats.totalCostUSD ?? 0) > 0 else {
            return nil
        }
        return CostUsageDailyReport.Summary(
            totalInputTokens: stats.inputTokens,
            totalOutputTokens: stats.outputTokens,
            cacheReadTokens: stats.cacheReadInputTokens,
            cacheCreationTokens: stats.cacheCreationInputTokens,
            totalTokens: stats.totalTokens,
            totalCostUSD: stats.totalCostUSD)
    }

    private static func summary(from entries: [CostUsageDailyReport.Entry]) -> CostUsageDailyReport.Summary? {
        guard !entries.isEmpty else { return nil }
        return CostUsageDailyReport.Summary(
            totalInputTokens: self.sum(entries.map(\.inputTokens)),
            totalOutputTokens: self.sum(entries.map(\.outputTokens)),
            cacheReadTokens: self.sum(entries.map(\.cacheReadTokens)),
            cacheCreationTokens: self.sum(entries.map(\.cacheCreationTokens)),
            totalTokens: self.sum(entries.map(\.totalTokens)),
            totalCostUSD: self.sum(entries.map(\.costUSD)))
    }

    private static func sum(_ values: [Int?]) -> Int? {
        var result = 0
        var found = false
        for value in values {
            guard let value else { continue }
            result += value
            found = true
        }
        return found ? result : nil
    }

    private static func sum(_ values: [Double?]) -> Double? {
        var result = 0.0
        var found = false
        for value in values {
            guard let value else { continue }
            result += value
            found = true
        }
        return found ? result : nil
    }

    private static func sorted(
        _ values: [CostUsageDailyReport.ModelBreakdown]) -> [CostUsageDailyReport.ModelBreakdown]
    {
        values.sorted { lhs, rhs in
            if (lhs.costUSD ?? -1) != (rhs.costUSD ?? -1) {
                return (lhs.costUSD ?? -1) > (rhs.costUSD ?? -1)
            }
            if (lhs.totalTokens ?? -1) != (rhs.totalTokens ?? -1) {
                return (lhs.totalTokens ?? -1) > (rhs.totalTokens ?? -1)
            }
            return lhs.modelName < rhs.modelName
        }
    }

    private static func nonEmpty<T>(_ values: [T]?) -> [T]? {
        guard let values, !values.isEmpty else { return nil }
        return values
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 1970,
            components.month ?? 1,
            components.day ?? 1)
    }

    private static func date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
