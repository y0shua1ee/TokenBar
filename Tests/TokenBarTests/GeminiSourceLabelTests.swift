import Testing
@testable import TokenBarCore

struct GeminiSourceLabelTests {
    @Test
    func `Gemini source label reflects OAuth backed API requests`() {
        #expect(GeminiStatusFetchStrategy.sourceLabel == "oauth-api")
    }
}
