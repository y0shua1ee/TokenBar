# Upstream CodexBar Merge Handoff

## Current Goal

Merge latest upstream `steipete/CodexBar` into TokenBar on branch `codex/merge-upstream-codexbar-20260615`, preserving TokenBar fork identity, providers, release paths, and local menu behavior.

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

## Validation

- `swift build --disable-sandbox` in the temporary resolved tree: passed.
- `make check`: passed.
- `swift build --disable-sandbox`: passed after final identity/lint fixes.
- `swift test --disable-sandbox --filter ProviderConfigEnvironmentTests`: passed, 33 tests.

## Not Run

- No live provider probes, browser-cookie imports, real `tokenbar usage` calls, or app-bundle relaunch validation were run, to avoid macOS Keychain prompts and live account access.
- Full unfiltered `swift test` was not run; the focused provider config tests were used after the final targeted refactor.

## Remaining Risk

- This is a large upstream sync, so UI/runtime behavior should still be smoke-tested from a freshly packaged app before release.
- The top historical `appcast.xml` item already contains an upstream CodexBar 0.29.1 entry from the branch baseline; this merge did not add a new release entry or regenerate appcast.
