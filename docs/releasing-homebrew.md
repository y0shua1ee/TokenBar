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
- Access to the tap repo: `../homebrew-tap`.

## 1) Release TokenBar normally
Follow `docs/RELEASING.md` to publish `TokenBar-<version>.zip` to GitHub Releases.

## 2) Update the Homebrew tap cask
In `../homebrew-tap`, add/update the cask at `Casks/tokenbar.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/TokenBar-<version>.zip`
- Update `sha256` to match that zip.
- Keep `depends_on arch: :arm64` and `depends_on macos: ">= :sonoma"` (TokenBar is macOS 14+).

## 2b) Update the Homebrew tap formula (CLI)
In `../homebrew-tap`, add/update the formula at `Formula/tokenbar.rb`:
- `url` points at the GitHub release assets:
  - macOS: `.../releases/download/v<version>/TokenBarCLI-v<version>-macos-arm64.tar.gz`
  - macOS: `.../releases/download/v<version>/TokenBarCLI-v<version>-macos-x86_64.tar.gz`
  - Linux: `.../releases/download/v<version>/TokenBarCLI-v<version>-linux-aarch64.tar.gz`
  - Linux: `.../releases/download/v<version>/TokenBarCLI-v<version>-linux-x86_64.tar.gz`
- Update all `sha256` values to match those tarballs.

## 3) Verify install
```sh
brew uninstall --cask tokenbar || true
brew untap <tokenbar-tap> || true
# tap command depends on TokenBar tap setup
brew install --cask tokenbar
open -a TokenBar
```

## 4) Push tap changes
Commit + push in the tap repo.
