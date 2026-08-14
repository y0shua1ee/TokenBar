#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE_SCRIPT="$ROOT/Scripts/package_app.sh"
RELEASE_SCRIPT="$ROOT/Scripts/sign-and-notarize.sh"
ADHOC_SCRIPT="$ROOT/Scripts/release-adhoc.sh"
CLI_PACKAGE_SCRIPT="$ROOT/Scripts/package_cli.sh"
WIDGET_PLIST="$ROOT/WidgetExtension/Info.plist"
WIDGET_PROJECT="$ROOT/WidgetExtension/CodexBarWidgetExtension.xcodeproj/project.pbxproj"
RELEASE_WORKFLOW="$ROOT/.github/workflows/release-cli.yml"
CLOUDKIT_SCRIPT="$ROOT/Scripts/cloudkit/deploy_schema.sh"
COMPILE_SCRIPT="$ROOT/Scripts/compile_and_run.sh"
LIVE_UPDATE_SCRIPT="$ROOT/Scripts/test_live_update.sh"
CLAUDE_OWNERSHIP_SCRIPT="$ROOT/Scripts/verify_1844_live.sh"
RELEASE_ENV="$ROOT/.mac-release.env"

grep -Fq 'APP_FINAL="$ROOT/TokenBar.app"' "$PACKAGE_SCRIPT"
grep -Fq 'install_binary "CodexBar" "$APP/Contents/MacOS/TokenBar"' "$PACKAGE_SCRIPT"
grep -Fq 'install_binary "CodexBarCLI" "$APP/Contents/Helpers/TokenBarCLI"' "$PACKAGE_SCRIPT"
grep -Fq 'ln -s "TokenBarCLI" "$APP/Contents/Helpers/tokenbar"' "$PACKAGE_SCRIPT"
grep -Fq 'CORE_RESOURCE_BUNDLE="${PREFERRED_BUILD_DIR}/CodexBar_CodexBarCore.bundle"' "$PACKAGE_SCRIPT"
grep -Fq 'BUNDLE_ID="com.y0shua1ee.tokenbar"' "$PACKAGE_SCRIPT"
grep -Fq 'APP_GROUP_ID="group.com.y0shua1ee.tokenbar"' "$PACKAGE_SCRIPT"
grep -Fq 'CODESIGN_ID="$APP_IDENTITY"' "$PACKAGE_SCRIPT"
grep -Fq 'TokenBarTeamID' "$PACKAGE_SCRIPT"

if rg -q 'Peter Steinberger|Y5PE65HELJ|com\.steipete\.codexbar' \
  "$PACKAGE_SCRIPT" "$RELEASE_SCRIPT" "$ADHOC_SCRIPT"; then
  echo "TokenBar release path unexpectedly inherits upstream identity metadata" >&2
  exit 1
fi

grep -Fq 'APP_IDENTITY="${APP_IDENTITY:-}"' "$RELEASE_SCRIPT"
grep -Fq 'APP_TEAM_ID is required for Developer ID release signing' "$RELEASE_SCRIPT"
grep -Fq 'env -u APP_IDENTITY -u APP_TEAM_ID -u TOKENBAR_PROVISIONING_PROFILE' "$ADHOC_SCRIPT"
grep -Fq 'TOKENBAR_SIGNING=adhoc ARCHES="$ARCHES_VALUE"' "$ADHOC_SCRIPT"
grep -Fq 'TOKENBAR_WIDGET_EXTENSION_BUILDER="${TOKENBAR_WIDGET_EXTENSION_BUILDER:-swiftpm}"' "$ADHOC_SCRIPT"
grep -Fq 'build_widget_extension_from_swiftpm' "$PACKAGE_SCRIPT"
grep -Fq 'install_binary "CodexBarWidget" "$appex/Contents/MacOS/CodexBarWidget"' "$PACKAGE_SCRIPT"
grep -Fq -- '--publish' "$ADHOC_SCRIPT"
grep -Fq 'require_release_origin' "$ADHOC_SCRIPT"
grep -Fq 'origin targets $origin_repo, but release repository is $REPO' "$ADHOC_SCRIPT"
grep -Fq 'git push origin "$TAG"' "$ADHOC_SCRIPT"
grep -Fq 'gh release create "$TAG"' "$ADHOC_SCRIPT"
grep -Fq 'require_clean_worktree' "$ADHOC_SCRIPT"
grep -Fq 'validate_changelog' "$ADHOC_SCRIPT"
grep -Fq 'CodexBarCLI' "$CLI_PACKAGE_SCRIPT"
grep -Fq 'TokenBarCLI' "$CLI_PACKAGE_SCRIPT"
grep -Fq 'ln -s TokenBarCLI "$OUT_DIR/tokenbar"' "$CLI_PACKAGE_SCRIPT"
grep -Fq 'CodexBar_CodexBarCore.bundle' "$CLI_PACKAGE_SCRIPT"
grep -Fq 'TokenBar' "$WIDGET_PLIST"
grep -Fq 'TokenBarTeamID' "$WIDGET_PLIST"
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER = "$(TOKENBAR_WIDGET_BUNDLE_ID)";' "$WIDGET_PROJECT"
grep -Fq 'INFOPLIST_KEY_TokenBarTeamID = "$(TOKENBAR_TEAM_ID)";' "$WIDGET_PROJECT"
grep -Fq "if: github.event_name == 'release'" "$RELEASE_WORKFLOW"
grep -Fq -- '--repo y0shua1ee/homebrew-tokenbar' "$RELEASE_WORKFLOW"
grep -Fq -- '-f repository=y0shua1ee/TokenBar' "$RELEASE_WORKFLOW"
grep -Fq -- '-f cask=tokenbar' "$RELEASE_WORKFLOW"
grep -Fq -- "-f cask_artifact='TokenBar-macos-universal-{version}.zip'" "$RELEASE_WORKFLOW"
grep -Fq 'TAP_FORMULA: ""' "$RELEASE_WORKFLOW"
if rg -q -- '-f formula=tokenbar|-f artifact_template=|-f target_aliases=' "$RELEASE_WORKFLOW"; then
  echo "TokenBar release workflow still requests unsupported tap Formula updates" >&2
  exit 1
fi
grep -Fq 'TokenBar CloudKit deployment is disabled until TokenBar owns an Apple team and container' "$CLOUDKIT_SCRIPT"
grep -Fq 'EXPECTED_CONTAINER_ID="iCloud.com.y0shua1ee.tokenbar"' "$CLOUDKIT_SCRIPT"
grep -Fq '[[ "$CONTAINER_ID" != "$EXPECTED_CONTAINER_ID" ]]' "$CLOUDKIT_SCRIPT"
grep -Fq 'Path.home() / ".tokenbar" / "mimo-local-usage.json"' "$ROOT/Scripts/mimo-usage.py"
if rg -q '\.codexbar/mimo-local-usage|Path\.home\(\) / "\.codexbar"' "$ROOT/Scripts/mimo-usage.py"; then
  echo "MiMo usage helper still writes to the upstream config directory" >&2
  exit 1
fi
grep -Fq 'TokenBar.app' "$COMPILE_SCRIPT"
grep -Fq 'com.y0shua1ee.TokenBar' "$COMPILE_SCRIPT"
grep -Fq 'Only an explicitly supplied APP_IDENTITY is allowed to sign TokenBar.' "$COMPILE_SCRIPT"
if rg -q 'detect_codesigning_identity|Developer ID Application:|Apple Development:|Apple Distribution:' \
  "$COMPILE_SCRIPT"; then
  echo "TokenBar development launcher still auto-selects a signing identity" >&2
  exit 1
fi
grep -Fq 'TOKENBAR_ALLOW_DESTRUCTIVE_LIVE_UPDATE=1' "$LIVE_UPDATE_SCRIPT"
grep -Fq 'APP_BUNDLE="$ROOT/TokenBar.app"' "$CLAUDE_OWNERSHIP_SCRIPT"
grep -Fq 'CLI="$APP_BUNDLE/Contents/Helpers/TokenBarCLI"' "$CLAUDE_OWNERSHIP_SCRIPT"
grep -Fq 'APP="$APP_BUNDLE/Contents/MacOS/TokenBar"' "$CLAUDE_OWNERSHIP_SCRIPT"
if rg -q 'CodexBar\.app|Contents/Helpers/CodexBarCLI|Contents/MacOS/CodexBar' "$CLAUDE_OWNERSHIP_SCRIPT"; then
  echo "Claude ownership verification still targets the upstream app bundle" >&2
  exit 1
fi
grep -Fq 'MAC_RELEASE_SUPUBLIC_ED_KEY=AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=' "$RELEASE_ENV"
grep -Fq 'MAC_RELEASE_SIGNING_KEY_FILE=' "$RELEASE_ENV"
if rg -q 'sparkle-private-key-KEEP-SECURE' "$RELEASE_ENV"; then
  echo "TokenBar release config references the mismatched Sparkle key" >&2
  exit 1
fi

if rg -q 'steipete/(homebrew-tap|CodexBar)' \
  "$RELEASE_WORKFLOW" "$LIVE_UPDATE_SCRIPT" "$ROOT/Scripts/wait_for_homebrew_tap_update.sh"; then
  echo "TokenBar publication path still targets an upstream repository" >&2
  exit 1
fi
if rg -q 'y0shua1ee/homebrew-tap' \
  "$RELEASE_WORKFLOW" "$ROOT/Scripts/wait_for_homebrew_tap_update.sh"; then
  echo "TokenBar publication path targets the wrong fork tap repository" >&2
  exit 1
fi

if rg -q 'com\.apple\.developer\.icloud' "$PACKAGE_SCRIPT"; then
  echo "TokenBar package path unexpectedly enables iCloud" >&2
  exit 1
fi
grep -Fq 'TOKENBAR_PROVISIONING_PROFILE must name a TokenBar Developer ID profile' "$PACKAGE_SCRIPT"
grep -Fq 'TOKENBAR_PROVISIONING_PROFILE must name a TokenBar Developer ID profile' "$RELEASE_SCRIPT"
grep -Fq 'verify_tokenbar_provisioning_profile' "$PACKAGE_SCRIPT"
grep -Fq 'Contents/embedded.provisionprofile' "$PACKAGE_SCRIPT"
if rg -q 'Scripts/profiles/CodexBar-|CodexBar-DeveloperID\.provisionprofile' \
  "$PACKAGE_SCRIPT" "$RELEASE_SCRIPT" "$ADHOC_SCRIPT"; then
  echo "TokenBar release path still selects the upstream CodexBar provisioning profile" >&2
  exit 1
fi
grep -Fq 'if [[ -n "$APP_GROUP_ID" ]]' "$PACKAGE_SCRIPT"

echo "TokenBar identity tests passed."
