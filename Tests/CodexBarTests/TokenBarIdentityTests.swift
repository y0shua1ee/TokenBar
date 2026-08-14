import Foundation
import Testing
@testable import CodexBarCore

struct TokenBarIdentityTests {
    @Test
    func `external product identity stays TokenBar owned`() {
        #expect(TokenBarIdentity.displayName == "TokenBar")
        #expect(TokenBarIdentity.commandName == "tokenbar")
        #expect(TokenBarIdentity.applicationBundleName == "TokenBar.app")
        #expect(TokenBarIdentity.applicationExecutableName == "TokenBar")
        #expect(TokenBarIdentity.cliExecutableName == "TokenBarCLI")
        #expect(TokenBarIdentity.repositoryURL == "https://github.com/y0shua1ee/TokenBar")
        #expect(TokenBarIdentity.websiteURL == "https://tokenbar.app")
        #expect(TokenBarIdentity.upstreamRepositoryURL == "https://github.com/steipete/CodexBar")
        #expect(TokenBarIdentity.bundleIdentifier == "com.y0shua1ee.tokenbar")
        #expect(TokenBarIdentity.debugBundleIdentifier == "com.y0shua1ee.tokenbar.debug")
        #expect(TokenBarIdentity.persistenceNamespace == "com.y0shua1ee.tokenbar")
        #expect(TokenBarIdentity.cloudKitContainerIdentifier == "iCloud.com.y0shua1ee.tokenbar")
    }

    @Test
    func `external persistence constants stay TokenBar owned`() {
        #expect(TokenBarIdentity.configDirectoryName == "tokenbar")
        #expect(TokenBarIdentity.legacyConfigDirectoryName == ".tokenbar")
        #expect(TokenBarIdentity.configPathDescription == "~/.config/tokenbar/config.json")
        #expect(TokenBarIdentity.legacyConfigPathDescription == "~/.tokenbar/config.json")
        #expect(
            TokenBarIdentity.configPathHint ==
                "~/.config/tokenbar/config.json (legacy: ~/.tokenbar/config.json)")
        #expect(TokenBarIdentity.applicationSupportDirectoryName == "TokenBar")
        #expect(TokenBarIdentity.cachesDirectoryName == "TokenBar")
        #expect(TokenBarIdentity.logsDirectoryName == "TokenBar")
        #expect(TokenBarIdentity.logFilename == "TokenBar.log")
        #expect(TokenBarIdentity.keychainStoreService == "com.y0shua1ee.TokenBar")
        #expect(TokenBarIdentity.legacyKeychainStoreService == "com.steipete.TokenBar")
        #expect(TokenBarIdentity.keychainCacheService == "com.y0shua1ee.tokenbar.cache")
        #expect(TokenBarIdentity.keychainCacheLabel == "TokenBar Cache")
        #expect(TokenBarIdentity.defaultTeamID.isEmpty)
        #expect(TokenBarIdentity.appGroupTeamIDInfoKey == "TokenBarTeamID")
        #expect(TokenBarIdentity.appGroupIdentifierBase == "com.y0shua1ee.tokenbar")
        #expect(TokenBarIdentity.legacyReleaseAppGroupIdentifier == "group.com.y0shua1ee.tokenbar")
        #expect(TokenBarIdentity.legacyDebugAppGroupIdentifier == "group.com.y0shua1ee.tokenbar.debug")
    }

    @Test
    func `external executable paths stay TokenBar owned`() {
        #expect(TokenBarIdentity.bundledCLIRelativePath == "Contents/Helpers/TokenBarCLI")
        #expect(TokenBarIdentity.bundledApplicationPath == "/Applications/TokenBar.app")
        #expect(TokenBarIdentity.bundledCLIPath == "/Applications/TokenBar.app/Contents/Helpers/TokenBarCLI")
        #expect(RemoteSessionFetcher.bundledCLIFallback == TokenBarIdentity.bundledCLIPath)
    }

    @Test
    func `core default paths stay in TokenBar namespaces`() throws {
        let applicationSupport = try #require(TokenBarIdentity.applicationSupportDirectory())
        let namespacedSupport = try #require(TokenBarIdentity.namespacedApplicationSupportDirectory())
        let caches = try #require(TokenBarIdentity.cachesDirectory())
        let logs = try #require(TokenBarIdentity.logsDirectory())

        #expect(applicationSupport.lastPathComponent == TokenBarIdentity.applicationSupportDirectoryName)
        #expect(namespacedSupport.lastPathComponent == TokenBarIdentity.persistenceNamespace)
        #expect(caches.lastPathComponent == TokenBarIdentity.cachesDirectoryName)
        #expect(logs.lastPathComponent == TokenBarIdentity.logsDirectoryName)
        #expect(FileLogSink.defaultURL.lastPathComponent == TokenBarIdentity.logFilename)
        #expect(FileManagedCodexAccountStore.defaultURL().path.hasSuffix("/TokenBar/managed-codex-accounts.json"))
        #expect(FileTokenAccountStore.defaultURL().path.hasSuffix("/TokenBar/token-accounts.json"))
        #expect(ProviderPluginApprovalStore.defaultURL.path.hasSuffix("/TokenBar/plugin-approvals.json"))
        #expect(UserProviderPluginLoader.defaultProvidersDirectory.path.hasSuffix("/.config/tokenbar/providers"))
        #expect(UserProviderPluginLoader.defaultCacheDirectory.path.hasSuffix("/Caches/TokenBar/plugins"))
        #expect(PiSessionCostCacheIO.cacheFileURL().path.contains("/Caches/TokenBar/"))
        #expect(ModelsDevCache.cacheFileURL().path.contains("/Caches/TokenBar/"))
        #expect(CostUsageClaudeCacheIO.cacheFileURL(provider: .claude).path.contains("/Caches/TokenBar/"))
    }

    @Test
    func `Claude application defaults use TokenBar domains`() {
        #expect(ClaudeOAuthKeychainPromptPreference.releaseApplicationDefaultsDomain ==
            TokenBarIdentity.bundleIdentifier)
        #expect(ClaudeOAuthKeychainPromptPreference.debugApplicationDefaultsDomain ==
            TokenBarIdentity.debugBundleIdentifier)
    }
}
