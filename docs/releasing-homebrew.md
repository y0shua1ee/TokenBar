---
summary: "Homebrew Cask release steps for TokenBar (Sparkle-disabled builds)."
read_when:
  - Publishing a TokenBar release via Homebrew
  - Updating the Homebrew tap cask definition
---

# TokenBar Homebrew Release Playbook

Homebrew is for the UI app via Cask. When installed via Homebrew, TokenBar disables Sparkle and shows a "update via brew" hint in About.

## Prereqs
- Homebrew installed.
- Access to the tap repo: `../homebrew-tokenbar`.

## 1) Release TokenBar normally
Follow `docs/RELEASING.md` to publish `TokenBar-macos-universal-<version>.zip` to GitHub Releases.

## 2) Let the Release CLI workflow update the tap
After the GitHub release is published, `.github/workflows/release-cli.yml` builds the standalone CLI assets and dispatches `y0shua1ee/homebrew-tokenbar`'s `update-formula.yml`. That tap workflow updates:
- `Casks/tokenbar.rb` for the app zip.

The tap currently has no `Formula/tokenbar.rb`; standalone CLI tarballs remain available directly from the GitHub
Release. The tap workflow's formula inputs are reserved for future formula support and are not sent by TokenBar's
release workflow.

If dispatch fails or is rate-limited, update the cask manually.

## 2a) Manual cask update
In `../homebrew-tokenbar`, update the cask at `Casks/tokenbar.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/TokenBar-macos-universal-<version>.zip`
- Update `sha256` to match that zip.
- Keep `depends_on macos: ">= :sonoma"` (TokenBar is macOS 14+). Do not add an architecture restriction; the app zip is universal.

## 3) Verify install
```sh
brew uninstall --cask tokenbar || true
brew untap y0shua1ee/tokenbar || true
brew tap y0shua1ee/tokenbar
brew install --cask y0shua1ee/tokenbar/tokenbar
open -a TokenBar
```

## 4) Push tap changes
Commit + push in the tap repo.
