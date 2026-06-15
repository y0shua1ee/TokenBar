import Testing
@testable import TokenBar

struct KeychainPromptCoordinatorTests {
    @Test
    func `detects raw SwiftPM debug executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Users/me/TokenBar/.build/arm64-apple-macosx/debug/TokenBar"))
        #expect(KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Users/me/TokenBar/.build/debug/TokenBar"))
    }

    @Test
    func `detects raw SwiftPM release executable`() {
        #expect(KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Users/me/TokenBar/.build/arm64-apple-macosx/release/TokenBar"))
    }

    @Test
    func `detects custom SwiftPM scratch path`() {
        #expect(KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/tmp/tokenbar-build/arm64-apple-macosx/debug/TokenBar"))
    }

    @Test
    func `keeps packaged app keychain behavior`() {
        #expect(!KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Applications/TokenBar.app/Contents/MacOS/TokenBar"))
        #expect(!KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Users/me/TokenBar/.build/package/TokenBar.app/Contents/MacOS/TokenBar"))
    }

    @Test
    func `ignores unrelated executable paths`() {
        #expect(!KeychainPromptCoordinator.isUnbundledCodexBarExecutable(
            "/Users/me/TokenBar/.build/debug/TokenBarCLI"))
        #expect(!KeychainPromptCoordinator.isUnbundledCodexBarExecutable(""))
        #expect(!KeychainPromptCoordinator.isUnbundledCodexBarExecutable("TokenBar"))
    }
}
