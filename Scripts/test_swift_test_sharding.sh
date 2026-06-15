#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/tokenbar-test-sharding.XXXXXX")"
trap 'rm -rf "${TEMP_DIR}"' EXIT

mkdir -p "${TEMP_DIR}/bin"
cat > "${TEMP_DIR}/bin/swift" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "${FAKE_SWIFT_LOG}"
if [[ "$*" == "test list" ]]; then
  printf '%s\n' \
    "TokenBarTests.Alpha/test_one()" \
    "TokenBarTests.Alpha/test_two(argument:)" \
    "TokenBarTests.Beta/test_two" \
    'TokenBarTests.`top level works`()' \
    'TokenBarTests.`top/level slash works`()'
  exit 0
fi
if [[ "$*" == *"|"* ]]; then
  group_runs="$(grep -c '|' "${FAKE_SWIFT_LOG}")"
  if [[ "${FAKE_SWIFT_GROUP_ALWAYS_FAIL:-0}" == "1" || "${group_runs}" -eq 1 ]]; then
    exit 1
  fi
fi
EOF
chmod +x "${TEMP_DIR}/bin/swift"

export PATH="${TEMP_DIR}/bin:${PATH}"
export FAKE_SWIFT_LOG="${TEMP_DIR}/swift.log"

python3 "${ROOT_DIR}/Scripts/ci_swift_test_by_suite.py" --group-size 4 --timeout 10 \
  >"${TEMP_DIR}/retry.log"
grep -Fq "failed with exit code 1; retrying shard once" "${TEMP_DIR}/retry.log"
grep -Fq "TokenBarTests\\.Alpha" "${FAKE_SWIFT_LOG}"
grep -Fq "TokenBarTests\\.Beta" "${FAKE_SWIFT_LOG}"
grep -Fq "TokenBarTests\\..*top\\ level\\ works" "${FAKE_SWIFT_LOG}"
grep -Fq "TokenBarTests\\..*top/level\\ slash\\ works" "${FAKE_SWIFT_LOG}"
[[ "$(wc -l < "${FAKE_SWIFT_LOG}")" -eq 3 ]]

if FAKE_SWIFT_GROUP_ALWAYS_FAIL=1 \
  python3 "${ROOT_DIR}/Scripts/ci_swift_test_by_suite.py" --group-size 4 --timeout 10 \
    >"${TEMP_DIR}/failure.log" 2>&1; then
  echo "ERROR: Repeated shard failure was masked." >&2
  exit 1
fi

echo "Swift test sharding tests passed."
