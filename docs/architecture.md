---
summary: "Architecture overview: modules, entry points, and data flow."
read_when:
  - Reviewing architecture before feature work
  - Refactoring app structure, app lifecycle, or module boundaries
---

# Architecture overview

## Modules
- `Sources/TokenBarCore`: fetch + parse (Codex RPC, PTY runner, Claude probes, OpenAI web scraping, status polling).
- `Sources/TokenBar`: state + UI (UsageStore, SettingsStore, StatusItemController, menus, icon rendering).
- `Sources/TokenBarWidget`: WidgetKit extension wired to the shared snapshot.
- `Sources/TokenBarCLI`: bundled CLI for `tokenbar` usage/status output.
- `Sources/TokenBarMacros`: SwiftSyntax macros for provider registration.
- `Sources/TokenBarMacroSupport`: shared macro support used by app/core/CLI targets.
- `Sources/TokenBarClaudeWatchdog`: helper process for stable Claude CLI PTY sessions.
- `Sources/TokenBarClaudeWebProbe`: CLI helper to diagnose Claude web fetches.

## Entry points
- `TokenBarApp`: SwiftUI keepalive + Settings scene.
- `AppDelegate`: wires status controller, Sparkle updater, notifications.

## Data flow
- Background refresh → `UsageFetcher`/provider probes → `UsageStore` → menu/icon/widgets.
- Settings toggles feed `SettingsStore` → `UsageStore` refresh cadence + feature flags.

## Concurrency & platform
- Swift 6 strict concurrency enabled; prefer Sendable state and explicit MainActor hops.
- macOS 14+ targeting; avoid deprecated APIs when refactoring.

See also: `docs/providers.md`, `docs/refresh-loop.md`, `docs/ui.md`.
