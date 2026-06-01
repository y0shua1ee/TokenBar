#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
import Foundation

extension TokenBarCLI {
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
        self.trace("printVersion:start")
        if let version = currentVersion() {
            print("TokenBar \(version)")
        } else {
            print("TokenBar")
        }
        self.trace("printVersion:exit")
        self.platformExit(0)
    }

    static func printHelp(for command: String?) -> Never {
        self.trace("printHelp:start command=\(command ?? "root")")
        let version = self.currentVersion() ?? "unknown"
        Self.trace("printHelp:version=\(version)")
        switch command {
        case "usage":
            print(Self.usageHelp(version: version))
        case "cost":
            print(Self.costHelp(version: version))
        case "serve":
            print(Self.serveHelp(version: version))
        case "config", "validate", "dump":
            print(Self.configHelp(version: version))
        case "cache", "clear":
            print(Self.cacheHelp(version: version))
        case "diagnose":
            print(Self.diagnoseHelp(version: version))
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
        if let version = self.currentVersion(bundleVersion: nil, executablePath: executablePath) {
            return version
        }
        return self.currentVersion(
            bundleVersion: bundle?.infoDictionary?["CFBundleShortVersionString"] as? String,
            executablePath: nil)
    }

    static func currentVersion(bundleVersion: String?, executablePath: String?) -> String? {
        if let executablePath, !executablePath.isEmpty {
            let executableURL = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath()
            if let version = Self.adjacentVersionFileVersion(for: executableURL) {
                return version
            }
            if let version = Self.containingAppVersion(for: executableURL) {
                return version
            }
        }
        return Self.normalizedBundleVersion(bundleVersion)
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

    static func adjacentVersionFileVersion(for executableURL: URL) -> String? {
        let versionURL = executableURL
            .deletingLastPathComponent()
            .appendingPathComponent("VERSION")
        guard let raw = try? String(contentsOf: versionURL, encoding: .utf8) else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("v"), trimmed.dropFirst().first?.isNumber == true {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    static func normalizedBundleVersion(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed != "TokenBar"
        else { return nil }
        return trimmed
    }

    static func platformExit(_ code: Int32) -> Never {
        #if canImport(Darwin)
        Darwin.exit(code)
        #else
        Glibc.exit(code)
        #endif
    }
}
