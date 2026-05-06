#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension CodexBarCLI {
    static func writeStderr(_ string: String) {
        guard let data = string.data(using: .utf8) else { return }
        FileHandle.standardError.write(data)
    }

    static func trace(_ message: String) {
        guard ProcessInfo.processInfo.environment["TOKENBAR_CLI_TRACE"] == "1" else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        Self.writeStderr("[TokenBarCLI trace] \(timestamp) \(message)\n")
    }

    static func printVersion() -> Never {
        Self.trace("printVersion:start")
        print("TokenBar")
        Self.trace("printVersion:exit")
        Self.platformExit(0)
    }

    static func printHelp(for command: String?) -> Never {
        Self.trace("printHelp:start command=\(command ?? "root")")
        let version = "unknown"
        Self.trace("printHelp:version=\(version)")
        switch command {
        case "usage":
            print(Self.usageHelp(version: version))
        case "cost":
            print(Self.costHelp(version: version))
        case "config", "validate", "dump":
            print(Self.configHelp(version: version))
        case "cache", "clear":
            print(Self.cacheHelp(version: version))
        default:
            print(Self.rootHelp(version: version))
        }
        Self.trace("printHelp:printed")
        Self.platformExit(0)
    }

    static func currentVersion(
        bundle: Bundle? = nil,
        executablePath: String? = CommandLine.arguments.first) -> String?
    {
        if let executablePath, !executablePath.isEmpty {
            let executableURL = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath()
            if let appVersion = Self.containingAppVersion(for: executableURL) {
                return appVersion
            }
        }

        // Keep the default raw SwiftPM CLI help/version path lightweight. On macOS hosted
        // runners, Bundle.main.infoDictionary can trigger framework/bundle metadata work
        // before any command is executed; packaged-app helpers already resolve above by
        // reading the containing .app Info.plist directly.
        return bundle?.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    static func containingAppVersion(for executableURL: URL) -> String? {
        var currentURL = executableURL.deletingLastPathComponent()
        let fileManager = FileManager.default

        while currentURL.path != currentURL.deletingLastPathComponent().path {
            if currentURL.pathExtension == "app" {
                let infoURL = currentURL
                    .appendingPathComponent("Contents")
                    .appendingPathComponent("Info.plist")
                guard let data = fileManager.contents(atPath: infoURL.path),
                      let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
                else { return nil }
                return plist["CFBundleShortVersionString"] as? String
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }

    static func platformExit(_ code: Int32) -> Never {
        #if canImport(Darwin)
        Darwin.exit(code)
        #else
        Glibc.exit(code)
        #endif
    }
}
