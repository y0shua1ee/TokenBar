import CodexBarCore
import Testing
@testable import CodexBar

struct KeychainMigrationTests {
    @Test
    func `migration list covers known keychain items`() {
        let items = Set(KeychainMigration.itemsToMigrate.map(\.label))
        let services = [
            TokenBarIdentity.keychainStoreService,
            TokenBarIdentity.legacyKeychainStoreService,
        ]
        let accounts = [
            "codex-cookie",
            "claude-cookie",
            "cursor-cookie",
            "factory-cookie",
            "minimax-cookie",
            "minimax-api-token",
            "augment-cookie",
            "copilot-api-token",
            "zai-api-token",
            "synthetic-api-key",
        ]
        let expected = Set(services.flatMap { service in
            accounts.map { account in "\(service):\(account)" }
        })

        let missing = expected.subtracting(items)
        #expect(missing.isEmpty, "Missing migration entries: \(missing.sorted())")
        #expect(items == expected)
        #expect(items.allSatisfy { !$0.hasPrefix("com.steipete.CodexBar:") })
    }
}
