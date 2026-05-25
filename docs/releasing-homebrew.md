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
- Access to the tap repo: [`y0shua1ee/homebrew-tokenbar`](https://github.com/y0shua1ee/homebrew-tokenbar) (`~/Documents/dev/taps/homebrew-tokenbar`).

## 1) Release TokenBar normally
Follow `docs/RELEASING.md` to publish `TokenBar-<version>-adhoc.zip` to GitHub Releases.

## 2) Update the Homebrew tap cask
In `~/Documents/dev/taps/homebrew-tokenbar`, update the cask at `Casks/tokenbar.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/TokenBar-<version>-adhoc.zip`
- Update `version` and `sha256` to match that zip.
- Keep `depends_on arch: :arm64` and `depends_on macos: ">= :sonoma"` while TokenBar app zips remain arm64-only/macOS 14+.
- Keep the `postflight` quarantine cleanup while fork releases are adhoc-signed so the bundled `tokenbar` CLI can run after install.

## 2b) CLI distribution
The cask links the bundled CLI helper from `TokenBar.app` as `tokenbar`, so users do not need a separate formula for normal macOS installs.

A standalone formula can be added later once release assets include macOS CLI tarballs alongside Linux tarballs:
- `url` points at the GitHub release assets:
  - macOS: `.../releases/download/v<version>/TokenBarCLI-v<version>-macos-arm64.tar.gz`
  - macOS: `.../releases/download/v<version>/TokenBarCLI-v<version>-macos-x86_64.tar.gz`
  - Linux: `.../releases/download/v<version>/TokenBarCLI-v<version>-linux-aarch64.tar.gz`
  - Linux: `.../releases/download/v<version>/TokenBarCLI-v<version>-linux-x86_64.tar.gz`
- Update all `sha256` values to match those tarballs.

## 3) Verify install
```sh
brew uninstall --cask tokenbar || true
brew untap y0shua1ee/tokenbar || true
brew tap y0shua1ee/tokenbar
brew install --cask tokenbar
/opt/homebrew/bin/tokenbar --version
open -a TokenBar
```

## 4) Push tap changes
Commit + push in the tap repo.
