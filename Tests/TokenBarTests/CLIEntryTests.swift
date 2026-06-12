import Commander
import Foundation
import XCTest
@testable import TokenBarCLI
@testable import TokenBarCore

final class CLIEntryTests: XCTestCase {
    func test_effectiveArgvDefaultsToUsage() {
        XCTAssertEqual(TokenBarCLI.effectiveArgv([]), ["usage"])
        XCTAssertEqual(TokenBarCLI.effectiveArgv(["--json"]), ["usage", "--json"])
        XCTAssertEqual(TokenBarCLI.effectiveArgv(["usage", "--json"]), ["usage", "--json"])
    }

    func test_decodesFormatFromOptionsAndFlags() {
        let jsonOption = ParsedValues(positional: [], options: ["format": ["json"]], flags: [])
        XCTAssertEqual(TokenBarCLI._decodeFormatForTesting(from: jsonOption), .json)

        let jsonFlag = ParsedValues(positional: [], options: [:], flags: ["json"])
        XCTAssertEqual(TokenBarCLI._decodeFormatForTesting(from: jsonFlag), .json)

        let textDefault = ParsedValues(positional: [], options: [:], flags: [])
        XCTAssertEqual(TokenBarCLI._decodeFormatForTesting(from: textDefault), .text)
    }

    func test_providerSelectionPrefersOverride() {
        let selection = TokenBarCLI.providerSelection(rawOverride: "codex", enabled: [.claude, .gemini])
        XCTAssertEqual(selection.asList, [.codex])
    }

    func test_normalizeVersionExtractsNumeric() {
        XCTAssertEqual(TokenBarCLI.normalizeVersion(raw: "codex 1.2.3 (build 4)"), "1.2.3")
        XCTAssertEqual(TokenBarCLI.normalizeVersion(raw: "  v2.0  "), "2.0")
    }

    func test_makeHeaderIncludesVersionWhenAvailable() {
        let header = TokenBarCLI.makeHeader(provider: .codex, version: "1.2.3", source: "cli")
        XCTAssertTrue(header.contains("Codex"))
        XCTAssertTrue(header.contains("1.2.3"))
        XCTAssertTrue(header.contains("cli"))
    }

    func test_cliVersionFallsBackToContainingAppBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-\(UUID().uuidString)", isDirectory: true)
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

        XCTAssertEqual(TokenBarCLI.containingAppVersion(for: helperURL), "9.8.7")
    }

    func test_cliVersionFollowsSymlinkedHelper() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-symlink-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("TokenBar.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "2.4.6"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)

        let symlinkURL = binURL.appendingPathComponent("tokenbar")
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: helperURL)

        XCTAssertEqual(TokenBarCLI.currentVersion(bundleVersion: nil, executablePath: symlinkURL.path), "2.4.6")
    }

    func test_cliVersionFallsBackToAdjacentVersionFile() throws {
        try self.expectAdjacentVersionFile(raw: "v3.2.1\n", expected: "3.2.1")
        try self.expectAdjacentVersionFile(raw: "3.2.2\n", expected: "3.2.2")
        try self.expectAdjacentVersionFile(raw: "version-3.2.3\n", expected: "version-3.2.3")
    }

    func test_cliVersionPrefersAdjacentVersionOverStandaloneBundleName() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-bundle-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let helperURL = binURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)
        try "4.5.6\n".write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: false,
            encoding: .utf8)

        XCTAssertEqual(
            TokenBarCLI.currentVersion(bundleVersion: "TokenBar", executablePath: helperURL.path),
            "4.5.6")
    }

    func test_cliVersionPrefersAdjacentVersionOverContainingAppBundle() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-app-adjacent-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let appURL = root.appendingPathComponent("TokenBar.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let helpersURL = contentsURL.appendingPathComponent("Helpers", isDirectory: true)
        try FileManager.default.createDirectory(at: helpersURL, withIntermediateDirectories: true)

        let infoURL = contentsURL.appendingPathComponent("Info.plist")
        let plist: [String: Any] = ["CFBundleShortVersionString": "8.8.8"]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: infoURL)

        let helperURL = helpersURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)
        try "5.6.7\n".write(
            to: helpersURL.appendingPathComponent("VERSION"),
            atomically: false,
            encoding: .utf8)

        XCTAssertEqual(TokenBarCLI.currentVersion(bundleVersion: nil, executablePath: helperURL.path), "5.6.7")
    }

    func test_cliVersionFallsBackToBundleVersion() {
        XCTAssertEqual(TokenBarCLI.currentVersion(bundleVersion: "7.8.9", executablePath: nil), "7.8.9")
        XCTAssertNil(TokenBarCLI.currentVersion(bundleVersion: "TokenBar", executablePath: nil))
    }

    private func expectAdjacentVersionFile(raw: String, expected: String) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("tokenbar-cli-version-file-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let binURL = root.appendingPathComponent("bin", isDirectory: true)
        try FileManager.default.createDirectory(at: binURL, withIntermediateDirectories: true)

        let helperURL = binURL.appendingPathComponent("TokenBarCLI")
        try Data().write(to: helperURL)
        try raw.write(
            to: binURL.appendingPathComponent("VERSION"),
            atomically: false,
            encoding: .utf8)

        XCTAssertEqual(TokenBarCLI.currentVersion(bundleVersion: nil, executablePath: helperURL.path), expected)
    }

    func test_renderOpenAIWebDashboardTextIncludesSummary() {
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

        XCTAssertTrue(text.contains("Web session: user@example.com"))
        XCTAssertTrue(text.contains("Code review: 45% remaining (Resets in "))
        XCTAssertTrue(text.contains("Web history: 1 events"))
    }

    func test_mapsErrorsToExitCodes() {
        XCTAssertEqual(TokenBarCLI.mapError(CodexStatusProbeError.codexNotInstalled), ExitCode(2))
        XCTAssertEqual(TokenBarCLI.mapError(CodexStatusProbeError.timedOut), ExitCode(4))
        XCTAssertEqual(TokenBarCLI.mapError(UsageError.noRateLimitsFound), ExitCode(3))
    }

    func test_antigravityPlanDebugKeepsOneShotHelperAliveUntilDebugFetch() {
        XCTAssertTrue(TokenBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: false))
        XCTAssertFalse(TokenBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .codex,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: false))
        XCTAssertFalse(TokenBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: true,
            persistsCLISessions: false))
        XCTAssertFalse(TokenBarCLI.holdsAntigravityCLISessionForPlanDebug(
            provider: .antigravity,
            planDebugEnabled: true,
            jsonOnly: false,
            persistsCLISessions: true))
    }

    func test_missingCodexBinaryErrorPayloadUsesInstallGuidance() {
        let payload = TokenBarCLI.makeErrorPayload(CodexStatusProbeError.codexNotInstalled, kind: .provider)

        XCTAssertEqual(payload.code, ExitCode.binaryNotFound.rawValue)
        XCTAssertTrue(payload.message.contains("Codex CLI missing"))
        XCTAssertFalse(payload.message.contains("Codex not running"))
    }

    func test_providerSelectionFallsBackToBothForPrimaryPair() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .claude])
        switch selection {
        case .both:
            break
        default:
            XCTFail("Expected both selection")
        }
    }

    func test_providerSelectionFallsBackToCustomWhenNonPrimary() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [.codex, .gemini])
        switch selection {
        case let .custom(providers):
            XCTAssertEqual(providers, [.codex, .gemini])
        default:
            XCTFail("Expected custom selection")
        }
    }

    func test_providerSelectionHonorsEmptyEnabledSet() {
        let selection = TokenBarCLI.providerSelection(rawOverride: nil, enabled: [])
        switch selection {
        case let .custom(providers):
            XCTAssertEqual(providers, [])
        default:
            XCTFail("Expected empty custom selection")
        }
    }

    func test_decodesSourceAndTimeoutOptions() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--web-timeout", "45", "--source", "oauth"])
        XCTAssertEqual(TokenBarCLI._decodeWebTimeoutForTesting(from: parsed), 45)
        XCTAssertEqual(TokenBarCLI._decodeSourceModeForTesting(from: parsed), .oauth)

        let parsedWeb = try parser.parse(arguments: ["--web"])
        XCTAssertEqual(TokenBarCLI._decodeSourceModeForTesting(from: parsedWeb), .web)
    }

    func test_shouldUseColorRespectsFormatAndFlags() {
        XCTAssertFalse(TokenBarCLI.shouldUseColor(noColor: true, format: .text))
        XCTAssertFalse(TokenBarCLI.shouldUseColor(noColor: false, format: .json))
    }

    func test_kiloUsageTextNotesShowFallbackOnlyForAutoResolvedToCLI() {
        XCTAssertEqual(TokenBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .auto,
            resolvedSourceLabel: "cli"), ["Using CLI fallback"])
        XCTAssertTrue(TokenBarCLI.usageTextNotes(
            provider: .kilo,
            sourceMode: .api,
            resolvedSourceLabel: "cli").isEmpty)
        XCTAssertTrue(TokenBarCLI.usageTextNotes(
            provider: .codex,
            sourceMode: .auto,
            resolvedSourceLabel: "cli").isEmpty)
    }

    func test_kiloAutoFallbackSummaryIncludesOrderedAttemptDetails() {
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

        XCTAssertEqual(summary, expected)
    }

    func test_kiloAutoFallbackSummaryIsNilOutsideKiloAutoFailures() {
        let attempts = [
            ProviderFetchAttempt(
                strategyID: "kilo.api",
                kind: .apiToken,
                wasAvailable: true,
                errorDescription: "example"),
        ]

        XCTAssertNil(TokenBarCLI.kiloAutoFallbackSummary(
            provider: .kilo,
            sourceMode: .api,
            attempts: attempts))
        XCTAssertNil(TokenBarCLI.kiloAutoFallbackSummary(
            provider: .codex,
            sourceMode: .auto,
            attempts: attempts))
    }

    func test_sourceModeRequiresWebSupportIsProviderAware() {
        XCTAssertTrue(TokenBarCLI.sourceModeRequiresWebSupport(.web, provider: .kilo))
        XCTAssertTrue(TokenBarCLI.sourceModeRequiresWebSupport(.auto, provider: .codex))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(.auto, provider: .kilo))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(.auto, provider: .grok))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(.web, provider: .grok))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(.api, provider: .kilo))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .ollama,
            environment: ["OLLAMA_API_KEY": "ollama-test"]))
        XCTAssertFalse(TokenBarCLI.sourceModeRequiresWebSupport(
            .auto,
            provider: .ollama,
            settings: ProviderSettingsSnapshot.make(
                ollama: .init(cookieSource: .off, manualCookieHeader: nil))))
    }
}
