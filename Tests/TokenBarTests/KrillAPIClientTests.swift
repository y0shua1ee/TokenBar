#if os(macOS)
import Testing
@testable import TokenBarCore

struct KrillAPIClientTests {
    @Test
    func `uses Krill same origin API host`() {
        #expect(KrillAPIClient.baseURL == "https://www.krill-ai.net")
        #expect(KrillAPIClient.loginURL.absoluteString == "https://www.krill-ai.net/login")
        #expect(KrillAPIClient.dashboardURL == "https://www.krill-ai.net/app")
        #expect(KrillProviderDescriptor.descriptor.metadata.dashboardURL == KrillAPIClient.dashboardURL)
        #expect(KrillAPIClient.baseURL != "https://www.krill-ai.com")
        #expect(KrillAPIClient.baseURL != "https://api.krill-ai.com")
    }
}
#endif
