#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROUP_SIZE="${CODEXBAR_TEST_GROUP_SIZE:-12}"
SUITE_TIMEOUT="${CODEXBAR_TEST_SUITE_TIMEOUT:-180}"

cd "${ROOT_DIR}"
ARGS=(
  --group-size "${GROUP_SIZE}"
  --timeout "${SUITE_TIMEOUT}"
)

DISABLE_SWIFTPM_SANDBOX=${TOKENBAR_SWIFT_TEST_DISABLE_SANDBOX:-}
if [[ -z "${DISABLE_SWIFTPM_SANDBOX}" && "${CODEX_SANDBOX:-}" == "seatbelt" ]]; then
  DISABLE_SWIFTPM_SANDBOX=1
fi
if [[ "${DISABLE_SWIFTPM_SANDBOX}" == "1" ]]; then
  ARGS+=(
    --swift-test-arg=--disable-sandbox
  )
fi

if [[ -n "${CODEXBAR_TEST_SHARD_INDEX:-}" || -n "${CODEXBAR_TEST_SHARD_COUNT:-}" ]]; then
  ARGS+=(
    --shard-index "${CODEXBAR_TEST_SHARD_INDEX:?CODEXBAR_TEST_SHARD_COUNT requires CODEXBAR_TEST_SHARD_INDEX}"
    --shard-count "${CODEXBAR_TEST_SHARD_COUNT:?CODEXBAR_TEST_SHARD_INDEX requires CODEXBAR_TEST_SHARD_COUNT}"
  )
fi

exec python3 "${ROOT_DIR}/Scripts/ci_swift_test_by_suite.py" "${ARGS[@]}" "$@"
