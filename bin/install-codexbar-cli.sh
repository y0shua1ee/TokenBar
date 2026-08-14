#!/usr/bin/env bash
set -euo pipefail

echo "WARN: install-codexbar-cli.sh is retained for compatibility; use install-tokenbar-cli.sh." >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-tokenbar-cli.sh" "$@"
