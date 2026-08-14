#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONF=${1:-release}
OUT_DIR="$ROOT/.build/tokenbar-cli/$CONF"

source "$ROOT/version.env"
source "$ROOT/Scripts/package_product_paths.sh"

swift build -c "$CONF" --product CodexBarCLI
BIN_DIR=$(codexbar_swiftpm_bin_path "$CONF")
INTERNAL_CLI=$(codexbar_require_product_file "$BIN_DIR" CodexBarCLI "$CONF")
CORE_BUNDLE=$(codexbar_require_product_directory "$BIN_DIR" CodexBar_CodexBarCore.bundle "$CONF")

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"
cp "$INTERNAL_CLI" "$OUT_DIR/TokenBarCLI"
chmod +x "$OUT_DIR/TokenBarCLI"
ln -s TokenBarCLI "$OUT_DIR/tokenbar"
cp -R "$CORE_BUNDLE" "$OUT_DIR/"
printf '%s\n' "$MARKETING_VERSION" > "$OUT_DIR/VERSION"

echo "Created standalone TokenBar CLI at $OUT_DIR"
