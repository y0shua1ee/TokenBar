#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TokenBar"
INTERNAL_APP_NAME="CodexBar"
APP_IDENTITY="${APP_IDENTITY:-}"
APP_BUNDLE="TokenBar.app"
APP_BUNDLE_ID="com.y0shua1ee.tokenbar"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/version.env"
source "$ROOT/Scripts/release_artifacts.sh"
source "$ROOT/Scripts/package_product_paths.sh"
source "$ROOT/Scripts/release_dsym_paths.sh"

verify_distribution_policy() {
  local app=$1
  if command -v syspolicy_check >/dev/null 2>&1; then
    syspolicy_check distribution "$app"
  else
    spctl -a -t exec -vv "$app"
  fi
}

verify_identity_bundle() {
  local app=$1 profile=$2 team_id=$3 bundle_id=$4 app_group_id=$5
  local metadata identifier signature_team entitlements entitlement_team entitlement_application_id

  codesign --verify --deep --strict --verbose=2 "$app" || return 1
  [[ -f "$app/Contents/embedded.provisionprofile" ]] || {
    echo "Packaged TokenBar is missing embedded.provisionprofile." >&2
    return 1
  }
  cmp -s "$profile" "$app/Contents/embedded.provisionprofile" || {
    echo "Packaged TokenBar does not contain the requested provisioning profile." >&2
    return 1
  }
  metadata=$(codesign -dv --verbose=4 "$app" 2>&1) || return 1
  identifier=$(awk -F= '$1 == "Identifier" { print $2; exit }' <<<"$metadata")
  signature_team=$(awk -F= '$1 == "TeamIdentifier" { print $2; exit }' <<<"$metadata")
  [[ "$identifier" == "$bundle_id" && "$signature_team" == "$team_id" ]] || {
    echo "TokenBar signature does not match APP_TEAM_ID and bundle ID." >&2
    return 1
  }
  entitlements=$(mktemp "${TMPDIR:-/tmp}/tokenbar-release-entitlements.XXXXXX.plist")
  if ! codesign -d --entitlements :- "$app" >"$entitlements" 2>/dev/null; then
    rm -f "$entitlements"
    return 1
  fi
  entitlement_team=$(plutil -extract com.apple.developer.team-identifier raw -o - "$entitlements" 2>/dev/null || true)
  entitlement_application_id=$(plutil -extract com.apple.application-identifier raw -o - "$entitlements" 2>/dev/null || true)
  if [[ "$entitlement_team" != "$team_id" || "$entitlement_application_id" != "$team_id.$bundle_id" ]] || \
    ! plutil -extract com.apple.security.application-groups xml1 -o - "$entitlements" 2>/dev/null \
      | grep -Fq "<string>${app_group_id}</string>"; then
    rm -f "$entitlements"
    echo "TokenBar signed entitlements do not match its team, bundle ID, and app group." >&2
    return 1
  fi
  rm -f "$entitlements"
}

# Allow building a universal binary if ARCHES is provided; default to universal (arm64 + x86_64).
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
ZIP_NAME=$(tokenbar_app_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")
DSYM_ZIP=$(tokenbar_dsym_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "Missing APP_STORE_CONNECT_* env vars (API key, key id, issuer id)." >&2
  exit 1
fi
if [[ -z "$APP_IDENTITY" ]]; then
  echo "APP_IDENTITY is required for Developer ID release signing." >&2
  exit 1
fi
if [[ -z "${APP_TEAM_ID:-}" && "$APP_IDENTITY" =~ \(([A-Z0-9]{10})\)$ ]]; then
  APP_TEAM_ID="${BASH_REMATCH[1]}"
  export APP_TEAM_ID
fi
if [[ -z "${APP_TEAM_ID:-}" ]]; then
  echo "APP_TEAM_ID is required for Developer ID release signing." >&2
  exit 1
fi
TOKENBAR_PROVISIONING_PROFILE="${TOKENBAR_PROVISIONING_PROFILE:-}"
if [[ -z "$TOKENBAR_PROVISIONING_PROFILE" || ! -f "$TOKENBAR_PROVISIONING_PROFILE" ]]; then
  echo "TOKENBAR_PROVISIONING_PROFILE must name a TokenBar Developer ID profile." >&2
  exit 1
fi

NOTARIZATION_TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/tokenbar-notarize.XXXXXX")
chmod 700 "$NOTARIZATION_TEMP_DIR"
API_KEY_PATH="$NOTARIZATION_TEMP_DIR/tokenbar-api-key.p8"
NOTARIZATION_ZIP="$NOTARIZATION_TEMP_DIR/${APP_NAME}Notarize.zip"
trap 'rm -rf "$NOTARIZATION_TEMP_DIR"' EXIT

(
  umask 077
  printf '%s' "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > "$API_KEY_PATH"
)
chmod 600 "$API_KEY_PATH"

ARCH_LIST=( ${ARCHES_VALUE} )
APP_IDENTITY="$APP_IDENTITY" APP_TEAM_ID="$APP_TEAM_ID" \
  TOKENBAR_PROVISIONING_PROFILE="$TOKENBAR_PROVISIONING_PROFILE" TOKENBAR_SIGNING=identity \
  ARCHES="${ARCHES_VALUE}" ./Scripts/package_app.sh release

ENTITLEMENTS_DIR="$ROOT/.build/entitlements"
APP_ENTITLEMENTS="${ENTITLEMENTS_DIR}/TokenBar.entitlements"
WIDGET_ENTITLEMENTS="${ENTITLEMENTS_DIR}/TokenBarWidget.entitlements"

echo "Signing with $APP_IDENTITY"
if [[ -f "$APP_BUNDLE/Contents/Helpers/TokenBarCLI" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    "$APP_BUNDLE/Contents/Helpers/TokenBarCLI"
fi
if [[ -f "$APP_BUNDLE/Contents/Helpers/CodexBarClaudeWatchdog" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    "$APP_BUNDLE/Contents/Helpers/CodexBarClaudeWatchdog"
fi
if [[ -d "$APP_BUNDLE/Contents/PlugIns/CodexBarWidget.appex" ]]; then
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP_BUNDLE/Contents/PlugIns/CodexBarWidget.appex/Contents/MacOS/CodexBarWidget"
  codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP_BUNDLE/Contents/PlugIns/CodexBarWidget.appex"
fi
codesign --force --timestamp --options runtime --sign "$APP_IDENTITY" \
  --entitlements "$APP_ENTITLEMENTS" \
  "$APP_BUNDLE"
verify_identity_bundle \
  "$APP_BUNDLE" "$TOKENBAR_PROVISIONING_PROFILE" "$APP_TEAM_ID" "$APP_BUNDLE_ID" \
  "${APP_TEAM_ID}.com.y0shua1ee.tokenbar"

DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$NOTARIZATION_ZIP"

echo "Submitting for notarization"
xcrun notarytool submit "$NOTARIZATION_ZIP" \
  --key "$API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

# Strip any extended attributes that would create AppleDouble files when zipping
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete

"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

verify_distribution_policy "$APP_BUNDLE"
stapler validate "$APP_BUNDLE"

echo "Packaging dSYM"
DSYM_STAGE_ROOT="$ROOT/.build/package-products/release"
DSYM_PATHS=()
for ARCH in "${ARCH_LIST[@]}"; do
  STAGED_DSYM="$DSYM_STAGE_ROOT/$ARCH/${INTERNAL_APP_NAME}.dSYM"
  if [[ -d "$STAGED_DSYM" ]]; then
    DSYM_PATHS+=("$STAGED_DSYM")
    continue
  fi
  BIN_DIR=$(codexbar_swiftpm_bin_path release "$ARCH")
  DSYM_PATHS+=("$(codexbar_resolve_dsym_path "$DSYM_STAGE_ROOT" "$BIN_DIR" "$INTERNAL_APP_NAME" "$ARCH")")
done

DSYM_PATH="${DSYM_PATHS[0]}"
DSYM_DWARF_PATHS=()
for ((index = 0; index < ${#ARCH_LIST[@]}; index++)); do
  ARCH="${ARCH_LIST[$index]}"
  if ! ARCH_DSYM=$(codexbar_require_dsym_dwarf_for_arch "${DSYM_PATHS[$index]}" "$INTERNAL_APP_NAME" "$ARCH"); then
    exit 1
  fi
  DSYM_DWARF_PATHS+=("$ARCH_DSYM")
done

if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
  MERGED_DSYM_ROOT="${DSYM_STAGE_ROOT}/${APP_NAME}.dSYM-universal"
  MERGED_DSYM="${MERGED_DSYM_ROOT}/${APP_NAME}.dSYM"
  rm -rf "$MERGED_DSYM_ROOT"
  mkdir -p "$MERGED_DSYM_ROOT"
  cp -R "$DSYM_PATH" "$MERGED_DSYM"
  DWARF_PATH="${MERGED_DSYM}/Contents/Resources/DWARF/${INTERNAL_APP_NAME}"
  lipo -create "${DSYM_DWARF_PATHS[@]}" -output "$DWARF_PATH"
  DSYM_PATH="$MERGED_DSYM"
fi
if [[ ! -d "$DSYM_PATH" ]]; then
  echo "Missing dSYM at SwiftPM-reported path: $DSYM_PATH" >&2
  exit 1
fi
codexbar_verify_dsym_matches_binary \
  "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
  "$DSYM_PATH/Contents/Resources/DWARF/$INTERNAL_APP_NAME" \
  "${ARCH_LIST[@]}"
"$DITTO_BIN" --norsrc -c -k --keepParent "$DSYM_PATH" "$DSYM_ZIP"

echo "Done: $ZIP_NAME"
