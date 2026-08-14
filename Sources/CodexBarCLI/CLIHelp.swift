import CodexBarCore
import Foundation

extension CodexBarCLI {
    static func pluginsHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar plugins list
          tokenbar plugins fetch <id> [--json] [--pretty]

        Description:
          Discover local .js and .ts provider plugins. Fetch requires a recorded approval binding.
          An interactive terminal can create the approval after showing exact origins, capabilities,
          secret names, and cookie domains. Headless use fails closed. Browser-cookie plugins are
          app-only and fail closed in the CLI.
        """
    }

    static func cardsHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar cards [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                        [--provider \(ProviderHelp.list)]
                        [--account <label>] [--account-index <index>] [--all-accounts]
                        [--no-credits] [--no-color] [--status] [--source <auto|web|cli|oauth|api>]
                        [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]
                        [--brief]

        Description:
          Print a one-shot usage snapshot as a responsive card grid in the terminal.
          Honors enabled providers from config and reuses the same fetch flags as tokenbar usage.
          Failed providers are summarized in a footer instead of error cards.
          Enabled claude-swap lists with 2+ accounts—or one account when `claudeSwapShowSingleAccount`
          is enabled—replace Claude cards unless an account or explicit non-auto `--source` CLI flag is selected.
          Sentinel accounts remain visible without metrics; claude-swap adapter failures use a separate footer entry.
          Use --brief for a compact table layout (Provider / Usage / Reset).
          Stdout is always the rendered card/table text; --json-output only affects stderr logs.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          tokenbar cards
          tokenbar cards --provider codex
          tokenbar cards --provider all --status
          tokenbar cards --brief
          tokenbar cards --no-color
        """
    }

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
          Token accounts are loaded from the resolved TokenBar config file.
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
                       [--no-color] [--pretty] [--refresh] [--provider-native-only]
                       [--days <days>] [--group-by project]

        Description:
          Print token cost usage from supported local logs and authenticated provider APIs.
          Local scans use cached results unless --refresh is provided; remote sources may require provider credentials.
          OpenRouter Activity requires a management key and reports the latest completed UTC days for the account.
          Experimental: use --provider-native-only to exclude pi and OMP session mirrors.

        Examples:
          tokenbar cost
          tokenbar cost --provider codex --group-by project
          tokenbar cost --provider claude --format json --pretty
          tokenbar cost --provider openrouter
        """
    }

    static func sessionsHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar sessions [--json|--json-v2] [--pretty]
          tokenbar sessions focus <id>

        Description:
          List live local Codex, Claude Code, pi, and OMP agent sessions.
          --json emits the legacy v1 array with only Codex and Claude providers.
          --json-v2 emits the complete current array, including Pi-family sessions.
          JSON uses stable AgentSession field names and ISO-8601 dates.
          Focus activates the owning terminal or desktop app on macOS.

        Examples:
          tokenbar sessions
          tokenbar sessions --json
          tokenbar sessions --json-v2
          tokenbar sessions focus 019f3497-73bf-7df3-a173-4f67d968914a
        """
    }

    static func dashboardHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar dashboard [--pretty] [--timeout <seconds>] [--output <path>]
                             [--identity <redacted|full>]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]

        Description:
          Print one dashboard-v1 snapshot as JSON, then exit. Honors enabled providers
          in stable order and keeps provider failures as row-level errors without
          dropping healthy rows. Account identity defaults to full emails;
          --identity redacted hides email local parts.
          Stdout contains only the JSON document; diagnostics are written to stderr.
          --timeout accepts 0...86400 seconds and defaults to 30; 0 disables the deadline.
          --output atomically writes the snapshot to a file (0644) instead of stdout;
          the parent directory must already exist (it is not created), and nothing is
          printed to stdout on success.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          tokenbar dashboard
          tokenbar dashboard --pretty
          tokenbar dashboard --timeout 60
          tokenbar dashboard --output /var/www/dashboard/snapshot.json
        """
    }

    static func serveHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar serve [--host <host>] [--port <port>] [--refresh-interval <seconds>]
                         [--request-timeout <seconds>]
                         [--dashboard-token <token>] [--allow-plain-http]
                         [--identity <redacted|full>]
                         [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                         [-v|--verbose]

        Description:
          Start a foreground HTTP server that exposes existing CLI JSON payloads and a
          token-gated dashboard snapshot, with a built-in web UI at /. The static web UI
          is always open; it sends a browser-entered token only when fetching snapshot data.
          The server binds to 127.0.0.1 by default; `localhost` is normalized to 127.0.0.1.
          GET /dashboard/v1/snapshot requires "Authorization: Bearer YOUR_TOKEN" and fails
          closed (401) when no token is configured. Set the token with --dashboard-token or,
          preferably, the CODEXBAR_DASHBOARD_TOKEN environment variable (argv leaks via ps).
          Transport is plain HTTP: the token crosses the network in cleartext on every
          request. A non-loopback --host therefore requires both a dashboard token and
          --allow-plain-http, which records that you accept that trade-off. On a
          non-loopback host the token also gates /usage and /cost (account data);
          / and /health are always open. Use a TLS-terminating reverse proxy for anything
          beyond a trusted network segment.
          Snapshot identity defaults to full account emails. --identity redacted hides
          email local parts and is recommended whenever responses cross a network.

        Endpoints:
          GET /                    Built-in web dashboard
          GET /health
          GET /usage
          GET /usage?provider=claude
          GET /usage?provider=all
          GET /cost
          GET /cost?provider=codex
          GET /dashboard/v1/snapshot

        Examples:
          tokenbar serve
          tokenbar serve --port 8080 --refresh-interval 60 --request-timeout 30
          CODEXBAR_DASHBOARD_TOKEN=YOUR_TOKEN tokenbar serve
          CODEXBAR_DASHBOARD_TOKEN=... tokenbar serve --host 0.0.0.0 --allow-plain-http
          curl http://127.0.0.1:8080/usage?provider=all
          curl -H "Authorization: Bearer $CODEXBAR_DASHBOARD_TOKEN" \\
            http://127.0.0.1:8080/dashboard/v1/snapshot
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
          tokenbar config dump [--show-secrets] [--format text|json]
                             [--json]
                             [--json-only]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]
                             [--pretty]
          tokenbar config providers [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config enable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config disable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          tokenbar config set-api-key --provider <name> (--api-key <key>|--stdin)
                                    [--label <label>] [--usage-scope team]
                                    [--organization-id <org>] [--workspace-id <project>]
                                    [--no-enable]
                                    [--format text|json] [--json] [--json-only] [--pretty]

        Description:
          Validate or print the TokenBar config file (default: validate).
          dump prints normalized config JSON with stored credentials redacted by default
          (use --show-secrets to reveal raw values).
          providers lists persistent provider enablement.
          enable/disable updates the same provider toggle used by Settings.
          set-api-key stores a provider API key in the resolved config file and enables that provider by default.
          For z.ai team usage, add --usage-scope team with BigModel organization and project IDs; this stores
          the key as a token account instead of a provider-level personal key.

        Examples:
          tokenbar config validate --format json --pretty
          tokenbar config dump --pretty
          tokenbar config providers
          tokenbar config enable --provider grok
          tokenbar config disable --provider cursor
          printf '%s' "$ELEVENLABS_API_KEY" | tokenbar config set-api-key --provider elevenlabs --stdin
          printf '%s' "$Z_AI_API_KEY" | tokenbar config set-api-key --provider zai --stdin \\
            --label Team --usage-scope team --organization-id org_... --workspace-id proj_...
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

    static func hooksHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar hooks list [--format text|json] [--pretty]
          tokenbar hooks enable
          tokenbar hooks disable
          tokenbar hooks test <event> --provider <name>
          tokenbar hooks watch [--interval <seconds>] [--provider <name>]

        Description:
          Run external commands when quota/provider events occur. Rules are stored in the
          shared config file and are disabled by default. Events:
          quota_low, quota_reached, quota_reset, provider_unavailable, provider_recovered,
          refresh_failed.

          Commands run directly (no shell), receive event metadata via CODEXBAR_* environment
          variables and a JSON payload on stdin, and are timed out. Only configure commands you trust.

          `watch` polls the selected providers and fires rules on real transitions, so hooks
          work without the macOS app. Events are edge-triggered against the previous poll, so a
          persisting condition does not re-fire. Baselines are in-memory: the first poll of a
          lane establishes state without firing. Keep one continuous process running so transition
          baselines and event rate limits survive between polls. Default interval 300s, minimum 60s.

        Examples:
          tokenbar hooks list
          tokenbar hooks enable
          tokenbar hooks test quota_reached --provider codex
          tokenbar hooks test quota_low --provider claude
          tokenbar hooks watch --interval 600
          tokenbar hooks watch --provider codex
        """
    }

    static func diagnoseHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar diagnose --provider <name|all> --format json
                           [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                           [-v|--verbose]
                           [--redact] [--output <path>]
                           [--pretty]

        Description:
          Run provider diagnostic fetches and print a safe JSON export for issue reporting.
          The export is redacted and omits raw API tokens, cookies, auth headers, emails,
          account IDs, org IDs, raw responses, and billing-history records.

        Examples:
          tokenbar diagnose --provider minimax --format json --redact --output diagnostic.json
          tokenbar diagnose --provider minimax --format json --pretty
          tokenbar diagnose --provider claude --format json --pretty
          tokenbar diagnose --provider all --format json
        """
    }

    static func cookieHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar cookie refresh <--provider <name>|--all>
                                 [--allow-keychain-prompt]
                                 [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--pretty]

        Description:
          Re-import browser cookies using each provider's configured browser order.
          Providers that may decrypt Chromium cookies fail before clearing the cache
          unless --allow-keychain-prompt explicitly acknowledges a possible macOS
          Keychain prompt. A prior denial keeps its six-hour cooldown unless that
          explicit interactive retry flag is supplied. Cookie values are never shown.

        Examples:
          tokenbar cookie refresh --provider opencodego --allow-keychain-prompt
          tokenbar cookie refresh --all --allow-keychain-prompt
          tokenbar cookie refresh --provider opencodego --allow-keychain-prompt --format json --pretty
        """
    }

    static func guardHelp(version: String) -> String {
        """
        TokenBar \(version)

        Usage:
          tokenbar guard --provider \(ProviderHelp.list)
                        [--min-remaining <percent>] [--window session|weekly]
                        [--timeout <seconds>] [--json] [--pretty] [--fail-open]
                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]

        Description:
          Exit non-zero when a provider lacks quota headroom, for use in gating scripts.
          Stable guard exit codes: 0 = safe (relevant window has at least --min-remaining% remaining),
                                   1 = insufficient quota, 64 = invalid arguments,
                                   69 = quota unavailable or fetch timed out.
          --min-remaining defaults to 10 (percent). --window defaults to session (the primary window);
          weekly checks the secondary window. --timeout accepts 0...86400 and defaults to 60 seconds;
          0 disables the guard-level deadline, but provider-specific timeouts still apply.
          --fail-open exits 0 instead of 69 when quota is unavailable.
          Human output is a single line to stdout; --json emits a machine-readable decision object.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          tokenbar guard --provider claude
          tokenbar guard --provider codex --min-remaining 20
          tokenbar guard --provider claude --window weekly --min-remaining 5
          tokenbar guard --provider claude --json
          tokenbar guard --provider codex --fail-open
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
          tokenbar cards [--provider \(ProviderHelp.list)] [--brief] [--no-color] [--status]
          tokenbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)] [--no-color] [--pretty] [--refresh]
                       [--provider-native-only]
                       [--days <days>] [--group-by project]
          tokenbar sessions [--json|--json-v2] [--pretty]
          tokenbar sessions focus <id>
          tokenbar dashboard [--pretty] [--timeout <seconds>] [--output <path>]
          tokenbar serve [--host <host>] [--port <port>] [--refresh-interval <seconds>]
                       [--request-timeout <seconds>]
                       [--dashboard-token <token>] [--allow-plain-http]
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
          tokenbar config set-api-key --provider zai --stdin --usage-scope team
                                   --organization-id <org> --workspace-id <project>
          tokenbar hooks <list|enable|disable> [--format text|json] [--pretty]
          tokenbar hooks test <event> --provider <name>
          tokenbar plugins <list|fetch <id>> [--json] [--pretty]
          tokenbar cache clear <--cookies|--cost|--all> [--provider <name>]
          tokenbar cookie refresh <--provider <name>|--all> [--allow-keychain-prompt]
          tokenbar diagnose --provider <name|all> --format json [--redact] [--output <path>] [--pretty]
          tokenbar guard --provider <name> [--min-remaining <percent>] [--window session|weekly] [--json]

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
          tokenbar cards --provider all --status
          tokenbar cards --brief
          tokenbar cost --provider claude --format json --pretty
          tokenbar cost --provider openrouter
          tokenbar sessions --json
          tokenbar dashboard --pretty
          tokenbar serve --port 8080
          tokenbar config validate --format json --pretty
          tokenbar config enable --provider grok
          tokenbar config set-api-key --provider elevenlabs --stdin
          tokenbar hooks test quota_reached --provider codex
          tokenbar plugins list
          tokenbar cache clear --cookies
          tokenbar cookie refresh --provider opencodego --allow-keychain-prompt
          tokenbar diagnose --provider minimax --format json --redact --output diagnostic.json
          tokenbar diagnose --provider minimax --format json --pretty
          tokenbar diagnose --provider all --format json
          tokenbar guard --provider claude --min-remaining 20
        """
    }
}
