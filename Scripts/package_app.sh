#!/usr/bin/env bash
set -euo pipefail

resolve_package_signing_mode() {
  local requested="${TOKENBAR_SIGNING:-${CODEXBAR_SIGNING:-adhoc}}"
  case "$requested" in
    adhoc|identity) ;;
    *)
      echo "ERROR: Unsupported TOKENBAR_SIGNING: $requested (expected adhoc or identity)" >&2
      return 1
      ;;
  esac
  SIGNING_MODE="$requested"
}

verify_no_quarantine_attribute() {
  local bundle="$1"
  local quarantined
  quarantined="$(xattr -r -p com.apple.quarantine "$bundle" 2>/dev/null || true)"
  if [[ -n "$quarantined" ]]; then
    echo "ERROR: Packaged app still has com.apple.quarantine: ${bundle}" >&2
    return 1
  fi
}

verify_packaged_app_integrity() {
  local bundle="$1"
  local sparkle="$bundle/Contents/Frameworks/Sparkle.framework"

  verify_no_quarantine_attribute "$bundle" || return 1
  codesign --verify --deep --strict --verbose=2 "$sparkle" || return 1
  codesign --verify --deep --strict --verbose=2 "$bundle" || return 1
}

verify_tokenbar_provisioning_profile() {
  local profile=$1 team_id=$2 bundle_id=$3 app_group_id=$4
  local profile_plist profile_team profile_entitlement_team profile_application_id provisions_all_devices
  local profile_app_groups

  profile_plist=$(mktemp "${TMPDIR:-/tmp}/tokenbar-profile.XXXXXX.plist")
  if ! security cms -D -i "$profile" >"$profile_plist" 2>/dev/null; then
    rm -f "$profile_plist"
    echo "ERROR: Could not decode TokenBar provisioning profile: $profile" >&2
    return 1
  fi

  profile_team=$(/usr/libexec/PlistBuddy -c 'Print :TeamIdentifier:0' "$profile_plist" 2>/dev/null || true)
  profile_entitlement_team=$(
    /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.developer.team-identifier' \
      "$profile_plist" 2>/dev/null || true)
  profile_application_id=$(
    /usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' \
      "$profile_plist" 2>/dev/null || true)
  provisions_all_devices=$(
    /usr/libexec/PlistBuddy -c 'Print :ProvisionsAllDevices' "$profile_plist" 2>/dev/null || true)
  if [[ "$provisions_all_devices" != "true" ]]; then
    rm -f "$profile_plist"
    echo "ERROR: TOKENBAR_PROVISIONING_PROFILE is not a Developer ID distribution profile." >&2
    return 1
  fi
  if [[ "$profile_team" != "$team_id" || "$profile_entitlement_team" != "$team_id" || \
    "$profile_application_id" != "$team_id.$bundle_id" ]]; then
    rm -f "$profile_plist"
    echo "ERROR: Provisioning profile does not match APP_TEAM_ID and TokenBar bundle ID." >&2
    return 1
  fi
  profile_app_groups=$(
    /usr/libexec/PlistBuddy -c 'Print :Entitlements:com.apple.security.application-groups' \
      "$profile_plist" 2>/dev/null || true)
  if ! sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$profile_app_groups" \
    | grep -Fxq "$app_group_id"; then
    rm -f "$profile_plist"
    echo "ERROR: Provisioning profile does not authorize TokenBar app group: $app_group_id" >&2
    return 1
  fi
  rm -f "$profile_plist"
}

verify_identity_signed_app() {
  local bundle=$1 team_id=$2 bundle_id=$3 app_group_id=$4
  local embedded_profile="$bundle/Contents/embedded.provisionprofile"
  local signed_metadata signed_identifier signed_team signed_entitlements signed_app_groups

  if [[ ! -f "$embedded_profile" ]]; then
    echo "ERROR: Identity-signed TokenBar bundle is missing embedded.provisionprofile." >&2
    return 1
  fi
  verify_tokenbar_provisioning_profile "$embedded_profile" "$team_id" "$bundle_id" "$app_group_id" || return 1

  if ! signed_metadata=$(codesign -dv --verbose=4 "$bundle" 2>&1); then
    echo "ERROR: Could not inspect the TokenBar code signature." >&2
    return 1
  fi
  signed_identifier=$(awk -F= '$1 == "Identifier" { print $2; exit }' <<<"$signed_metadata")
  signed_team=$(awk -F= '$1 == "TeamIdentifier" { print $2; exit }' <<<"$signed_metadata")
  if [[ "$signed_identifier" != "$bundle_id" || "$signed_team" != "$team_id" ]]; then
    echo "ERROR: TokenBar signature does not match APP_TEAM_ID and bundle ID." >&2
    return 1
  fi

  signed_entitlements=$(mktemp "${TMPDIR:-/tmp}/tokenbar-entitlements.XXXXXX.plist")
  if ! codesign -d --entitlements :- "$bundle" >"$signed_entitlements" 2>/dev/null; then
    rm -f "$signed_entitlements"
    echo "ERROR: Could not read TokenBar's signed entitlements." >&2
    return 1
  fi
  local entitlement_team entitlement_application_id
  entitlement_team=$(
    /usr/libexec/PlistBuddy -c 'Print :com.apple.developer.team-identifier' \
      "$signed_entitlements" 2>/dev/null || true)
  entitlement_application_id=$(
    /usr/libexec/PlistBuddy -c 'Print :com.apple.application-identifier' \
      "$signed_entitlements" 2>/dev/null || true)
  if [[ "$entitlement_team" != "$team_id" || "$entitlement_application_id" != "$team_id.$bundle_id" ]]; then
    rm -f "$signed_entitlements"
    echo "ERROR: TokenBar's signed entitlements do not match APP_TEAM_ID and bundle ID." >&2
    return 1
  fi
  signed_app_groups=$(
    /usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups' \
      "$signed_entitlements" 2>/dev/null || true)
  if ! sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"$signed_app_groups" \
    | grep -Fxq "$app_group_id"; then
    rm -f "$signed_entitlements"
    echo "ERROR: TokenBar's signed entitlements do not include app group: $app_group_id" >&2
    return 1
  fi
  rm -f "$signed_entitlements"
}

CONF=${1:-release}
ALLOW_LLDB=${TOKENBAR_ALLOW_LLDB:-${CODEXBAR_ALLOW_LLDB:-0}}
SIGNING_MODE=
resolve_package_signing_mode
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
LOWER_CONF=$(printf "%s" "$CONF" | tr '[:upper:]' '[:lower:]')
case "$LOWER_CONF" in
  debug|release) ;;
  *)
    echo "ERROR: Unsupported build configuration: $CONF (expected debug or release)" >&2
    exit 1
    ;;
esac

if [[ -z "${APP_TEAM_ID:-}" && "${APP_IDENTITY:-}" =~ \(([A-Z0-9]{10})\)$ ]]; then
  APP_TEAM_ID="${BASH_REMATCH[1]}"
  export APP_TEAM_ID
fi
if [[ "$SIGNING_MODE" == "identity" ]]; then
  if [[ -z "${APP_IDENTITY:-}" ]]; then
    echo "ERROR: APP_IDENTITY is required when TOKENBAR_SIGNING=identity." >&2
    exit 1
  fi
  if [[ -z "${APP_TEAM_ID:-}" ]]; then
    echo "ERROR: APP_TEAM_ID is required when TOKENBAR_SIGNING=identity." >&2
    exit 1
  fi
  PROVISIONING_PROFILE_SOURCE="${TOKENBAR_PROVISIONING_PROFILE:-}"
  if [[ -z "$PROVISIONING_PROFILE_SOURCE" || ! -f "$PROVISIONING_PROFILE_SOURCE" ]]; then
    echo "ERROR: TOKENBAR_PROVISIONING_PROFILE must name a TokenBar Developer ID profile." >&2
    exit 1
  fi
else
  PROVISIONING_PROFILE_SOURCE=""
fi

BUNDLE_ID="com.y0shua1ee.tokenbar"
FEED_URL="https://raw.githubusercontent.com/y0shua1ee/TokenBar/main/appcast.xml"
AUTO_CHECKS=true
if [[ "$LOWER_CONF" == "debug" ]]; then
  BUNDLE_ID="com.y0shua1ee.tokenbar.debug"
  FEED_URL=""
fi
if [[ "$SIGNING_MODE" == "adhoc" ]]; then
  FEED_URL=""
fi
if [[ "$LOWER_CONF" == "debug" || "$SIGNING_MODE" == "adhoc" ]]; then
  AUTO_CHECKS=false
fi
WIDGET_BUNDLE_ID="${BUNDLE_ID}.widget"
APP_TEAM_ID="${APP_TEAM_ID:-}"
if [[ -n "$APP_TEAM_ID" ]]; then
  APP_GROUP_ID="${APP_TEAM_ID}.com.y0shua1ee.tokenbar"
  if [[ "$BUNDLE_ID" == *".debug"* ]]; then
    APP_GROUP_ID="${APP_TEAM_ID}.com.y0shua1ee.tokenbar.debug"
  fi
elif [[ "$BUNDLE_ID" == *".debug"* ]]; then
  APP_GROUP_ID="group.com.y0shua1ee.tokenbar.debug"
else
  APP_GROUP_ID="group.com.y0shua1ee.tokenbar"
fi
if [[ "$SIGNING_MODE" == "identity" ]]; then
  verify_tokenbar_provisioning_profile \
    "$PROVISIONING_PROFILE_SOURCE" "$APP_TEAM_ID" "$BUNDLE_ID" "$APP_GROUP_ID"
fi

# Load version info
source "$ROOT/version.env"
source "$ROOT/Scripts/package_product_paths.sh"
source "$ROOT/Scripts/sparkle_signing_paths.sh"

# Clean build only when explicitly requested (slower).
if [[ "${CODEXBAR_FORCE_CLEAN:-0}" == "1" ]]; then
  if [[ -d "$ROOT/.build" ]]; then
    if command -v trash >/dev/null 2>&1; then
      if ! trash "$ROOT/.build"; then
        echo "WARN: trash .build failed; continuing with swift package clean." >&2
      fi
    else
      rm -rf "$ROOT/.build" || echo "WARN: rm -rf .build failed; continuing with swift package clean." >&2
    fi
  fi
  swift package clean >/dev/null 2>&1 || true
fi

# Build for host architecture by default; allow overriding via ARCHES (e.g., "arm64 x86_64" for universal).
ARCH_LIST=( ${ARCHES:-} )
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  HOST_ARCH=$(uname -m)
  case "$HOST_ARCH" in
    arm64) ARCH_LIST=(arm64) ;;
    x86_64) ARCH_LIST=(x86_64) ;;
    *) ARCH_LIST=("$HOST_ARCH") ;;
  esac
fi

patch_keyboard_shortcuts() {
  local util_path="$ROOT/.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"
  if [[ ! -f "$util_path" ]]; then
    return 0
  fi
  if grep -q "keyboardShortcutsSafeBundle" "$util_path"; then
    return 0
  fi

  chmod +w "$util_path" || true
  python3 - "$util_path" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
if ".keyboardShortcutsSafeBundle" in text:
    sys.exit(0)

text = text.replace(
    'NSLocalizedString(self, bundle: .module, comment: self)',
    'NSLocalizedString(self, bundle: .keyboardShortcutsSafeBundle, comment: self)',
)

inject = """
private extension Bundle {
    /// Safe lookup that avoids the fatal trap in the autogenerated `Bundle.module`
    /// when the resource bundle is not placed at the bundle root.
    static let keyboardShortcutsSafeBundle: Bundle = {
        #if os(macOS)
        if let url = Bundle.main.url(forResource: "KeyboardShortcuts_KeyboardShortcuts", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }

        let rootURL = Bundle.main.bundleURL.appendingPathComponent("KeyboardShortcuts_KeyboardShortcuts.bundle")
        if let bundle = Bundle(url: rootURL) {
            return bundle
        }
        #endif

        let devURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()  // Utilities.swift
            .deletingLastPathComponent()  // KeyboardShortcuts
            .deletingLastPathComponent()  // Sources
            .appendingPathComponent("KeyboardShortcuts_KeyboardShortcuts.bundle")
        if let bundle = Bundle(url: devURL) {
            return bundle
        }

        return Bundle.main
    }()
}
"""

marker = "}\n\n\nextension Data {"
if marker not in text:
    raise SystemExit("Marker not found in Utilities.swift; patch failed.")

text = text.replace(marker, "}\n\n" + inject + "\n\nextension Data {")
path.write_text(text)
PY
}

KEYBOARD_SHORTCUTS_UTIL="$ROOT/.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"
if [[ ! -f "$KEYBOARD_SHORTCUTS_UTIL" ]]; then
  swift build -c "$CONF" --arch "${ARCH_LIST[0]}"
fi
patch_keyboard_shortcuts

# Resolve SwiftPM's current output path without relying on a fixed build-system layout.
# The output variable keeps the per-arch cache in this shell instead of losing it to
# command substitution.
swiftpm_bin_path() {
  local arch="$1"
  local output_var="$2"
  local cache_var="SWIFTPM_BIN_PATH_${arch//[^A-Za-z0-9]/_}"
  if [[ -z "${!cache_var+set}" ]]; then
    local resolved
    if ! resolved=$(codexbar_swiftpm_bin_path "$CONF" "$arch"); then
      return 1
    fi
    printf -v "$cache_var" '%s' "$resolved"
  fi
  printf -v "$output_var" '%s' "${!cache_var}"
}

binary_has_arch() {
  local binary="$1"
  local arch="$2"
  [[ -f "$binary" ]] && lipo -archs "$binary" 2>/dev/null | tr ' ' '\n' | grep -qx "$arch"
}

# SwiftBuild can reuse one output directory for sequential per-arch builds. Snapshot
# each fresh slice before the next build can replace it.
PRODUCT_STAGE_ROOT="$ROOT/.build/package-products/$LOWER_CONF"
rm -rf "$PRODUCT_STAGE_ROOT"

stage_build_products() {
  local arch="$1"
  local bin_dir stage_dir name product
  swiftpm_bin_path "$arch" bin_dir

  stage_dir="$PRODUCT_STAGE_ROOT/$arch"
  mkdir -p "$stage_dir"
  for name in CodexBar CodexBarCLI CodexBarClaudeWatchdog CodexBarWidget; do
    if ! product=$(codexbar_require_product_file "$bin_dir" "$name" "$arch"); then
      return 1
    fi
    if ! binary_has_arch "$product" "$arch"; then
      echo "ERROR: ${product} does not contain required architecture: ${arch}" >&2
      return 1
    fi
    cp "$product" "$stage_dir/$name"
  done
  if [[ -d "$bin_dir/CodexBar.dSYM" ]]; then
    cp -R "$bin_dir/CodexBar.dSYM" "$stage_dir/"
  fi
}

for ARCH in "${ARCH_LIST[@]}"; do
  swift build -c "$CONF" --arch "$ARCH"
  stage_build_products "$ARCH"
done

APP_FINAL="$ROOT/TokenBar.app"
APP_STAGE="$ROOT/.build/package/TokenBar.app"
rm -rf "$APP_STAGE"
APP="$APP_STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/Helpers" "$APP/Contents/PlugIns"

# Convert new .icon bundle to .icns if present (macOS 14+/IconStudio export)
ICON_SOURCE="$ROOT/Icon.icon"
ICON_TARGET="$ROOT/Icon.icns"
if [[ -f "$ICON_SOURCE" ]]; then
  iconutil --convert icns --output "$ICON_TARGET" "$ICON_SOURCE"
fi

ENTITLEMENTS_DIR="$ROOT/.build/entitlements"
APP_ENTITLEMENTS="${ENTITLEMENTS_DIR}/TokenBar.entitlements"
WIDGET_ENTITLEMENTS="${ENTITLEMENTS_DIR}/TokenBarWidget.entitlements"
mkdir -p "$ENTITLEMENTS_DIR"
if [[ "$ALLOW_LLDB" == "1" && "$LOWER_CONF" != "debug" ]]; then
  echo "ERROR: TOKENBAR_ALLOW_LLDB requires debug configuration" >&2
  exit 1
fi
IDENTITY_ENTITLEMENT_KEYS=""
if [[ "$SIGNING_MODE" == "identity" ]]; then
  IDENTITY_ENTITLEMENT_KEYS=$(cat <<IDENTITY
    <key>com.apple.application-identifier</key>
    <string>${APP_TEAM_ID}.${BUNDLE_ID}</string>
    <key>com.apple.developer.team-identifier</key>
    <string>${APP_TEAM_ID}</string>
IDENTITY
)
fi
# CloudKit remains disabled until TokenBar owns a matching CloudKit container/profile.
# Formal identity builds include only the identity, team, and app-group entitlements
# authorized by TOKENBAR_PROVISIONING_PROFILE; ad-hoc builds retain their existing shape.
cat > "$APP_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
${IDENTITY_ENTITLEMENT_KEYS}
    $(if [[ -n "$APP_GROUP_ID" ]]; then printf '%s\n' \
      '    <key>com.apple.security.application-groups</key>' \
      '    <array>' \
      "        <string>${APP_GROUP_ID}</string>" \
      '    </array>'; fi)
    $(if [[ "$ALLOW_LLDB" == "1" ]]; then echo "    <key>com.apple.security.get-task-allow</key><true/>"; fi)
</dict>
</plist>
PLIST
cat > "$WIDGET_ENTITLEMENTS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    $(if [[ -n "$APP_GROUP_ID" ]]; then printf '%s\n' \
      '    <key>com.apple.security.application-groups</key>' \
      '    <array>' \
      "        <string>${APP_GROUP_ID}</string>" \
      '    </array>'; fi)
</dict>
</plist>
PLIST
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TokenBar</string>
    <key>CFBundleDisplayName</key><string>TokenBar</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>TokenBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>TokenBar contributors. MIT License.</string>
    <key>SUFeedURL</key><string>${FEED_URL}</string>
    <key>SUPublicEDKey</key><string>AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=</string>
    <key>SUEnableAutomaticChecks</key><${AUTO_CHECKS}/>
    <key>TokenBarBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>TokenBarGitCommit</key><string>${GIT_COMMIT}</string>
    <key>TokenBarTeamID</key><string>${APP_TEAM_ID}</string>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key><string>com.y0shua1ee.tokenbar.menu-layout-item</string>
            <key>UTTypeDescription</key><string>TokenBar menu bar layout token</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict/>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Resolve a built binary from the fresh per-arch snapshot or SwiftPM's reported directory.
resolve_binary_path() {
  local name="$1"
  local arch="$2"
  local bin_dir candidate
  swiftpm_bin_path "$arch" bin_dir
  if ! candidate=$(codexbar_resolve_staged_or_reported_file \
    "$PRODUCT_STAGE_ROOT" "$bin_dir" "$name" "$arch"); then
    return 1
  fi
  if ! binary_has_arch "$candidate" "$arch"; then
    echo "ERROR: ${candidate} does not contain required architecture: ${arch}" >&2
    return 1
  fi
  echo "$candidate"
}

verify_binary_arches() {
  local binary="$1"; shift
  local expected=("$@")
  local actual
  actual=$(lipo -archs "$binary")
  local actual_count expected_count
  actual_count=$(wc -w <<<"$actual" | tr -d ' ')
  expected_count=${#expected[@]}
  if [[ "$actual_count" -ne "$expected_count" ]]; then
    echo "ERROR: $binary arch mismatch (expected: ${expected[*]}, actual: ${actual})" >&2
    exit 1
  fi
  for arch in "${expected[@]}"; do
    if [[ "$actual" != *"$arch"* ]]; then
      echo "ERROR: $binary missing arch $arch (have: ${actual})" >&2
      exit 1
    fi
  done
}

install_binary() {
  local name="$1"
  local dest="$2"
  local binaries=()
  for arch in "${ARCH_LIST[@]}"; do
    local src
    if ! src=$(resolve_binary_path "$name" "$arch"); then
      exit 1
    fi
    binaries+=("$src")
  done
  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$dest"
  else
    cp "${binaries[0]}" "$dest"
  fi
  chmod +x "$dest"
  verify_binary_arches "$dest" "${ARCH_LIST[@]}"
}

strip_release_binary() {
  local binary="$1"
  if [[ "$LOWER_CONF" != "release" ]]; then
    return 0
  fi
  if [[ ! -f "$binary" ]]; then
    return 0
  fi
  xcrun strip -x "$binary"
}

ensure_widget_extension_project() {
  local spec="$ROOT/WidgetExtension/project.yml"
  local project_dir="$ROOT/WidgetExtension/CodexBarWidgetExtension.xcodeproj"
  if [[ -f "$project_dir/project.pbxproj" ]]; then
    return
  fi
  if ! command -v xcodegen >/dev/null 2>&1; then
    echo "ERROR: Missing ${project_dir}; install xcodegen or restore the generated project." >&2
    exit 1
  fi

  # The tracked project is authoritative. Regenerating it during packaging records the checkout
  # directory's spelling in a package file reference and leaves release worktrees dirty.
  xcodegen generate --spec "$spec" --project "$ROOT/WidgetExtension" --quiet
}

build_widget_extension_with_xcode() {
  local xcode_conf="Release"
  if [[ "$LOWER_CONF" == "debug" ]]; then
    xcode_conf="Debug"
  fi

  ensure_widget_extension_project

  local derived_dir="$ROOT/.build/xcode-widget-extension-${LOWER_CONF}"
  local project_dir="$ROOT/WidgetExtension/CodexBarWidgetExtension.xcodeproj"
  local build_log="$derived_dir/xcodebuild.log"
  local timeout_seconds="${CODEXBAR_WIDGET_EXTENSION_TIMEOUT_SECONDS:-900}"
  local archs="${ARCH_LIST[*]}"

  mkdir -p "$derived_dir"
  echo "Building CodexBarWidget Xcode extension for TokenBar (${xcode_conf}, ${archs})." >&2
  xcodebuild \
    -project "$project_dir" \
    -scheme CodexBarWidgetExtension \
    -configuration "$xcode_conf" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$derived_dir" \
    -skipPackageUpdates \
    -disableAutomaticPackageResolution \
    -skipMacroValidation \
    -skipPackagePluginValidation \
    TOKENBAR_WIDGET_BUNDLE_ID="$WIDGET_BUNDLE_ID" \
    CODEXBAR_WIDGET_BUNDLE_ID="$WIDGET_BUNDLE_ID" \
    TOKENBAR_TEAM_ID="$APP_TEAM_ID" \
    CODEXBAR_TEAM_ID="$APP_TEAM_ID" \
    MARKETING_VERSION="$MARKETING_VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO \
    ARCHS="$archs" \
    ONLY_ACTIVE_ARCH=NO \
    build >"$build_log" 2>&1 &

  local xcodebuild_pid=$!
  local elapsed=0
  while kill -0 "$xcodebuild_pid" 2>/dev/null; do
    if [[ "$elapsed" -ge "$timeout_seconds" ]]; then
      kill "$xcodebuild_pid" 2>/dev/null || true
      wait "$xcodebuild_pid" 2>/dev/null || true
      tail -80 "$build_log" >&2 || true
      echo "ERROR: Timed out building CodexBarWidget extension after ${timeout_seconds}s" >&2
      exit 1
    fi
    sleep 5
    elapsed=$((elapsed + 5))
    if (( elapsed > 0 && elapsed % 60 == 0 )); then
      echo "Still building CodexBarWidget extension (${elapsed}s)..." >&2
    fi
  done
  if ! wait "$xcodebuild_pid"; then
    tail -120 "$build_log" >&2 || true
    echo "ERROR: Failed to build CodexBarWidget extension" >&2
    exit 1
  fi

  local appex="$derived_dir/Build/Products/${xcode_conf}/CodexBarWidget.appex"
  if [[ ! -f "$appex/Contents/MacOS/CodexBarWidget" ]]; then
    echo "ERROR: Missing Xcode-built CodexBarWidget.appex at ${appex}" >&2
    exit 1
  fi
  echo "$appex"
}

build_widget_extension_from_swiftpm() {
  local appex="$ROOT/.build/package/CodexBarWidget.appex"
  rm -rf "$appex"
  mkdir -p "$appex/Contents/MacOS" "$appex/Contents/Resources"
  install_binary "CodexBarWidget" "$appex/Contents/MacOS/CodexBarWidget"
  cat >"$appex/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>TokenBar</string>
    <key>CFBundleExecutable</key>
    <string>CodexBarWidget</string>
    <key>CFBundleIdentifier</key>
    <string>${WIDGET_BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>CodexBarWidget</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>CFBundleShortVersionString</key>
    <string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>TokenBarTeamID</key>
    <string>${APP_TEAM_ID}</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.widgetkit-extension</string>
    </dict>
</dict>
</plist>
PLIST
  printf 'XPC!' >"$appex/Contents/PkgInfo"
  plutil -lint "$appex/Contents/Info.plist" >/dev/null
  echo "$appex"
}

build_widget_extension() {
  local builder="${TOKENBAR_WIDGET_EXTENSION_BUILDER:-xcode}"

  case "$builder" in
    swiftpm)
      build_widget_extension_from_swiftpm
      ;;
    xcode)
      build_widget_extension_with_xcode
      ;;
    *)
      echo "ERROR: Unsupported TOKENBAR_WIDGET_EXTENSION_BUILDER=${builder}" >&2
      exit 1
      ;;
  esac
}

install_widget_extension() {
  local src_appex
  src_appex="$(build_widget_extension)"
  local widget_app="$APP/Contents/PlugIns/CodexBarWidget.appex"
  rm -rf "$widget_app"
  mkdir -p "$APP/Contents/PlugIns"
  cp -R "$src_appex" "$widget_app"
  verify_binary_arches "$widget_app/Contents/MacOS/CodexBarWidget" "${ARCH_LIST[@]}"
}

install_binary "CodexBar" "$APP/Contents/MacOS/TokenBar"
strip_release_binary "$APP/Contents/MacOS/TokenBar"
# Ship the internal CodexBarCLI product under TokenBar's public CLI names.
install_binary "CodexBarCLI" "$APP/Contents/Helpers/TokenBarCLI"
ln -s "TokenBarCLI" "$APP/Contents/Helpers/tokenbar"
strip_release_binary "$APP/Contents/Helpers/TokenBarCLI"
# Watchdog helper: ensures `claude` probes die when CodexBar crashes/gets killed.
install_binary "CodexBarClaudeWatchdog" "$APP/Contents/Helpers/CodexBarClaudeWatchdog"
strip_release_binary "$APP/Contents/Helpers/CodexBarClaudeWatchdog"
install_widget_extension
strip_release_binary "$APP/Contents/PlugIns/CodexBarWidget.appex/Contents/MacOS/CodexBarWidget"

swiftpm_bin_path "${ARCH_LIST[0]}" PREFERRED_BUILD_DIR

# Embed Sparkle.framework
SPARKLE_SOURCE=$(codexbar_require_product_directory "$PREFERRED_BUILD_DIR" Sparkle.framework packaging)
cp -R "$SPARKLE_SOURCE" "$APP/Contents/Frameworks/"
chmod -R a+rX "$APP/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/TokenBar"
# Re-sign Sparkle and all nested components with the selected package identity.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ "$SIGNING_MODE" == "adhoc" ]]; then
  CODESIGN_ID="-"
  CODESIGN_ARGS=(--force --sign "$CODESIGN_ID")
elif [[ "$ALLOW_LLDB" == "1" ]]; then
  CODESIGN_ID="-"
  CODESIGN_ARGS=(--force --sign "$CODESIGN_ID")
else
  CODESIGN_ID="$APP_IDENTITY"
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$CODESIGN_ID")
fi
function resign() { codesign "${CODESIGN_ARGS[@]}" "$1"; }
# Validate Sparkle's nested layout before signing so framework layout drift fails clearly.
SPARKLE_SIGNING_TARGETS=$(codexbar_sparkle_signing_targets "$SPARKLE")
while IFS= read -r SPARKLE_TARGET; do
  resign "$SPARKLE_TARGET"
done <<<"$SPARKLE_SIGNING_TARGETS"

if [[ -f "$ICON_TARGET" ]]; then
  cp "$ICON_TARGET" "$APP/Contents/Resources/Icon.icns"
fi

# Bundle app resources (provider icons, etc.).
APP_RESOURCES_DIR="$ROOT/Sources/CodexBar/Resources"
if [[ -d "$APP_RESOURCES_DIR" ]]; then
  cp -R "$APP_RESOURCES_DIR/." "$APP/Contents/Resources/"
fi
if [[ ! -f "$APP/Contents/Resources/Icon-classic.icns" ]]; then
  echo "ERROR: Missing Icon-classic.icns in app bundle resources." >&2
  exit 1
fi

# SwiftPM resource bundles (e.g. KeyboardShortcuts) are emitted next to the built binary.
shopt -s nullglob
SWIFTPM_BUNDLES=("${PREFERRED_BUILD_DIR}/"*.bundle)
shopt -u nullglob
if [[ ${#SWIFTPM_BUNDLES[@]} -gt 0 ]]; then
  for bundle in "${SWIFTPM_BUNDLES[@]}"; do
    bundle_name="$(basename "$bundle")"
    cp -R "$bundle" "$APP/Contents/Resources/"
  done
fi
if [[ ! -d "$APP/Contents/Resources/KeyboardShortcuts_KeyboardShortcuts.bundle" ]]; then
  echo "ERROR: Missing KeyboardShortcuts SwiftPM resource bundle (Settings → Keyboard shortcut will crash)." >&2
  echo "Expected: ${PREFERRED_BUILD_DIR}/KeyboardShortcuts_KeyboardShortcuts.bundle" >&2
  exit 1
fi

# The helper CLI resolves CodexBarCore resources beside its executable. Keep a
# dedicated copy in Helpers; the app copy above remains in Contents/Resources.
CORE_RESOURCE_BUNDLE="${PREFERRED_BUILD_DIR}/CodexBar_CodexBarCore.bundle"
if [[ ! -d "$CORE_RESOURCE_BUNDLE" ]]; then
  echo "ERROR: Missing CodexBarCore SwiftPM resource bundle for TokenBarCLI." >&2
  echo "Expected: ${CORE_RESOURCE_BUNDLE}" >&2
  exit 1
fi
rm -rf "$APP/Contents/Helpers/CodexBar_CodexBarCore.bundle"
cp -R "$CORE_RESOURCE_BUNDLE" "$APP/Contents/Helpers/"

if [[ "$SIGNING_MODE" == "identity" ]]; then
  cp "$PROVISIONING_PROFILE_SOURCE" "$APP/Contents/embedded.provisionprofile"
fi

# Ensure contents are writable before stripping attributes and signing.
chmod -R u+w "$APP"

# Strip extended attributes to prevent AppleDouble (._*) files that break code sealing
xattr -cr "$APP"
find "$APP" -name '._*' -delete

# Sign helper binaries if present
if [[ -f "${APP}/Contents/Helpers/TokenBarCLI" ]]; then
  codesign "${CODESIGN_ARGS[@]}" "${APP}/Contents/Helpers/TokenBarCLI"
fi
if [[ -d "${APP}/Contents/Helpers/CodexBar_CodexBarCore.bundle" ]]; then
  codesign "${CODESIGN_ARGS[@]}" "${APP}/Contents/Helpers/CodexBar_CodexBarCore.bundle"
fi
if [[ -f "${APP}/Contents/Helpers/CodexBarClaudeWatchdog" ]]; then
  codesign "${CODESIGN_ARGS[@]}" "${APP}/Contents/Helpers/CodexBarClaudeWatchdog"
fi

# Sign widget extension if present
if [[ -d "${APP}/Contents/PlugIns/CodexBarWidget.appex" ]]; then
  codesign "${CODESIGN_ARGS[@]}" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP/Contents/PlugIns/CodexBarWidget.appex/Contents/MacOS/CodexBarWidget"
  codesign "${CODESIGN_ARGS[@]}" \
    --entitlements "$WIDGET_ENTITLEMENTS" \
    "$APP/Contents/PlugIns/CodexBarWidget.appex"
fi

# Finally sign the app bundle itself
codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$APP_ENTITLEMENTS" \
  "$APP"

rm -rf "$APP_FINAL"
mv "$APP" "$APP_FINAL"
APP="$APP_FINAL"
verify_packaged_app_integrity "$APP"
if [[ "$SIGNING_MODE" == "identity" ]]; then
  verify_identity_signed_app "$APP" "$APP_TEAM_ID" "$BUNDLE_ID" "$APP_GROUP_ID"
fi
# Release gate for the 0.48.0 crash class (#2738): launch the packaged binary
# with the build checkout unreadable so a `Bundle.module`-style compile-time
# path dependency fails packaging here instead of on user machines.
if [[ "$LOWER_CONF" == "release" ]]; then
  "$ROOT/Scripts/verify_packaged_app_launch.sh" "$APP"
fi
echo "Created $APP"
