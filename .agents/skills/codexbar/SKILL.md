---
name: codexbar
description: "TokenBar read-only bridge. Provider usage, limits, credits, config health. JSON. No writes."
---

# TokenBar Read-Only Bridge

Read TokenBar. Never mutate config/auth. The skill folder and `CODEXBAR_*` environment variables retain their
upstream-compatible names.

## Run

```bash
skill="${CODEX_HOME:-$HOME/.codex}/skills/codexbar"
"$skill/scripts/codexbar" doctor
"$skill/scripts/codexbar" providers
"$skill/scripts/codexbar" usage
"$skill/scripts/codexbar" usage --provider codex
"$skill/scripts/codexbar" usage --all
```

All stdout: JSON. The inherited upstream JSON shape is kept for compatibility.

## Rules

- Start `doctor` when install/config unknown.
- `usage` reads enabled providers. Prefer this.
- `usage --provider ID` reads one provider.
- `usage --all` expensive; use only when needed.
- Identities hidden by default. `--include-identities` only when user explicitly needs them.
- Secrets always hidden.
- Helper read-only: fixed allowlist only. No config writes, auth repair, enable/disable, key storage.
- Timeout means upstream stuck. Narrow provider or raise `CODEXBAR_TIMEOUT` (default 120 seconds).

## Binary

Auto-find: `CODEXBAR_BIN`, `tokenbar`/legacy `codexbar` on PATH, TokenBar app bundle, Homebrew cask, then legacy
CodexBar locations. If missing: open TokenBar, Preferences > Advanced > Install CLI; or set `CODEXBAR_BIN`.

Each stdout/stderr stream capped at 1 MiB while fully drained. Timeout kills process group.
