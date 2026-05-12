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
          Use --account or --account-index to select a specific token account, or --all-accounts to fetch all.
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

        Description:
          Validate or print the TokenBar config file (default: validate).

        Examples:
          tokenbar config validate --format json --pretty
          tokenbar config dump --pretty
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
          tokenbar config <validate|dump> [--format text|json]
                                        [--json]
                                        [--json-only]
                                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                        [-v|--verbose]
                                        [--pretty]
          tokenbar cache clear <--cookies|--cost|--all> [--provider <name>]

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
          tokenbar config validate --format json --pretty
          tokenbar cache clear --cookies
        """
    }
}
