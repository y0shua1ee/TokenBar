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
        if let version = currentVersion() {
            Self.trace("printVersion:currentVersion")
            print("TokenBar \(version)")
        } else {
            Self.trace("printVersion:no-currentVersion")
            print("TokenBar")
        }
        Self.trace("printVersion:exit")
        Self.platformExit(0)
    }

    static func printHelp(for command: String?) -> Never {
        Self.trace("printHelp:start command=\(command ?? "root")")
        let version = self.currentVersion() ?? "unknown"
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
        bundle: Bundle = .main,
        executablePath: String? = CommandLine.arguments.first) -> String?
    {
        if let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        guard let executablePath, !executablePath.isEmpty else { return nil }

        let executableURL = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath()
        return Self.containingAppVersion(for: executableURL)
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
