import Foundation
@testable import TokenBarCore

func withIsolatedOpenAIDashboardCache<T>(_ operation: () throws -> T) rethrows -> T {
    let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "tokenbar-openai-dashboard-cache-\(UUID().uuidString)",
        isDirectory: true)
    let cacheURL = rootURL.appendingPathComponent("openai-dashboard.json")
    defer { try? FileManager.default.removeItem(at: rootURL) }

    return try OpenAIDashboardCacheStore.$cacheURLOverride.withValue(cacheURL) {
        OpenAIDashboardCacheStore.clear()
        defer { OpenAIDashboardCacheStore.clear() }
        return try operation()
    }
}
