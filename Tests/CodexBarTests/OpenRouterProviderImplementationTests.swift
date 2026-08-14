import CodexBarCore
import Foundation
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
@Suite(.serialized)
struct OpenRouterProviderImplementationTests {
    @Test
    func `settings distinguish regular and management key responsibilities`() throws {
        let fixture = try Self.makeFixture(suite: "OpenRouterProviderImplementationTests-fields")
        let fields = OpenRouterProviderImplementation().settingsFields(context: fixture.context)

        #expect(fields.map(\.id) == [
            "openrouter-api-key",
            "openrouter-management-key",
            "openrouter-api-url",
        ])

        let apiKey = try #require(fields.first { $0.id == "openrouter-api-key" })
        #expect(apiKey.title == "API key")
        #expect(apiKey.subtitle.contains(TokenBarIdentity.configPathHint))
        #expect(apiKey.subtitle.contains("Credits balance"))
        #expect(apiKey.subtitle.contains("current-key quota"))
        guard case .secure = apiKey.kind else {
            Issue.record("Expected the regular API key field to be secure")
            return
        }

        let managementKey = try #require(fields.first { $0.id == "openrouter-management-key" })
        #expect(managementKey.title == "Management key (Activity)")
        #expect(managementKey.subtitle.contains(TokenBarIdentity.configPathHint))
        #expect(managementKey.subtitle.contains("Account-level Activity only"))
        #expect(managementKey.subtitle.contains("last 30 completed UTC days"))
        #expect(managementKey.subtitle.contains("cannot be used for completions"))
        #expect(managementKey.subtitle.contains("does not use this key for Credits balance or current-key quota"))
        #expect(managementKey.actions.map(\.id) == ["openrouter-open-management-keys"])
        guard case .secure = managementKey.kind else {
            Issue.record("Expected the management key field to be secure")
            return
        }

        apiKey.binding.wrappedValue = "test-regular-key"
        managementKey.binding.wrappedValue = "test-management-key"
        #expect(fixture.settings[providerConfig: .openrouter, field: .apiKey] == "test-regular-key")
        #expect(fixture.settings[providerConfig: .openrouter, field: .secretKey] == "test-management-key")

        let endpoint = try #require(fields.first { $0.id == "openrouter-api-url" })
        #expect(endpoint.subtitle.contains("regular-key Credits balance and quota"))
        #expect(endpoint.subtitle.contains("Management Activity always uses OpenRouter's hosted API"))
    }

    @Test
    func `management key alone makes OpenRouter available`() throws {
        let fixture = try Self.makeFixture(suite: "OpenRouterProviderImplementationTests-management-config")
        fixture.settings[providerConfig: .openrouter, field: .secretKey] = "test-management-key"

        let context = ProviderAvailabilityContext(provider: .openrouter, settings: fixture.settings, environment: [:])

        #expect(OpenRouterProviderImplementation().isAvailable(context: context))
    }

    @Test
    func `management environment key alone makes OpenRouter available`() throws {
        let fixture = try Self.makeFixture(suite: "OpenRouterProviderImplementationTests-management-env")
        let context = ProviderAvailabilityContext(
            provider: .openrouter,
            settings: fixture.settings,
            environment: [OpenRouterSettingsReader.managementKeyEnvironmentKey: "test-management-key"])

        #expect(OpenRouterProviderImplementation().isAvailable(context: context))
    }

    @Test
    func `OpenRouter remains unavailable without either credential`() throws {
        let fixture = try Self.makeFixture(suite: "OpenRouterProviderImplementationTests-missing")
        fixture.settings[providerConfig: .openrouter, field: .apiKey] = "   "
        fixture.settings[providerConfig: .openrouter, field: .secretKey] = "   "
        let context = ProviderAvailabilityContext(provider: .openrouter, settings: fixture.settings, environment: [:])

        #expect(!OpenRouterProviderImplementation().isAvailable(context: context))
    }

    @Test
    func `presentation reports the selected OpenRouter source`() throws {
        let fixture = try Self.makeFixture(suite: "OpenRouterProviderImplementationTests-presentation")
        fixture.store.lastSourceLabels[.openrouter] = "activity"
        let metadata = try #require(ProviderDescriptorRegistry.metadata[.openrouter])
        let context = ProviderPresentationContext(
            provider: .openrouter,
            settings: fixture.settings,
            store: fixture.store,
            metadata: metadata)

        let detailLine = OpenRouterProviderImplementation().presentation(context: context).detailLine(context)

        #expect(detailLine == "activity")
    }

    private static func makeFixture(suite: String) throws -> Fixture {
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        let settings = SettingsStore(
            userDefaults: defaults,
            configStore: testConfigStore(suiteName: suite),
            zaiTokenStore: NoopZaiTokenStore(),
            syntheticTokenStore: NoopSyntheticTokenStore())
        let store = UsageStore(
            fetcher: UsageFetcher(environment: [:]),
            browserDetection: BrowserDetection(cacheTTL: 0),
            settings: settings,
            startupBehavior: .testing,
            environmentBase: [:])
        let context = ProviderSettingsContext(
            provider: .openrouter,
            settings: settings,
            store: store,
            boolBinding: { keyPath in
                Binding(
                    get: { settings[keyPath: keyPath] },
                    set: { settings[keyPath: keyPath] = $0 })
            },
            stringBinding: { keyPath in
                Binding(
                    get: { settings[keyPath: keyPath] },
                    set: { settings[keyPath: keyPath] = $0 })
            },
            statusText: { _ in nil },
            setStatusText: { _, _ in },
            lastAppActiveRunAt: { _ in nil },
            setLastAppActiveRunAt: { _, _ in },
            requestConfirmation: { _ in },
            runLoginFlow: {})
        return Fixture(settings: settings, store: store, context: context)
    }

    private struct Fixture {
        let settings: SettingsStore
        let store: UsageStore
        let context: ProviderSettingsContext
    }
}
