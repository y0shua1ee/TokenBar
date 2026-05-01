import Testing
@testable import TokenBar

struct KeychainMigrationTests {
    @Test
    func `migration list covers known keychain items`() {
        let items = Set(KeychainMigration.itemsToMigrate.map(\.label))
        let expected: Set = [
            "com.y0shua1ee.TokenBar:codex-cookie",
            "com.y0shua1ee.TokenBar:claude-cookie",
            "com.y0shua1ee.TokenBar:cursor-cookie",
            "com.y0shua1ee.TokenBar:factory-cookie",
            "com.y0shua1ee.TokenBar:minimax-cookie",
            "com.y0shua1ee.TokenBar:minimax-api-token",
            "com.y0shua1ee.TokenBar:augment-cookie",
            "com.y0shua1ee.TokenBar:copilot-api-token",
            "com.y0shua1ee.TokenBar:zai-api-token",
            "com.y0shua1ee.TokenBar:synthetic-api-key",
        ]

        let missing = expected.subtracting(items)
        #expect(missing.isEmpty, "Missing migration entries: \(missing.sorted())")
    }
}
