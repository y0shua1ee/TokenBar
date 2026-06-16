# Upstream CodexBar Merge Handoff

## Current Goal

Merge latest upstream `steipete/CodexBar` into TokenBar on branch `codex/merge-upstream-codexbar-20260615`, preserving TokenBar fork identity, providers, release paths, and local menu behavior.

Follow-up goal: fix the main-thread review findings before this merge branch is considered ready to merge.

Current state: second review and integration validation are complete. A post-live-test menu-card fix for
OpenRouter/Krill cost-history displays has been applied and validated. A follow-up persistent Refresh spinner fix has
also been applied and validated. The latest packaged worktree app is running from
`/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app`.

## Upstream Source

- Remote: `upstream https://github.com/steipete/CodexBar.git`
- Merged source: `upstream/main`
- Upstream commit: `b1e52908934581bbe15c80a9117adf4d3d5705fd` (`fix: normalize website provider logos`)
- Note: fetching upstream tags hit local tag clobber conflicts, so the merge used `git fetch upstream main --no-tags` and `upstream/main`.

## Merge Strategy

- Direct merge produced hundreds of path/name conflicts because upstream uses CodexBar naming while this fork uses TokenBar naming and has prior squash/manual upstream sync history.
- Built a temporary mapped upstream tree with CodexBar paths and symbols converted to TokenBar equivalents, then layered TokenBar fork-specific files and behavior back in.
- Created the real merge relationship with `git merge -s ours --no-commit upstream/main`, then overlaid the tested resolved tree into this worktree.
- This keeps `upstream/main` as the second parent while preserving a resolved TokenBar file tree.

## Key Decisions Preserved

- Kept product/package semantics as TokenBar, including `TokenBar`, `TokenBarCLI`, widget naming, and `TokenBarTeamID`.
- Kept bundle/feed identity on the fork side: `com.y0shua1ee.tokenbar`, `com.y0shua1ee.tokenbar.debug`, and `https://raw.githubusercontent.com/y0shua1ee/TokenBar/main/appcast.xml`.
- Kept TokenBar-owned Keychain/cache/app-group names under `com.y0shua1ee.*` instead of upstream `com.steipete.*`.
- Kept local Custom and Krill providers and restored their descriptor/implementation registry entries after upstream macro removal.
- Kept DeepSeek dashboard cost support, OpenRouter activity/management-key support, and Krill remote cost support.
- Kept merged-menu detached auto-positioning behavior through `StatusItemController+MergedMenuPresentation.swift`.
- Updated `Scripts/lint.sh` to run SwiftLint with `--no-cache` so `make check` works in restricted worktrees where SwiftLint cannot write its default cache.

## Review Fixes Applied

- Restored Release CLI workflow dispatch/watch targets to `y0shua1ee/homebrew-tokenbar` and `repository=y0shua1ee/TokenBar`.
- Restored public README, website, CNAME, CLI docs, release docs, and release skill install/update links to TokenBar fork URLs and `y0shua1ee/tokenbar/tokenbar`.
- Restored `TokenBarCLI.resetTimeDisplayStyleFromDefaults()` to read `com.y0shua1ee.tokenbar` and `com.y0shua1ee.tokenbar.debug`.
- Restored DeepSeek dashboard login support by setting `supportsLoginFlow`, adding a DeepSeek dashboard menu action, and wiring `runLoginFlow` to `DeepSeekPlatformTokenManager.shared.loginViaWebView()`.
- Cleared trailing whitespace introduced by `docs/UPSTREAM_STRATEGY.md`.
- Added focused regression tests for the CLI defaults domain and DeepSeek dashboard login capability.

## Second Review Fixes Applied

- Restored remaining fork-local paths and release URLs in `AGENTS.md`, `Makefile`, `Scripts/generate-llms.mjs`, `Scripts/test_live_update.sh`, `docs/FORK_QUICK_START.md`, and regenerated `docs/llms.txt`.
- Updated the Kimi K2 settings documentation action to open `https://github.com/y0shua1ee/TokenBar/blob/main/docs/kimi-k2.md`.
- Added missing `custom` and `krill` provider IDs to `docs/configuration.md`.
- Fixed Krill menu descriptor rendering so quota details remain plain secondary rows instead of being rendered as `Resets ...` lines.
- Fixed DeepSeek optional usage summary handling so a slow or cancellation-ignoring optional summary cannot delay the required balance result, and parent cancellation cancels the optional summary promptly even if balance transport ignores cancellation.
- Aligned the merged-menu readiness test with current detached merged-menu presentation (`prepareMergedMenuForPresentation()` instead of `statusItem.menu`).
- Fixed merged provider switching so the first switch into an uncached tab keeps live menu row shells visible and caches displaced content instead of replacing rows.

## Post-Live-Test Fixes Applied

- Fixed OpenRouter and Krill menu cards so provider usage/quota fetch errors are suppressed in the header when a
  displayable cost-history snapshot is already available. The header now shows the cost snapshot freshness instead of a
  red `No available fetch strategy for openrouter.` or `Krill API HTTP 400` line.
- Kept the error visible when no cost history is available, so genuinely empty/misconfigured OpenRouter and Krill states
  still surface actionable failures.
- Moved shared menu-card subtitle calculation into `MenuCardView+ModelHelpers.swift` to stay under the SwiftLint
  `file_length` limit.
- Fixed the persistent bottom `Refresh` row so its spinner reflects only an explicit manual refresh click, not the
  global/background `UsageStore.isRefreshing` state. Background provider refreshes can still update provider subtitles,
  but they no longer make every provider tab's bottom action row look busy.
- Fixed merged-menu window drift after provider tab switches by realigning the open detached menu window to the status
  item anchor after content/height changes. This targets cases where switching providers leaves the panel floating in
  the middle/lower part of the screen instead of under the menu bar.

## Validation

- `swift build --disable-sandbox` in the temporary resolved tree: passed.
- `make check`: passed.
- `swift build --disable-sandbox`: passed after final identity/lint fixes.
- `swift test --disable-sandbox --filter ProviderConfigEnvironmentTests`: passed, 33 tests.
- Follow-up review fix validation:
  - `rg -n "steipete/CodexBar|steipete/homebrew-tap|steipete/tap/tokenbar|codexbar\\.app|brew install --cask tokenbar|com\\.steipete\\.tokenbar\\\"|com\\.steipete\\.tokenbar\\.debug" README.md docs/index.html docs/site.js docs/CNAME docs/cli.md docs/RELEASING.md docs/releasing-homebrew.md .github/workflows/release-cli.yml .agents/skills/release-codexbar/SKILL.md Sources/TokenBarCLI/CLIHelpers.swift`: no matches.
  - `git diff --check`: passed.
  - `swift test --disable-sandbox --filter 'ProviderSettingsDescriptorTests|CLIEntryTests'`: passed, 42 selected tests.
  - `make check`: passed.
- Second review validation:
  - `node Scripts/generate-llms.mjs`: passed, regenerated `docs/llms.txt`.
  - Static fork identity scan over `Sources/TokenBar`, `Sources/TokenBarCore`, `Scripts`, `docs`, `AGENTS.md`, `Makefile`, `.github`, `CHANGELOG.md`, and `appcast.xml`: only historical `appcast.xml` 0.29.1 CodexBar entry and historical `CHANGELOG.md` Homebrew text remain.
  - `git diff --check`: passed.
  - `make check`: passed.
  - `swift test --disable-sandbox --filter ConfigurationDocsProviderIDTests`: passed.
  - `swift test --disable-sandbox --filter MenuDescriptorKrillTests`: passed.
  - `swift test --disable-sandbox --filter DeepSeekUsageFetcherTests`: passed.
  - `swift test --disable-sandbox --filter StatusMenuReadinessBaselineTests`: passed.
  - `swift test --disable-sandbox --filter StatusMenuSwitcherRefreshTests`: passed.
  - `swift test --disable-sandbox --parallel --num-workers 1 --filter 'ProviderRegistryTests|ProviderSettingsDescriptorTests|DocumentationLinkTests|ProviderConfigEnvironmentTests|StatusMenuReadinessBaselineTests|StatusMenuSwitcherRefreshTests|MenuDescriptorKrillTests|DeepSeekDashboardUsageFetcherTests|DeepSeekUsageFetcherTests|OpenRouterUsageStatsTests|KimiK2UsageFetcherTests|KrillCostUsageFetcherTests|CLIEntryTests|CLIProviderSelectionTests|CLIArgumentParsingTests|ConfigurationDocsProviderIDTests|ProviderChangelogLinkTests'`: passed, 152 Swift tests.
- Post-live-test validation:
  - `swift test --disable-sandbox --filter MenuCardCostHintTests`: passed, 5 Swift tests.
  - `make check`: passed.
  - `./Scripts/package_app.sh`: passed, created `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app`.
  - Relaunched packaged worktree app; current process path is `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app/Contents/MacOS/TokenBar`.
- Persistent Refresh spinner validation:
  - `swift test --disable-sandbox --filter StatusMenuPersistentRefreshTests`: passed, 20 Swift tests.
  - `make check`: passed.
  - `./Scripts/package_app.sh`: passed, created `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app`.
  - Relaunched packaged worktree app; current process path is `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app/Contents/MacOS/TokenBar`.
- Merged-menu positioning validation:
  - `swift test --disable-sandbox --filter 'MergedMenuPositioningTests|StatusMenuSwitcherRefreshTests'`: passed, 16 Swift tests.
  - `make check`: passed.
  - `./Scripts/package_app.sh`: passed, created `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app`.
  - Relaunched packaged worktree app; current process path is `/Users/areslee/.codex/worktrees/987e/TokenBar/TokenBar.app/Contents/MacOS/TokenBar`.

## Not Run

- No live provider probes, browser-cookie imports, or real `tokenbar usage` calls were run, to avoid macOS Keychain prompts and live account access.
- Full unfiltered `swift test` was not run; the focused provider config tests were used after the final targeted refactor.
- Follow-up fixes also did not run live DeepSeek dashboard login, because that opens a WebView and may touch real account state. The regression test verifies the UI capability/menu path without triggering the login flow.
- The second review did not package/relaunch the app bundle, but the post-live-test menu-card fix did package and
  relaunch the worktree app for manual menu verification.

## Remaining Risk

- This is a large upstream sync, so UI/runtime behavior should still be smoke-tested from a freshly packaged app before release.
- The top historical `appcast.xml` item already contains an upstream CodexBar 0.29.1 entry from the branch baseline; this merge did not add a new release entry or regenerate appcast.
- Full unfiltered `swift test` remains not run on this branch; current evidence is focused integration tests plus `make check`.
