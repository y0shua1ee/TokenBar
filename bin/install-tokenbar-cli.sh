#!/usr/bin/env bash
set -euo pipefail

APP="/Applications/TokenBar.app"
HELPER="$APP/Contents/Helpers/TokenBarCLI"
TARGETS=("/usr/local/bin/tokenbar" "/opt/homebrew/bin/tokenbar")

if [[ ! -x "$HELPER" ]]; then
  echo "TokenBarCLI helper not found at $HELPER. Please reinstall TokenBar." >&2
  exit 1
fi

install_script=$(mktemp)
cat > "$install_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HELPER="__HELPER__"
TARGETS=("/usr/local/bin/tokenbar" "/opt/homebrew/bin/tokenbar")

for t in "${TARGETS[@]}"; do
  mkdir -p "$(dirname "$t")"
  ln -sf "$HELPER" "$t"
  echo "Linked $t -> $HELPER"
done
EOF

perl -pi -e "s#__HELPER__#$HELPER#g" "$install_script"

osascript -e "do shell script \"bash '$install_script'\" with administrator privileges"
rm -f "$install_script"

echo "TokenBar CLI installed. Try: tokenbar usage"
