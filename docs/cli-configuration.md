---
summary: "TokenBar CLI configuration commands for provider toggles, API keys, and isolated config files."
read_when:
  - Using tokenbar config from scripts or CI
  - Enabling or disabling providers without opening Settings
  - Storing provider API keys from the command line
---

# CLI configuration

`tokenbar config` edits the same resolved config file used by the app's Settings → Providers pane.
New installs use `~/.config/tokenbar/config.json`; absolute `XDG_CONFIG_HOME` paths and `CODEXBAR_CONFIG` are
supported, and existing `~/.tokenbar/config.json` installs keep using the legacy file when no XDG config exists.
The CLI writes the file with `0600` permissions.

## Providers

List persistent provider toggles:

```bash
tokenbar config providers
tokenbar config providers --json --pretty
```

Enable or disable a provider:

```bash
tokenbar config enable --provider grok
tokenbar config disable --provider cursor
```

These are persistent app/CLI settings. They are different from `tokenbar usage --provider grok`, which is a one-shot
command override and does not edit config.

If every provider is disabled, `tokenbar usage` with no `--provider` prints no text output, and
`tokenbar usage --json` prints `[]`. Passing `--provider <name>` still fetches that provider for the one command.

## API keys

API keys are stored under the provider entry in config:

```bash
printf '%s' "$ELEVENLABS_API_KEY" | tokenbar config set-api-key --provider elevenlabs --stdin
```

`set-api-key` enables the provider by default. Add `--no-enable` when you only want to save the key:

```bash
printf '%s' "$OPENROUTER_API_KEY" | tokenbar config set-api-key --provider openrouter --stdin --no-enable
```

Useful examples:

```bash
printf '%s' "$OPENAI_ADMIN_KEY" | tokenbar config set-api-key --provider openai --stdin
printf '%s' "$ANTHROPIC_ADMIN_KEY" | tokenbar config set-api-key --provider claude --stdin
printf '%s' "$DEEPGRAM_API_KEY" | tokenbar config set-api-key --provider deepgram --stdin
printf '%s' "$GROQ_API_KEY" | tokenbar config set-api-key --provider groq --stdin
printf '%s' "$LLM_PROXY_API_KEY" | tokenbar config set-api-key --provider llmproxy --stdin
printf '%s' "$Z_AI_API_KEY" | tokenbar config set-api-key --provider zai --stdin
printf '%s' "$XAI_MANAGEMENT_API_KEY" | tokenbar config set-api-key --provider xai --stdin
```

For a z.ai team account:

```bash
printf '%s' "$Z_AI_API_KEY" | tokenbar config set-api-key --provider zai --stdin \
  --label Team \
  --usage-scope team \
  --organization-id org_... \
  --workspace-id proj_...
```

Use single-line BigModel organization/project IDs; see [z.ai](zai.md).

Only providers that consume config-backed API keys accept this command. Admin API providers may require a key with
organization/usage permissions, not a normal inference key. The `xai` provider reads xAI developer-platform billing
with a Management key plus a team ID (set `workspaceID` in the provider entry, `XAI_TEAM_ID`, or the app settings
pane); inference API keys are not accepted. The separate Grok provider tracks consumer Grok/SuperGrok subscriptions
through its own browser/CLI session and takes no API key, so enable it with
`tokenbar config enable --provider grok`.

LLM Proxy also needs a base URL. Use `LLM_PROXY_BASE_URL` for CLI runs, or add `"enterpriseHost"` to the provider entry
in the TokenBar config file.

## Isolated config files

For tests, demos, and CI, point TokenBar at a temporary config file:

```bash
export CODEXBAR_CONFIG=/tmp/tokenbar-config.json
tokenbar config enable --provider grok
tokenbar config providers --json --pretty
```

The override applies to both reads and writes for the current process environment.

## Cost history window

The app setting controls the menu's local cost-history window. For one-off CLI reports, pass `--days`:

```bash
tokenbar cost --provider codex --days 90
tokenbar cost --provider claude --days 180 --format json --pretty
tokenbar cost --provider openrouter --days 30 --format json --pretty
```

The accepted range is 1...365 days. OpenRouter Activity is limited by the provider API to 1...30 completed UTC days
and requires `OPENROUTER_MANAGEMENT_KEY` or the Management key field in app settings.

## Validation

After hand-editing config:

```bash
tokenbar config validate
tokenbar config dump --pretty
```

`dump` prints normalized config, including providers omitted from a hand-written file.
