import Commander
import Foundation
import Testing
import TokenBarCore
@testable import TokenBarCLI

struct CLIEntryTests {
    @Test
    func `effective argv defaults to usage`() {
        #expect(TokenBarCLI.effectiveArgv([]) == ["usage"])
        #expect(TokenBarCLI.effectiveArgv(["--json"]) == ["usage", "--json"])
        #expect(TokenBarCLI.effectiveArgv(["usage", "--json"]) == ["usage", "--json"])
    }

    @Test
    func `decodes format from options and flags`() {
        let jsonOption = ParsedValues(positional: [], options: ["format": ["json"]], flags: [])
        #expect(TokenBarCLI._decodeFormatForTesting(from: jsonOption) == .json)

        let jsonFlag = ParsedValues(positional: [], options: [:], flags: ["json"])
        #expect(TokenBarCLI._decodeFormatForTesting(from: jsonFlag) == .json)

        let textDefault = ParsedValues(positional: [], options: [:], flags: [])
        #expect(TokenBarCLI._decodeFormatForTesting(from: textDefault) == .text)
    }

    @Test
    func `provider selection prefers override`() {
        let selection = TokenBarCLI.providerSelection(rawOverride: "codex", enabled: [.claude, .gemini])
        #expect(selection.asList == [.codex])
    }

    @Test
    func `normalize version extracts numeric`() {
        #expect(TokenBarCLI.normalizeVersion(raw: "codex 1.2.3 (build 4)") == "1.2.3")
        #expect(TokenBarCLI.normalizeVersion(raw: "  v2.0  ") == "2.0")
    }

    @Test
    func `make header includes version when available`() {
        let header = TokenBarCLI.makeHeader(provider: .codex, version: "1.2.3", source: "cli")
        #expect(header.contains("Codex"))
        #expect(header.contains("1.2.3"))
        #expect(header.contains("cli"))
    }

    @Test
    func `CLI version falls back to containing app bundle`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbar-cli-version-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("TokenBar.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "9.8.7"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)

        #expect(TokenBarCLI.containingAppVersion(for: helperURL) == "9.8.7")
    }

    @Test
    func `CLI version follows symlinked helper`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codexbar-cli-version-symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("TokenBar.app", isDirectory: true)
        let emptyBundleURL = root.appendingPathComponent("Empty.bundle", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: emptyBundleURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "2.4.6"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)

        let symlinkURL = binURL.appendingPathComponent("tokenbar")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: helperURL)

        let emptyBundle = try #require(Bundle(url: emptyBundleURL))
        #expect(TokenBarCLI.currentVersion(bundle: emptyBundle, executablePath: symlinkURL.path) == "2.4.6")
    }

    @Test
    func `raw SwiftPM CLI version can skip bundle and filesystem lookup`() {
        #expect(TokenBarCLI.currentVersion(bundle: nil, executablePath: nil) == nil)
    }

    @Test
    func `CLI version falls back to adjacent VERSION file`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-file-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let emptyBundleURL = root.appendingPathComponent("Empty.bundle", isDirectory: true)
        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: emptyBundleURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let helperURL = binURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)
        try "v3.2.1\n".write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: true,
            encoding: .utf8)

        let emptyBundle = try #require(Bundle(url: emptyBundleURL))
        #expect(TokenBarCLI.currentVersion(bundle: emptyBundle, executablePath: helperURL.path) == "3.2.1")

        try "3.2.2\n".write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: true,
            encoding: .utf8)
        #expect(TokenBarCLI.currentVersion(bundle: emptyBundle, executablePath: helperURL.path) == "3.2.2")

        try "version-3.2.3\n".write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: true,
            encoding: .utf8)
        #expect(TokenBarCLI.currentVersion(bundle: emptyBundle, executablePath: helperURL.path) == "version-3.2.3")
    }

    @Test
    func `render open AI web dashboard text includes summary`() {
        let event = CreditEvent(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            service: "codex",
            creditsUsed: 10)
        let snapshot = OpenAIDashboardSnapshot(
            signedInEmail: "user@example.com",
            codeReviewRemainingPercent: 45,
            codeReviewLimit: RateWindow(
                usedPercent: 55,
                windowMinutes: nil,
                resetsAt: Date().addingTimeInterval(3600),
                resetDescription: nil),
            creditEvents: [event],
            dailyBreakdown: [],
            usageBreakdown: [],
            creditsPurchaseURL: nil,
            updatedAt: Date())

        let text = TokenBarCLI.renderOpenAIWebDashboardText(snapshot)

        #expect(text.contains("Web session: user@example.com"))
        #expect(text.contains("Code review: 45% remaining (Resets in "))
        #expect(text.contains("Web history: 1 events"))
    }

    @Test
    func `maps errors to exit codes`() {
        #expect(TokenBarCLI.mapError(CodexStatusProbeError.codexNotInstalled) == ExitCode(2))
        #expect(TokenBarCLI.mapError(CodexStatusProbeError.timedOut) == ExitCode(4))
        #expect(TokenBarCLI.mapError(UsageError.noRateLimitsFound) == ExitCode(3))
    }

    @Test
    func `provider selection falls back to both for primary pair`() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .claude])
        switch selection {
        case .both:
            break
        default:
            #expect(Bool(false))
        }
    }

    @Test
    func `provider selection falls back to custom when non primary`() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .gemini])
        switch selection {
        case let .custom(providers):
            #expect(providers == [.codex, .gemini])
        default:
            #expect(Bool(false))
        }
    }

    @Test
    func `provider selection defaults to codex when empty`() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [])
        switch selection {
        case let .single(provider):
            #expect(provider == .codex)
        default:
            #expect(Bool(false))
        }
    }

    @Test
    func `decodes source and timeout options`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--web-timeout", "45", "--source", "oauth"])
        #expect(TokenBarCLI._decodeWebTimeoutForTesting(from: parsed) == 45)
        #expect(TokenBarCLI._decodeSourceModeForTesting(from: parsed) == .oauth)

        let parsedWeb = try parser.parse(arguments: ["--web"])
        #expect(TokenBarCLI._decodeSourceModeForTesting(from: parsedWeb) == .web)
    }

    @Test
    func `should use color respects format and flags`() {
        #expect(!TokenBarCLI.shouldUseColor(noColor: true, format: .text))
        #expect(!TokenBarCLI.shouldUseColor(noColor: false, format: .json))
    }

    @Test
    func `kilo usage text notes show fallback only for auto resolved to CLI`() {
        #expect(TokenBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .auto,
            resolvedSourceLabel: "cli") == ["Using CLI fallback"])
        #expect(TokenBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .api,
            resolvedSourceLabel: "cli").isEmpty)
        #expect(TokenBarCLI.usageTextNotes(
            provider: .codex,
            sourceMode: .auto,
            resolvedSourceLabel: "cli").isEmpty)
    }

    @Test
    func `kilo auto fallback summary includes ordered attempt details`() {
        let attempts = [
            ProviderFetchAttempt(
                strategyID: "kilo.api",
                kind: .apiToken,
                wasAvailable: true,
                errorDescription: "Kilo authentication failed (401/403)."),
            ProviderFetchAttempt(
                strategyID: "kilo.cli",
                kind: .cli,
                wasAvailable: true,
                errorDescription: "Kilo CLI session not found."),
        ]

        let summary = TokenBarCLI.kiloAutoFallbackSummary(
            provider: .kilo,
            sourceMode: .auto,
            attempts: attempts)
        let expected = [
            "Kilo auto fallback attempts: api: Kilo authentication failed (401/403).",
            " -> cli: Kilo CLI session not found.",
        ].joined()

        #expect(
            summary ==
                expected)
    }

    @Test
    func `kilo auto fallback summary is nil outside kilo auto failures`() {
        let attempts = [
            ProviderFetchAttempt(
                strategyID: "kilo.api",
                kind: .apiToken,
                wasAvailable: true,
                errorDescription: "example"),
        ]

        #expect(TokenBarCLI.kiloAutoFallbackSummary(
            provider: .kilo,
            sourceMode: .api,
            attempts: attempts) == nil)
        #expect(TokenBarCLI.kiloAutoFallbackSummary(
            provider: .codex,
            sourceMode: .auto,
            attempts: attempts) == nil)
    }

    @Test
    func `source mode requires web support is provider aware`() {
        #expect(TokenBarCLI.sourceModeRequiresWebSupport(.web, provider: .kilo))
        #expect(TokenBarCLI.sourceModeRequiresWebSupport(.auto, provider: .codex))
        #expect(!TokenBarCLI.sourceModeRequiresWebSupport(.auto, provider: .kilo))
        #expect(!TokenBarCLI.sourceModeRequiresWebSupport(.api, provider: .kilo))
    }
}
