import Testing
@testable import TokenBar

struct KeychainMigrationTests {
    @Test
    func `migration list covers known keychain items`() {
        let items = Set(KeychainMigration.itemsToMigrate.map(\.label))
        let expected: Set = [
            "com.steipete.TokenBar:codex-cookie",
            "com.steipete.TokenBar:claude-cookie",
            "com.steipete.TokenBar:cursor-cookie",
            "com.steipete.TokenBar:factory-cookie",
            "com.steipete.TokenBar:minimax-cookie",
            "com.steipete.TokenBar:minimax-api-token",
            "com.steipete.TokenBar:augment-cookie",
            "com.steipete.TokenBar:copilot-api-token",
            "com.steipete.TokenBar:zai-api-token",
            "com.steipete.TokenBar:synthetic-api-key",
        ]

        let missing = expected.subtracting(items)
        #expect(missing.isEmpty, "Missing migration entries: \(missing.sorted())")
    }
}
