import Foundation

/// TokenBar-owned names that are observable outside the Swift module boundary.
///
/// The fork intentionally keeps its inherited `CodexBar*` Swift symbols, targets, resource bundle names,
/// queue labels, and environment-variable names. New user-visible names and persisted paths must use this
/// namespace instead of introducing another product-identity literal.
public enum TokenBarIdentity {
    public static let displayName = "TokenBar"
    public static let commandName = "tokenbar"

    public static let applicationBundleName = "TokenBar.app"
    public static let applicationExecutableName = "TokenBar"
    public static let cliExecutableName = "TokenBarCLI"
    public static let repositoryURL = "https://github.com/y0shua1ee/TokenBar"
    public static let websiteURL = "https://tokenbar.app"
    public static let upstreamRepositoryURL = "https://github.com/steipete/CodexBar"
    public static let bundledCLIRelativePath = "Contents/Helpers/TokenBarCLI"
    public static let bundledApplicationPath = "/Applications/TokenBar.app"
    public static let bundledCLIPath =
        "\(TokenBarIdentity.bundledApplicationPath)/\(TokenBarIdentity.bundledCLIRelativePath)"

    public static let bundleIdentifier = "com.y0shua1ee.tokenbar"
    public static let debugBundleIdentifier = "com.y0shua1ee.tokenbar.debug"
    public static let persistenceNamespace = TokenBarIdentity.bundleIdentifier
    public static let cloudKitContainerIdentifier = "iCloud.\(TokenBarIdentity.bundleIdentifier)"

    public static let applicationSupportDirectoryName = TokenBarIdentity.displayName
    public static let cachesDirectoryName = TokenBarIdentity.displayName
    public static let logsDirectoryName = TokenBarIdentity.displayName
    public static let logFilename = "\(TokenBarIdentity.displayName).log"
    public static let configDirectoryName = TokenBarIdentity.commandName
    public static let legacyConfigDirectoryName = ".\(TokenBarIdentity.commandName)"

    /// General first-party Keychain service used by provider-specific stores.
    public static let keychainStoreService = "com.y0shua1ee.TokenBar"
    /// Service used by early TokenBar builds after the product rename. This is not CodexBar's service.
    public static let legacyKeychainStoreService = "com.steipete.TokenBar"
    /// Dedicated service used by `KeychainCacheStore`.
    public static let keychainCacheService = "\(TokenBarIdentity.bundleIdentifier).cache"
    public static let keychainCacheLabel = "\(TokenBarIdentity.displayName) Cache"

    /// Empty by design: an ad-hoc build falls back to the legacy unprefixed app group.
    public static let defaultTeamID = ""
    public static let appGroupTeamIDInfoKey = "TokenBarTeamID"
    public static let appGroupIdentifierBase = TokenBarIdentity.bundleIdentifier
    public static let legacyReleaseAppGroupIdentifier = "group.\(TokenBarIdentity.bundleIdentifier)"
    public static let legacyDebugAppGroupIdentifier = "group.\(TokenBarIdentity.debugBundleIdentifier)"

    public static let pluginApprovalsFilename = "plugin-approvals.json"
    public static let pluginsDirectoryName = "plugins"

    public static var configPathDescription: String {
        "~/.config/\(self.configDirectoryName)/config.json"
    }

    public static var legacyConfigPathDescription: String {
        "~/\(self.legacyConfigDirectoryName)/config.json"
    }

    public static var configPathHint: String {
        "\(self.configPathDescription) (legacy: \(self.legacyConfigPathDescription))"
    }

    public static func applicationSupportDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(self.applicationSupportDirectoryName, isDirectory: true)
    }

    public static func namespacedApplicationSupportDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(self.persistenceNamespace, isDirectory: true)
    }

    public static func cachesDirectory(fileManager: FileManager = .default) -> URL? {
        fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(self.cachesDirectoryName, isDirectory: true)
    }

    public static func logsDirectory(fileManager: FileManager = .default) -> URL? {
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library", isDirectory: true)
        return library
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent(self.logsDirectoryName, isDirectory: true)
    }
}
