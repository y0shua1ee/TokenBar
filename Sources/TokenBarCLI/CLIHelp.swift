import Foundation
import TokenBarCore

extension TokenBarCLI {
    static func usageHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar usage [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--account <label>] [--account-index <index>] [--all-accounts]
                       [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                       [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]

        Description:
          Print usage from enabled providers as text (default) or JSON. Honors your in-app toggles.
          Output format: use --json (or --format json) for JSON on stdout; use --json-output for JSON logs on stderr.
          Source behavior is provider-specific:
          - Codex: OpenAI web dashboard (usage limits, credits remaining, code review remaining, usage breakdown).
            Auto falls back to Codex CLI only when cookies are missing.
          - Claude: claude.ai API.
            Auto falls back to Claude CLI only when cookies are missing.
          - Kilo: app.kilo.ai API.
            Auto falls back to Kilo CLI when API credentials are missing or unauthorized.
          Token accounts are loaded from ~/.tokenbar/config.json.
          Use --account or --account-index to select a specific token account.
          Use --all-accounts to fetch every token account, or every visible Codex account for Codex.
          Account selection requires a single provider.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          tokenbar usage
          tokenbar usage --provider claude
          tokenbar usage --provider gemini
          tokenbar usage --format json --provider all --pretty
          tokenbar usage --provider all --json
          tokenbar usage --status
          tokenbar usage --provider codex --source web --format json --pretty
        """
    }

    static func costHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--no-color] [--pretty] [--refresh]

        Description:
          Print token cost usage from Claude/Codex native logs, supported pi sessions, and Krill API stats.
          Native-log providers use cached scan results unless --refresh is provided.

        Examples:
          tokenbar cost
          tokenbar cost --provider claude --format json --pretty
          tokenbar cost --provider krill --format json --pretty
        """
    }

    static func serveHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          codexbar serve [--port <port>] [--refresh-interval <seconds>]
                         [--request-timeout <seconds>]
                         [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                         [-v|--verbose]

        Description:
          Start a foreground localhost-only HTTP server that exposes existing CLI JSON payloads.
          The server binds to 127.0.0.1 only in this initial version.

        Endpoints:
          GET /health
          GET /usage
          GET /usage?provider=claude
          GET /usage?provider=all
          GET /cost
          GET /cost?provider=codex

        Examples:
          codexbar serve
          codexbar serve --port 8080 --refresh-interval 60 --request-timeout 30
          curl http://127.0.0.1:8080/usage?provider=all
        """
    }

    static func configHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar config validate [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                 [-v|--verbose]
                                 [--pretty]
          tokenbar config dump [--format text|json]
                             [--json]
                             [--json-only]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]
                             [--pretty]
          tokenbar config providers [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config enable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config disable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config set-api-key --provider <name> (--api-key <key>|--stdin)
                                    [--no-enable]
                                    [--format text|json] [--json] [--json-only] [--pretty]

        Description:
          Validate or print the TokenBar config file (default: validate).
          providers lists persistent provider enablement.
          enable/disable updates the same provider toggle used by Settings.
          set-api-key stores a provider API key in ~/.tokenbar/config.json and enables that provider by default.

        Examples:
          tokenbar config validate --format json --pretty
          tokenbar config dump --pretty
          tokenbar config providers
          tokenbar config enable --provider grok
          tokenbar config disable --provider cursor
          printf '%s' "$ELEVENLABS_API_KEY" | tokenbar config set-api-key --provider elevenlabs --stdin
        """
    }

    static func cacheHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar cache clear <--cookies|--cost|--all>
                              [--provider <name>]
                              [--format text|json]
                              [--json]
                              [--json-only]
                              [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                              [-v|--verbose]
                              [--pretty]

        Description:
          Clear cached data. Use --cookies to clear browser cookie caches (stored in Keychain),
          --cost to clear cost usage scan caches, or --all for both.
          Optionally specify --provider with --cookies to clear cookies for a single provider only.

        Examples:
          tokenbar cache clear --cookies
          tokenbar cache clear --cookies --provider claude
          tokenbar cache clear --cost
          tokenbar cache clear --all
          tokenbar cache clear --all --format json --pretty
        """
    }

    static func diagnoseHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar diagnose --provider <name|all> --format json
                           [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                           [-v|--verbose]
                           [--pretty]

        Description:
          Run provider diagnostic fetches and print a safe JSON export for issue reporting.
          The export is redacted and omits raw API tokens, cookies, auth headers, emails,
          account IDs, org IDs, raw responses, and billing-history records.

        Examples:
          tokenbar diagnose --provider minimax --format json --pretty
          tokenbar diagnose --provider claude --format json --pretty
          tokenbar diagnose --provider all --format json
        """
    }

    static func rootHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar [--format text|json]
                  [--json]
                  [--json-only]
                  [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                  [--provider \(ProviderHelp.list)]
                  [--account <label>] [--account-index <index>] [--all-accounts]
                  [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                  [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]
          tokenbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)] [--no-color] [--pretty] [--refresh]
          codexbar serve [--port <port>] [--refresh-interval <seconds>]
                       [--request-timeout <seconds>]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
          tokenbar config <validate|dump|providers> [--format text|json]
                                        [--json]
                                        [--json-only]
                                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                        [-v|--verbose]
                                        [--pretty]
          tokenbar config enable --provider <name>
          tokenbar config disable --provider <name>
          tokenbar config set-api-key --provider <name> (--api-key <key>|--stdin)
          tokenbar cache clear <--cookies|--cost|--all> [--provider <name>]
          tokenbar diagnose --provider <name|all> --format json [--pretty]

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          tokenbar
          tokenbar --format json --provider all --pretty
          tokenbar --provider all --json
          tokenbar --provider gemini
          tokenbar cost --provider claude --format json --pretty
          tokenbar serve --port 8080
          tokenbar config validate --format json --pretty
          tokenbar config enable --provider grok
          tokenbar config set-api-key --provider elevenlabs --stdin
          tokenbar cache clear --cookies
          tokenbar diagnose --provider minimax --format json --pretty
          tokenbar diagnose --provider all --format json
        """
    }
}
