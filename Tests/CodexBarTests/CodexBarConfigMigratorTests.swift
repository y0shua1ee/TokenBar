import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

@Suite(.serialized)
struct CodexBarConfigMigratorTests {
    @Test
    func `legacy Moonshot key is bound to its selected region`() throws {
        let suite = "CodexBarConfigMigratorTests-moonshot-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let configStore = testConfigStore(suiteName: suite)
        var config = CodexBarConfig.makeDefault()
        config.setProviderConfig(ProviderConfig(
            id: .moonshot,
            apiKey: "legacy-china-token",
            region: MoonshotRegion.china.rawValue))
        try configStore.save(config)

        let migrated = CodexBarConfigMigrator.loadOrMigrate(
            configStore: configStore,
            userDefaults: defaults,
            stores: Self.legacyStores(
                secrets: CountingLegacySecretStore(),
                accountStore: CountingTokenAccountStore()))

        #expect(migrated.providerConfig(for: .moonshot)?.apiKeyRegion == MoonshotRegion.china.rawValue)
        #expect(try configStore.load()?.providerConfig(for: .moonshot)?.apiKeyRegion == MoonshotRegion.china.rawValue)
    }

    @Test
    func `legacy secret migration completion flag skips repeated scans`() throws {
        let suite = "CodexBarConfigMigratorTests-skip-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let secrets = CountingLegacySecretStore()
        let accountStore = CountingTokenAccountStore()
        let stores = Self.legacyStores(secrets: secrets, accountStore: accountStore)
        let configStore = testConfigStore(suiteName: suite)

        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        let firstSecretLoads = secrets.loadCount
        let firstAccountLoads = accountStore.loadCount
        #expect(firstSecretLoads > 0)
        #expect(firstAccountLoads == 1)
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey) == true)

        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        #expect(secrets.loadCount == firstSecretLoads)
        #expect(accountStore.loadCount == firstAccountLoads)
    }

    @Test
    func `CodexBar completion flag skips migration and is canonicalized to TokenBar`() throws {
        let suite = "CodexBarConfigMigratorTests-compatible-flag-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: Self.compatibleMigrationCompletedKey)

        let secrets = CountingLegacySecretStore()
        let accountStore = CountingTokenAccountStore()
        _ = CodexBarConfigMigrator.loadOrMigrate(
            configStore: testConfigStore(suiteName: suite),
            userDefaults: defaults,
            stores: Self.legacyStores(secrets: secrets, accountStore: accountStore))

        #expect(secrets.loadCount == 0)
        #expect(accountStore.loadCount == 0)
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey))
    }

    @Test
    func `legacy migration completion waits for successful cleanup`() throws {
        let suite = "CodexBarConfigMigratorTests-cleanup-failure-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let secrets = CountingLegacySecretStore(token: "legacy-token", throwOnStore: true)
        let accountStore = CountingTokenAccountStore()
        let stores = Self.legacyStores(secrets: secrets, accountStore: accountStore)
        let configStore = testConfigStore(suiteName: suite)

        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        let firstSecretLoads = secrets.loadCount
        #expect(firstSecretLoads > 0)
        #expect(secrets.clearAttempts > 0)
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey) == false)

        secrets.throwOnStore = false
        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        #expect(secrets.loadCount > firstSecretLoads)
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey) == true)
    }

    @Test
    func `legacy stores are kept when migrated config save fails`() throws {
        let suite = "CodexBarConfigMigratorTests-save-failure-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbar-tests", isDirectory: true)
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let blockedDirectory = base.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blockedDirectory)

        let secrets = CountingLegacySecretStore(token: "legacy-token")
        let accountStore = CountingTokenAccountStore()
        let stores = Self.legacyStores(secrets: secrets, accountStore: accountStore)
        let configStore = CodexBarConfigStore(
            fileURL: blockedDirectory.appendingPathComponent("config.json"))

        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        #expect(secrets.clearAttempts == 0)
        #expect(try secrets.loadToken() == "legacy-token")
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey) == false)

        try FileManager.default.removeItem(at: blockedDirectory)
        _ = CodexBarConfigMigrator.loadOrMigrate(configStore: configStore, userDefaults: defaults, stores: stores)

        #expect(secrets.clearAttempts > 0)
        #expect(try secrets.loadToken() == nil)
        #expect(defaults.bool(forKey: Self.legacyMigrationCompletedKey) == true)
    }

    @Test
    func `Krill JWT migration runs after the general legacy migration completed`() throws {
        let suite = "CodexBarConfigMigratorTests-krill-independent-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: Self.legacyMigrationCompletedKey)

        let jwt = Self.krillJWT(expiration: 4_000_000_000)
        let krillStore = CountingKrillLegacyJWTStore(token: jwt)
        let migrated = CodexBarConfigMigrator.loadOrMigrate(
            configStore: testConfigStore(suiteName: suite),
            userDefaults: defaults,
            stores: Self.legacyStores(
                secrets: CountingLegacySecretStore(),
                accountStore: CountingTokenAccountStore(),
                krillStore: krillStore))

        #expect(migrated.providerConfig(for: .krill)?.sanitizedAPIKey == jwt)
        #expect(krillStore.loadCount == 1)
        #expect(krillStore.deleteAttempts == 1)
        #expect(try krillStore.loadJWT() == nil)
        #expect(defaults.bool(forKey: Self.krillLegacyJWTMigrationCompletedKey))
    }

    @Test
    func `Krill JWT stays in Keychain when config persistence fails`() throws {
        let suite = "CodexBarConfigMigratorTests-krill-save-failure-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbar-tests", isDirectory: true)
            .appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let blockedDirectory = base.appendingPathComponent("blocked")
        try Data("not a directory".utf8).write(to: blockedDirectory)
        let configStore = CodexBarConfigStore(fileURL: blockedDirectory.appendingPathComponent("config.json"))
        let jwt = Self.krillJWT(expiration: 4_000_000_000)
        let krillStore = CountingKrillLegacyJWTStore(token: jwt)

        _ = CodexBarConfigMigrator.loadOrMigrate(
            configStore: configStore,
            userDefaults: defaults,
            stores: Self.legacyStores(
                secrets: CountingLegacySecretStore(),
                accountStore: CountingTokenAccountStore(),
                krillStore: krillStore))

        #expect(krillStore.deleteAttempts == 0)
        #expect(try krillStore.loadJWT() == jwt)
        #expect(defaults.bool(forKey: Self.krillLegacyJWTMigrationCompletedKey) == false)
    }

    @Test
    func `Krill JWT migration retries when noninteractive Keychain access is unavailable`() throws {
        let suite = "CodexBarConfigMigratorTests-krill-keychain-deferred-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        let krillStore = CountingKrillLegacyJWTStore(
            token: Self.krillJWT(expiration: 4_000_000_000),
            loadError: KrillLegacyJWTStoreError.interactionNotAllowed)
        _ = CodexBarConfigMigrator.loadOrMigrate(
            configStore: testConfigStore(suiteName: suite),
            userDefaults: defaults,
            stores: Self.legacyStores(
                secrets: CountingLegacySecretStore(),
                accountStore: CountingTokenAccountStore(),
                krillStore: krillStore))

        #expect(krillStore.loadCount == 1)
        #expect(krillStore.deleteAttempts == 0)
        #expect(defaults.bool(forKey: Self.krillLegacyJWTMigrationCompletedKey) == false)
    }

    @Test
    func `invalid legacy Krill JWTs are deleted instead of migrated`() throws {
        let invalidTokens = [
            "not-a-jwt",
            Self.krillJWT(expiration: 1),
        ]

        for token in invalidTokens {
            let suite = "CodexBarConfigMigratorTests-krill-invalid-\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suite))
            defaults.removePersistentDomain(forName: suite)
            defer { defaults.removePersistentDomain(forName: suite) }
            let krillStore = CountingKrillLegacyJWTStore(token: token)

            let migrated = CodexBarConfigMigrator.loadOrMigrate(
                configStore: testConfigStore(suiteName: suite),
                userDefaults: defaults,
                stores: Self.legacyStores(
                    secrets: CountingLegacySecretStore(),
                    accountStore: CountingTokenAccountStore(),
                    krillStore: krillStore))

            #expect(migrated.providerConfig(for: .krill)?.sanitizedAPIKey == nil)
            #expect(krillStore.deleteAttempts == 1)
            #expect(defaults.bool(forKey: Self.krillLegacyJWTMigrationCompletedKey))
        }
    }

    private static let legacyMigrationCompletedKey = "tokenbar.legacySecretsMigrationCompleted"
    private static let compatibleMigrationCompletedKey = "codexbar.legacySecretsMigrationCompleted"
    private static let krillLegacyJWTMigrationCompletedKey = "tokenbar.krillLegacyJWTMigrationCompleted"

    private static func krillJWT(expiration: TimeInterval) -> String {
        let header = Data(#"{"alg":"none"}"#.utf8).base64EncodedString()
        let payload = Data(#"{"exp":\#(expiration)}"#.utf8).base64EncodedString()
        let base64URL: (String) -> String = {
            $0.replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(base64URL(header)).\(base64URL(payload)).signature"
    }

    private static func legacyStores(
        secrets: CountingLegacySecretStore,
        accountStore: CountingTokenAccountStore,
        krillStore: any KrillLegacyJWTStoring = CountingKrillLegacyJWTStore())
        -> CodexBarConfigMigrator.LegacyStores
    {
        CodexBarConfigMigrator.LegacyStores(
            zaiTokenStore: secrets,
            syntheticTokenStore: secrets,
            codexCookieStore: secrets,
            claudeCookieStore: secrets,
            cursorCookieStore: secrets,
            opencodeCookieStore: secrets,
            factoryCookieStore: secrets,
            minimaxCookieStore: secrets,
            minimaxAPITokenStore: secrets,
            kimiTokenStore: secrets,
            augmentCookieStore: secrets,
            ampCookieStore: secrets,
            copilotTokenStore: secrets,
            tokenAccountStore: accountStore,
            krillLegacyJWTStore: krillStore)
    }
}

private final class CountingLegacySecretStore: ZaiTokenStoring, SyntheticTokenStoring, CookieHeaderStoring,
    MiniMaxCookieStoring, MiniMaxAPITokenStoring, KimiTokenStoring, CopilotTokenStoring,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var token: String?
    var throwOnStore: Bool
    private(set) var loadCount = 0
    private(set) var clearAttempts = 0

    init(token: String? = nil, throwOnStore: Bool = false) {
        self.token = token
        self.throwOnStore = throwOnStore
    }

    func loadToken() throws -> String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadCount += 1
        return self.token
    }

    func storeToken(_ token: String?) throws {
        try self.store(token)
    }

    func loadCookieHeader() throws -> String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadCount += 1
        return self.token
    }

    func storeCookieHeader(_ header: String?) throws {
        try self.store(header)
    }

    private func store(_ value: String?) throws {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.clearAttempts += value == nil ? 1 : 0
        if self.throwOnStore {
            throw TestStoreError.storeFailed
        }
        self.token = value
    }
}

private final class CountingTokenAccountStore: ProviderTokenAccountStoring, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var loadCount = 0

    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.loadCount += 1
        return [:]
    }

    func storeAccounts(_: [UsageProvider: ProviderTokenAccountData]) throws {}

    func ensureFileExists() throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("codexbar-empty-accounts.json")
    }
}

private final class CountingKrillLegacyJWTStore: KrillLegacyJWTStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    private let loadError: (any Error)?
    private(set) var loadCount = 0
    private(set) var deleteAttempts = 0

    init(token: String? = nil, loadError: (any Error)? = nil) {
        self.token = token
        self.loadError = loadError
    }

    func loadJWT() throws -> String? {
        try self.lock.withLock {
            self.loadCount += 1
            if let loadError {
                throw loadError
            }
            return self.token
        }
    }

    func deleteJWT() {
        self.lock.withLock {
            self.deleteAttempts += 1
            self.token = nil
        }
    }
}

private enum TestStoreError: Error {
    case storeFailed
}
