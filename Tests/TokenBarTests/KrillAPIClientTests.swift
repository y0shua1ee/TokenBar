#if os(macOS)
import Testing
@testable import TokenBarCore

struct KrillAPIClientTests {
    @Test
    func `uses Krill same origin API host`() {
        #expect(KrillAPIClient.baseURL == "https://www.krill-ai.com")
        #expect(KrillAPIClient.baseURL != "https://api.krill-ai.com")
    }
}
#endif
