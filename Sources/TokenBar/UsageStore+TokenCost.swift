import Foundation
import TokenBarCore

extension UsageStore {
    func tokenSnapshot(for provider: UsageProvider) -> CostUsageTokenSnapshot? {
        self.tokenSnapshots[provider]
    }

    func tokenError(for provider: UsageProvider) -> String? {
        self.tokenErrors[provider]
    }

    func tokenLastAttemptAt(for provider: UsageProvider) -> Date? {
        self.lastTokenFetchAt[provider]
    }

    func isTokenRefreshInFlight(for provider: UsageProvider) -> Bool {
        self.tokenRefreshInFlight.contains(provider)
    }

    func tokenCostScope(for provider: UsageProvider) -> (codexHomePath: String?, signature: String) {
        guard provider == .codex else {
            return (nil, provider.rawValue)
        }
        let homePath = self.settings.activeManagedCodexRemoteHomePath?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let homePath, !homePath.isEmpty else {
            return (nil, "codex:ambient")
        }
        return (homePath, "codex:managed:\(homePath)")
    }

    func tokenSnapshot(
        fromProviderSnapshot snapshot: UsageSnapshot?,
        provider: UsageProvider)
        -> CostUsageTokenSnapshot?
    {
        switch provider {
        case .openai:
            snapshot?.openAIAPIUsage?.toCostUsageTokenSnapshot()
        case .mistral:
            snapshot?.mistralUsage?.toCostUsageTokenSnapshot(historyDays: self.settings.costUsageHistoryDays)
        default:
            nil
        }
    }

    nonisolated static func tokenCostRequiresProviderSnapshot(_ provider: UsageProvider) -> Bool {
        switch provider {
        case .mistral, .openai:
            true
        default:
            false
        }
    }

    func loadCostModelBreakdowns(
        provider: UsageProvider,
        dayKey: String) async -> [CostUsageDailyReport.ModelBreakdown]?
    {
        guard provider == .krill else { return nil }
        #if os(macOS)
        do {
            let breakdowns = try await KrillCostUsageFetcher.loadModelBreakdowns(dayKey: dayKey)
            self.mergeCostModelBreakdowns(breakdowns, provider: provider, dayKey: dayKey)
            return breakdowns
        } catch {
            return nil
        }
        #else
        return nil
        #endif
    }

    private func mergeCostModelBreakdowns(
        _ breakdowns: [CostUsageDailyReport.ModelBreakdown]?,
        provider: UsageProvider,
        dayKey: String)
    {
        guard let breakdowns, !breakdowns.isEmpty else { return }
        guard let snapshot = self.tokenSnapshots[provider] else { return }
        var didUpdate = false
        let daily = snapshot.daily.map { entry in
            guard entry.date == dayKey else { return entry }
            if let existing = entry.modelBreakdowns, !existing.isEmpty { return entry }
            didUpdate = true
            return CostUsageDailyReport.Entry(
                date: entry.date,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                cacheReadTokens: entry.cacheReadTokens,
                cacheCreationTokens: entry.cacheCreationTokens,
                totalTokens: entry.totalTokens,
                costUSD: entry.costUSD,
                modelsUsed: breakdowns.map(\.modelName).sorted(),
                modelBreakdowns: breakdowns)
        }
        guard didUpdate else { return }
        self.tokenSnapshots[provider] = CostUsageTokenSnapshot(
            sessionTokens: snapshot.sessionTokens,
            sessionCostUSD: snapshot.sessionCostUSD,
            sessionRequests: snapshot.sessionRequests,
            last30DaysTokens: snapshot.last30DaysTokens,
            last30DaysCostUSD: snapshot.last30DaysCostUSD,
            last30DaysRequests: snapshot.last30DaysRequests,
            costCurrencyCode: snapshot.costCurrencyCode,
            currencyCode: snapshot.currencyCode,
            daily: daily,
            updatedAt: snapshot.updatedAt)
        self.persistWidgetSnapshot(reason: "cost-model-breakdowns")
    }

    nonisolated static func costUsageCacheDirectory(
        fileManager: FileManager = .default) -> URL
    {
        let root = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return root
            .appendingPathComponent("TokenBar", isDirectory: true)
            .appendingPathComponent("cost-usage", isDirectory: true)
    }

    nonisolated static func tokenCostNoDataMessage(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).tokenCost.noDataMessage()
    }
}
