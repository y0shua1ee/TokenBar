import Commander
import Testing
import TokenBarCore
@testable import TokenBarCLI

struct CLIArgumentParsingTests {
    @Test
    func `json shortcut does not enable json logs`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json"])

        #expect(parsed.flags.contains("jsonShortcut"))
        #expect(!parsed.flags.contains("jsonOutput"))
        #expect(TokenBarCLI._decodeFormatForTesting(from: parsed) == .json)
    }

    @Test
    func `json output flag enables json logs`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json-output"])

        #expect(parsed.flags.contains("jsonOutput"))
        #expect(!parsed.flags.contains("jsonShortcut"))
        #expect(TokenBarCLI._decodeFormatForTesting(from: parsed) == .text)
    }

    @Test
    func `log level and verbose are parsed`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--log-level", "info", "--verbose"])

        #expect(parsed.flags.contains("verbose"))
        #expect(parsed.options["logLevel"] == ["info"])
    }

    @Test
    func `resolved log level defaults to error`() {
        #expect(TokenBarCLI.resolvedLogLevel(verbose: false, rawLevel: nil) == .error)
        #expect(TokenBarCLI.resolvedLogLevel(verbose: true, rawLevel: nil) == .debug)
        #expect(TokenBarCLI.resolvedLogLevel(verbose: false, rawLevel: "info") == .info)
    }

    @Test
    func `format option overrides json shortcut`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json", "--format", "text"])

        #expect(parsed.flags.contains("jsonShortcut"))
        #expect(parsed.options["format"] == ["text"])
        #expect(TokenBarCLI._decodeFormatForTesting(from: parsed) == .text)
    }

    @Test
    func `json only enables json format`() throws {
        let signature = TokenBarCLI._usageSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: ["--json-only"])

        #expect(parsed.flags.contains("jsonOnly"))
        #expect(!parsed.flags.contains("jsonOutput"))
        #expect(TokenBarCLI._decodeFormatForTesting(from: parsed) == .json)
    }

    @Test
    func `diagnose accepts json output flag but discards provider logs`() throws {
        let signature = TokenBarCLI._diagnoseSignatureForTesting()
        let parser = CommandParser(signature: signature)
        let parsed = try parser.parse(arguments: [
            "--provider", "minimax",
            "--format", "json",
            "--json-output",
        ])

        #expect(parsed.flags.contains("jsonOutput"))
        let config = TokenBarCLI.loggingConfiguration(path: ["diagnose"], values: parsed)
        switch config.destination {
        case .discard:
            break
        case .stderr, .oslog:
            Issue.record("diagnose should not emit provider logs beside the safe JSON export")
        }
    }
}
