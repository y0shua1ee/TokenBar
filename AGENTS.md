# Repository Guidelines

## Project Structure & Modules

- `Sources/CodexBar`: Swift 6 menu bar app (usage/credits probes, icon renderer, settings). Keep changes small and reuse existing helpers.
- `Tests/CodexBarTests`: XCTest coverage for usage parsing, status probes, icon patterns; mirror new logic with focused tests.
- `Scripts`: build/package helpers (`package_app.sh`, `sign-and-notarize.sh`, `make_appcast.sh`, `build_icon.sh`, `compile_and_run.sh`). Release wrappers call `Scripts/mac-release`, which resolves `MAC_RELEASE_TOOL` or the shared `agent-scripts` checkout.
- `docs`: release notes and process (`docs/RELEASING.md`, screenshots). Root-level zips/appcast are generated artifacts—avoid editing except during releases.

## Build, Test, Run

- Dev loop: `./Scripts/compile_and_run.sh` kills old instances, builds, packages, relaunches `TokenBar.app`, and confirms it stays running; add `--test` for the sharded full suite.
- Quick build/test: `swift build` (debug) or `swift build -c release`; `make test` for the sharded full suite.
- Package locally: `./Scripts/package_app.sh` to refresh `TokenBar.app`, then restart with `pkill -x TokenBar || pkill -f TokenBar.app || true; cd /Users/areslee/Documents/dev/active/TokenBar && open -n /Users/areslee/Documents/dev/active/TokenBar/TokenBar.app`.
- Release flow: `./Scripts/release.sh`; app metadata lives in `.mac-release.env`, repo build/signing stays in `Scripts/sign-and-notarize.sh`, and validation steps live in `docs/RELEASING.md`.

## Coding Style & Naming

- Enforce SwiftFormat/SwiftLint: run `swiftformat Sources Tests` and `swiftlint --strict`. 4-space indent, 120-char lines, explicit `self` is intentional—do not remove.
- Favor small, typed structs/enums; maintain existing `MARK` organization. Use descriptive symbols; match current commit tone.

## Testing Guidelines

- Add/extend XCTest cases under `Tests/CodexBarTests/*Tests.swift` (`FeatureNameTests` with `test_caseDescription` methods).
- Model names in tests/code: released models or clearly fictitious names only; never expose unreleased names.
- Always run `make test` before handoff; add focused `swift test --filter ...` runs for parser/provider fixes when possible.
- After any code change, run `make check` and fix all reported format/lint issues before handoff.
- Prefer CLI/focused tests over app-bundle live tests when behavior can be verified without relaunching TokenBar.
- Never run tests/checks or ad-hoc validation that can display macOS Keychain prompts. Live provider probes, browser-cookie imports, `tokenbar usage` against real accounts, and real SecItem reads must be explicitly requested; otherwise use parser tests, stubs, test stores, or `KeychainNoUIQuery`.
- macOS CI is brittle around headless AppKit status/menu tests. Prefer covering menu behavior through stable state/model seams (`MenuDescriptor`, `ProvidersPane`, `CodexAccountsSectionState`, etc.) instead of constructing live `NSStatusBar`/`NSMenu` flows unless the AppKit wiring itself is the thing under test.

## Commit & PR Guidelines

- Commit messages: short imperative clauses (e.g., “Improve usage probe”, “Fix icon dimming”); keep commits scoped.
- PRs/patches should list summary, commands run, screenshots/GIFs for UI changes, and linked issue/reference when relevant.

## Agent Notes

- Use the provided scripts and package manager (SwiftPM); avoid adding dependencies or tooling without confirmation.
- Menu bar automation: capture the target screen first and verify the TokenBar icon is visibly onscreen. Reject `click-extra` success when coordinates fall outside display bounds; hidden menu extras are not click proof.
- Validate UI/runtime behavior against the freshly built bundle; restart via the pkill+open command above to avoid running stale binaries.
- To guarantee the right bundle is running after a rebuild, use: `pkill -x TokenBar || pkill -f TokenBar.app || true; cd /Users/areslee/Documents/dev/active/TokenBar && open -n /Users/areslee/Documents/dev/active/TokenBar/TokenBar.app`.
- For CLI-testable provider/parser/settings behavior, use CLI/focused tests instead of `Scripts/package_app.sh` or `./Scripts/compile_and_run.sh`.
- Run `./Scripts/compile_and_run.sh` only when UI/runtime behavior needs bundle-level validation; it builds, tests, packages, relaunches, and verifies the app stays running.
- Widget/Tahoe UI issues: use Parallels macOS VM plus screenshots/clicks for autonomous verification.
- Release script: keep it in the foreground; do not background it—wait until it finishes.
- Personal/self-use releases: while the owner has no Apple Developer Program membership, use `Scripts/release-adhoc.sh --publish` after green gates. Do not require Developer ID notarization, Sparkle private-key validation, or `appcast.xml` updates for this ad-hoc/manual release mode unless the user explicitly asks for a formal public Sparkle release.
- Sparkle release key: use `.mac-release.env` `MAC_RELEASE_SIGNING_KEY_FILE`, the legacy `AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=` key. Do not use `sparkle-private-key-KEEP-SECURE.txt`; that is VibeTunnel's mismatched key.
- Swift concurrency: treat sibling `async let` tasks as a review red flag when one child is required and another is optional/best-effort. Prefer sequential awaits or a drained `withThrowingTaskGroup` that surfaces required failures and explicitly contains optional failures; crash stacks mentioning `swift_task_dealloc` or `asyncLet_finish_after_task_completion` should trigger an audit of nearby `async let` usage.
- Prefer modern SwiftUI/Observation macros: use `@Observable` models with `@State` ownership and `@Bindable` in views; avoid `ObservableObject`, `@ObservedObject`, and `@StateObject`.
- Favor modern macOS 15+ APIs over legacy/deprecated counterparts when refactoring (Observation, new display link APIs, updated menu item styling, etc.).
- Keep provider data siloed: when rendering usage or account info for a provider (Claude vs Codex), never display identity/plan fields sourced from a different provider.\*\*\*
- Claude CLI status line is custom + user-configurable; never rely on it for usage parsing.
- Cookie imports: default Chrome-only when possible to avoid other browser prompts; override via browser list when needed.

# Project Agent Guide

## Role split

This repository may be edited with both Codex App and Hermes.

- Codex App is the primary coding interface.
- Hermes is the memory curator and project continuity agent.
- The repository files are the source of truth for project state.
- Hermes memory is only for compact, durable facts.

## Project facts

Fill this section once the project is understood.

- Project name:
- Purpose:
- Tech stack:
- Main source directories:
- Package manager:
- Local dev command:
- Test command:
- Lint/typecheck command:
- Deployment target:

## Cross-agent handoff protocol

Before meaningful work:

- Read this `AGENTS.md`.
- Read `.ai/HANDOFF.md` if it exists.
- Read `.ai/DECISIONS.md` before changing architecture, APIs, database schema, auth, deployment, storage, or test strategy.

After non-trivial coding work, update `.ai/HANDOFF.md` with:

- Current goal
- Current state
- Files changed
- Tests run and results
- Decisions made
- Blockers / next steps
- Stable facts Hermes should review for memory

Non-trivial work includes:

- Implementing or removing a feature
- Fixing a bug that required investigation
- Refactoring more than one file
- Changing tests, build, CI, deployment, database, APIs, auth, or storage
- Discovering a durable project convention or environment quirk

Do not update `.ai/HANDOFF.md` for read-only questions or trivial edits.

## Durable decisions

Use `.ai/DECISIONS.md` for accepted technical decisions.

Record a decision when changing:

- Architecture
- Public API shape
- Database schema or migration strategy
- Authentication or authorization
- Deployment topology
- Storage model
- Testing strategy
- Long-term library/framework choice

Prefer appending a new decision entry over rewriting history. If a decision is superseded, add a new entry and mark the old one as superseded.

## Hermes memory policy

Hermes may save only compact, durable facts such as:

- Project path, purpose, and tech stack
- Stable commands for install, test, lint, dev, deploy
- Durable architecture decisions
- Persistent environment quirks
- Repeated user workflow preferences
- Known pitfalls that are likely to recur

Hermes should not save:

- Temporary TODOs
- One-off debugging state
- Raw logs or stack traces
- Secrets, tokens, keys, credentials, customer data, or private data
- Information already clearly documented in `AGENTS.md` unless it is a compact index to where that information lives

Codex must not directly edit `~/.hermes/memories/`, `MEMORY.md`, or `USER.md`.

## Security rules

Never write secrets into:

- `AGENTS.md`
- `.ai/HANDOFF.md`
- `.ai/DECISIONS.md`
- Git commits
- Agent memory

Use placeholders such as `<API_KEY_FROM_ENV>` when needed.

## Working style

When finishing a task, the final response should include:

- What changed
- Tests run
- Files touched
- Whether `.ai/HANDOFF.md` or `.ai/DECISIONS.md` was updated
- Any unresolved risks
