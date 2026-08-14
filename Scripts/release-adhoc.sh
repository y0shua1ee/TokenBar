#!/usr/bin/env bash
set -euo pipefail

APP_NAME="TokenBar"
INTERNAL_APP_NAME="CodexBar"
APP_BUNDLE="TokenBar.app"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

SKIP_CHECKS=0
PUBLISH=0
WAIT_ASSETS=0
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
WAIT_SECONDS=${TOKENBAR_ADHOC_WAIT_ASSETS_SECONDS:-3600}
WAIT_INTERVAL=${TOKENBAR_ADHOC_WAIT_ASSETS_INTERVAL:-30}

usage() {
  cat <<'EOF'
Usage: Scripts/release-adhoc.sh [--publish] [--wait-assets] [--skip-checks] [--arches "arm64 x86_64"]

Build an ad-hoc signed TokenBar release package for personal/manual distribution.
This path does not notarize, use a provisioning profile, enable iCloud, or
generate/update a Sparkle appcast. Publishing is opt-in with --publish.

Options:
  --publish          Create/push the git tag and GitHub Release with app + dSYM assets.
  --wait-assets      After publishing, wait for all release assets.
  --skip-checks      Skip make check and make test after those gates have already passed.
  --arches VALUE     Build architectures, default: "arm64 x86_64".
EOF
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      PUBLISH=1
      ;;
    --wait-assets)
      WAIT_ASSETS=1
      ;;
    --skip-checks)
      SKIP_CHECKS=1
      ;;
    --arches)
      shift
      [[ $# -gt 0 ]] || die "--arches requires a value"
      ARCHES_VALUE=$1
      ;;
    --arches=*)
      ARCHES_VALUE=${1#*=}
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
  shift
done

require_bin() {
  local bin
  for bin in "$@"; do
    command -v "$bin" >/dev/null 2>&1 || die "Missing required tool: $bin"
  done
}

require_clean_worktree() {
  [[ -z $(git status --porcelain) ]] || die "Working tree is not clean; commit or stash before publishing."
}

normalize_github_repo() {
  local remote_url=$1 repo_path

  case "$remote_url" in
    git@github.com:*) repo_path=${remote_url#git@github.com:} ;;
    ssh://git@github.com/*) repo_path=${remote_url#ssh://git@github.com/} ;;
    https://github.com/*) repo_path=${remote_url#https://github.com/} ;;
    http://github.com/*) repo_path=${remote_url#http://github.com/} ;;
    *) return 1 ;;
  esac

  repo_path=${repo_path%/}
  repo_path=${repo_path%.git}
  [[ "$repo_path" == */* && "$repo_path" != */*/* ]] || return 1
  printf '%s\n' "$repo_path"
}

require_release_origin() {
  local origin_url origin_repo

  origin_url=$(git remote get-url origin) || die "Missing git remote: origin"
  if ! origin_repo=$(normalize_github_repo "$origin_url"); then
    die "origin is not a supported GitHub repository URL: $origin_url"
  fi
  [[ "$origin_repo" == "$REPO" ]] || \
    die "origin targets $origin_repo, but release repository is $REPO"
}

validate_changelog() {
  python3 - "$MARKETING_VERSION" <<'PY'
import pathlib
import re
import sys

version = sys.argv[1]
text = pathlib.Path("CHANGELOG.md").read_text()
first = re.search(r"^##\s+(.+)$", text, re.M)
if not first:
    raise SystemExit("No changelog sections found")
header = first.group(1)
if "Unreleased" in header:
    raise SystemExit("Top changelog section is still marked Unreleased")
if not (header.startswith(f"{version} ") or header.startswith(f"{version} -") or header.startswith(f"{version} —")):
    raise SystemExit(f"Top changelog section '{header}' does not match version {version}")
PY
}

verify_adhoc_bundle() {
  local feed_url auto_checks signature team_id

  codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
  signature=$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1 | awk -F= '$1 == "Signature" { print $2; exit }')
  [[ "$signature" == "adhoc" ]] || die "Expected ad-hoc signature, got: ${signature:-unknown}"

  feed_url=$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)
  [[ -z "$feed_url" ]] || die "Ad-hoc bundle must use an empty SUFeedURL; got: $feed_url"

  auto_checks=$(/usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)
  [[ "$auto_checks" == "false" ]] || die "Ad-hoc bundle must disable Sparkle automatic checks"

  team_id=$(/usr/libexec/PlistBuddy -c 'Print :TokenBarTeamID' "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true)
  [[ -z "$team_id" ]] || die "Ad-hoc bundle must not claim a development team"
  [[ ! -f "$APP_BUNDLE/Contents/embedded.provisionprofile" ]] || die "Ad-hoc bundle must not embed a provisioning profile"
}

package_dsym() {
  local dsym_stage_root="$ROOT/.build/package-products/release"
  local dsym_path arch staged_dsym arch_dsym dwarf_path merged_dsym_root merged_dsym
  local dsym_paths=()
  local dsym_dwarf_paths=()

  for arch in "${ARCH_LIST[@]}"; do
    staged_dsym="$dsym_stage_root/$arch/${INTERNAL_APP_NAME}.dSYM"
    if [[ -d "$staged_dsym" ]]; then
      dsym_paths+=("$staged_dsym")
      continue
    fi
    local bin_dir
    bin_dir=$(codexbar_swiftpm_bin_path release "$arch")
    dsym_paths+=("$(codexbar_resolve_dsym_path "$dsym_stage_root" "$bin_dir" "$INTERNAL_APP_NAME" "$arch")")
  done

  dsym_path="${dsym_paths[0]}"
  for index in "${!ARCH_LIST[@]}"; do
    arch="${ARCH_LIST[$index]}"
    arch_dsym=$(codexbar_require_dsym_dwarf_for_arch "${dsym_paths[$index]}" "$INTERNAL_APP_NAME" "$arch")
    dsym_dwarf_paths+=("$arch_dsym")
  done

  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    merged_dsym_root="$dsym_stage_root/${APP_NAME}.dSYM-adhoc-universal"
    merged_dsym="$merged_dsym_root/${APP_NAME}.dSYM"
    rm -rf "$merged_dsym_root"
    mkdir -p "$merged_dsym_root"
    cp -R "$dsym_path" "$merged_dsym"
    dwarf_path="$merged_dsym/Contents/Resources/DWARF/${INTERNAL_APP_NAME}"
    lipo -create "${dsym_dwarf_paths[@]}" -output "$dwarf_path"
    dsym_path="$merged_dsym"
  fi

  codexbar_verify_dsym_matches_binary \
    "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$dsym_path/Contents/Resources/DWARF/$INTERNAL_APP_NAME" \
    "${ARCH_LIST[@]}"
  /usr/bin/ditto --norsrc -c -k --keepParent "$dsym_path" "$DSYM_ZIP"
}

publish_release() {
  local notes_md tag_args=() release_assets=("$ZIP_NAME" "$DSYM_ZIP")
  local current_branch release_branch remote_tag_status

  require_bin gh
  require_clean_worktree
  require_release_origin

  release_branch=${TOKENBAR_ADHOC_RELEASE_BRANCH:-main}
  current_branch=$(git branch --show-current)
  [[ "$current_branch" == "$release_branch" ]] || \
    die "Release must run on $release_branch; current branch is ${current_branch:-detached}"

  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    die "Local tag already exists: $TAG"
  fi
  set +e
  git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1
  remote_tag_status=$?
  set -e
  case "$remote_tag_status" in
    0) die "Remote tag already exists: $TAG" ;;
    2) ;;
    *) die "Could not verify remote tag state for $TAG" ;;
  esac
  gh repo view "$REPO" --json nameWithOwner --jq .nameWithOwner >/dev/null || \
    die "Could not reach GitHub repo: $REPO"
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    die "GitHub Release already exists: $TAG"
  fi

  notes_md=$(mktemp "/tmp/${APP_NAME}-adhoc-notes.XXXXXX")
  trap 'rm -f "${notes_md:-}"' RETURN
  "$ROOT/Scripts/mac-release" notes "$MARKETING_VERSION" "$notes_md"

  tag_args=(-m "${APP_NAME} ${MARKETING_VERSION} (ad-hoc)")
  git tag "${tag_args[@]}" "$TAG"
  git push origin "$TAG"
  gh release create "$TAG" "${release_assets[@]}" \
    --repo "$REPO" \
    --title "${APP_NAME} ${MARKETING_VERSION}" \
    --notes-file "$notes_md" \
    --verify-tag
}

wait_for_release_assets() {
  local deadline=$((SECONDS + WAIT_SECONDS))

  until "$ROOT/Scripts/check-release-assets.sh" "$TAG"; do
    [[ "$SECONDS" -lt "$deadline" ]] || die "Timed out waiting for complete release assets on $TAG"
    echo "Waiting for release assets on $TAG..."
    sleep "$WAIT_INTERVAL"
  done
}

require_bin swift lipo codesign xattr
source "$ROOT/version.env"
source "$ROOT/Scripts/release_artifacts.sh"
source "$ROOT/Scripts/package_product_paths.sh"
source "$ROOT/Scripts/release_dsym_paths.sh"

ZIP_NAME=$(tokenbar_app_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")
DSYM_ZIP=$(tokenbar_dsym_zip_name "$MARKETING_VERSION" "$ARCHES_VALUE")
REPO=${TOKENBAR_ADHOC_RELEASE_REPO:-y0shua1ee/TokenBar}
TAG=${TOKENBAR_ADHOC_TAG:-v${MARKETING_VERSION}}
ARCH_LIST=( $ARCHES_VALUE )
[[ ${#ARCH_LIST[@]} -gt 0 ]] || die "No architectures requested"

validate_changelog

if [[ "$SKIP_CHECKS" != "1" ]]; then
  make check
  make test
fi

rm -f "$ZIP_NAME" "$DSYM_ZIP"
env -u APP_IDENTITY -u APP_TEAM_ID -u TOKENBAR_PROVISIONING_PROFILE \
  TOKENBAR_WIDGET_EXTENSION_BUILDER="${TOKENBAR_WIDGET_EXTENSION_BUILDER:-swiftpm}" \
  TOKENBAR_SIGNING=adhoc ARCHES="$ARCHES_VALUE" \
  "$ROOT/Scripts/package_app.sh" release
verify_adhoc_bundle
xattr -cr "$APP_BUNDLE"
find "$APP_BUNDLE" -name '._*' -delete
/usr/bin/ditto --norsrc -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"
package_dsym

echo "Ad-hoc release artifacts:"
shasum -a 256 "$ZIP_NAME" "$DSYM_ZIP"

if [[ "$PUBLISH" == "1" ]]; then
  publish_release
  if [[ "$WAIT_ASSETS" == "1" ]]; then
    wait_for_release_assets
  fi
  echo "Ad-hoc GitHub Release published: $TAG"
else
  echo "Ad-hoc artifacts built locally. Re-run with --publish to create the GitHub Release."
fi
