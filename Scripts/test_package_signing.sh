#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
PACKAGE_SCRIPT="$ROOT/Scripts/package_app.sh"
RELEASE_SCRIPT="$ROOT/Scripts/sign-and-notarize.sh"
FUNCTIONS_FILE=$(mktemp "${TMPDIR:-/tmp}/codexbar-package-signing-functions.XXXXXX")
trap 'rm -f "$FUNCTIONS_FILE"' EXIT

python3 - "$PACKAGE_SCRIPT" "$FUNCTIONS_FILE" <<'PY'
import sys
from pathlib import Path

script = Path(sys.argv[1]).read_text()
functions = []
for name in (
    'resolve_package_signing_mode',
    'verify_no_quarantine_attribute',
    'verify_packaged_app_integrity',
    'verify_tokenbar_provisioning_profile',
    'verify_identity_signed_app',
):
    start = script.index(f'{name}() {{')
    end = script.index('\n}\n', start) + 3
    functions.append(script[start:end])
Path(sys.argv[2]).write_text('\n\n'.join(functions))
PY

source "$FUNCTIONS_FILE"

unset CODEXBAR_SIGNING
unset TOKENBAR_SIGNING
SIGNING_MODE=
resolve_package_signing_mode
[[ "$SIGNING_MODE" == "adhoc" ]]

TOKENBAR_SIGNING=identity
resolve_package_signing_mode
[[ "$SIGNING_MODE" == "identity" ]]

TOKENBAR_SIGNING=invalid
if resolve_package_signing_mode 2>/dev/null; then
  echo "Invalid package signing mode unexpectedly succeeded" >&2
  exit 1
fi

grep -Fq 'TOKENBAR_SIGNING=identity' "$RELEASE_SCRIPT"
grep -Fq 'APP_IDENTITY="${APP_IDENTITY:-}"' "$RELEASE_SCRIPT"
if grep -Fq 'Peter Steinberger' "$RELEASE_SCRIPT"; then
  echo "Release script unexpectedly inherited an upstream signing identity" >&2
  exit 1
fi

if env -u APP_IDENTITY -u APP_TEAM_ID TOKENBAR_SIGNING=identity "$PACKAGE_SCRIPT" release \
  2>/dev/null; then
  echo "Identity packaging unexpectedly accepted a missing APP_IDENTITY/APP_TEAM_ID" >&2
  exit 1
fi
if env -u APP_IDENTITY -u APP_TEAM_ID \
  APP_STORE_CONNECT_API_KEY_P8=dummy \
  APP_STORE_CONNECT_KEY_ID=dummy \
  APP_STORE_CONNECT_ISSUER_ID=dummy \
  "$RELEASE_SCRIPT" 2>/dev/null; then
  echo "Formal release unexpectedly accepted a missing APP_IDENTITY/APP_TEAM_ID" >&2
  exit 1
fi

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/codexbar-package-signing.XXXXXX")
trap 'rm -f "$FUNCTIONS_FILE"; rm -rf "$TEMP_DIR"' EXIT
APP="$TEMP_DIR/TokenBar.app"
mkdir -p "$APP/Contents/Frameworks/Sparkle.framework"
PROFILE="$TEMP_DIR/TokenBar.provisionprofile"
ENTITLEMENTS="$TEMP_DIR/TokenBar.entitlements"

python3 - "$PROFILE" "$ENTITLEMENTS" <<'PY'
import plistlib
import sys
from pathlib import Path

team = "TESTTEAM01"
bundle = "com.y0shua1ee.tokenbar"
group = f"{team}.{bundle}"
entitlements = {
    "application-identifier": f"{team}.{bundle}",
    "com.apple.developer.team-identifier": team,
    "com.apple.security.application-groups": [group],
}
profile = {
    "TeamIdentifier": [team],
    "ProvisionsAllDevices": True,
    "Entitlements": entitlements,
}
Path(sys.argv[1]).write_bytes(plistlib.dumps(profile))
Path(sys.argv[2]).write_bytes(plistlib.dumps({
    "com.apple.application-identifier": f"{team}.{bundle}",
    "com.apple.developer.team-identifier": team,
    "com.apple.security.application-groups": [group],
}))
PY

xattr() {
  if [[ "${MOCK_QUARANTINE:-0}" == "1" ]]; then
    printf '0081;fake;Safari;https://example.invalid\n'
    return 0
  fi
  return 1
}

security() {
  local input="${!#}"
  [[ "$1" == "cms" && "$2" == "-D" && "$3" == "-i" ]] || return 1
  cat "$input"
}

codesign() {
  if [[ "$*" == *"-dv --verbose=4"* ]]; then
    printf 'Identifier=%s\nTeamIdentifier=%s\n' \
      "${MOCK_CODESIGN_IDENTIFIER:-com.y0shua1ee.tokenbar}" \
      "${MOCK_CODESIGN_TEAM:-TESTTEAM01}"
    return "${MOCK_CODESIGN_STATUS:-0}"
  fi
  if [[ "$*" == *"-d --entitlements :-"* ]]; then
    cat "$ENTITLEMENTS"
    return "${MOCK_CODESIGN_STATUS:-0}"
  fi
  return "${MOCK_CODESIGN_STATUS:-0}"
}

verify_packaged_app_integrity "$APP"

# Provisioning-profile parsing uses macOS's PlistBuddy. Keep the surrounding release checks portable, and exercise
# these platform-specific assertions from lint-macos and local macOS lint runs.
if [[ -x /usr/libexec/PlistBuddy ]]; then
  verify_tokenbar_provisioning_profile \
    "$PROFILE" TESTTEAM01 com.y0shua1ee.tokenbar TESTTEAM01.com.y0shua1ee.tokenbar

  mkdir -p "$APP/Contents"
  cp "$PROFILE" "$APP/Contents/embedded.provisionprofile"
  verify_identity_signed_app \
    "$APP" TESTTEAM01 com.y0shua1ee.tokenbar TESTTEAM01.com.y0shua1ee.tokenbar

  if verify_tokenbar_provisioning_profile \
    "$PROFILE" TESTTEAM01 com.y0shua1ee.tokenbar TESTTEAM01.com.y0shua1ee.tokenbar.wrong 2>/dev/null; then
    echo "Profile with an unauthorized app group unexpectedly passed" >&2
    exit 1
  fi

  export MOCK_CODESIGN_TEAM=WRONGTEAM1
  if verify_identity_signed_app \
    "$APP" TESTTEAM01 com.y0shua1ee.tokenbar TESTTEAM01.com.y0shua1ee.tokenbar 2>/dev/null; then
    echo "Signature with a mismatched team unexpectedly passed" >&2
    exit 1
  fi
  unset MOCK_CODESIGN_TEAM
fi

export MOCK_QUARANTINE=1
if verify_packaged_app_integrity "$APP" 2>/dev/null; then
  echo "Quarantined app unexpectedly passed integrity verification" >&2
  exit 1
fi
unset MOCK_QUARANTINE

export MOCK_CODESIGN_STATUS=1
if verify_packaged_app_integrity "$APP" 2>/dev/null; then
  echo "App with an invalid signature unexpectedly passed integrity verification" >&2
  exit 1
fi
unset MOCK_CODESIGN_STATUS

echo "Package signing tests passed."
