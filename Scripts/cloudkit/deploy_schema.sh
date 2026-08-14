#!/usr/bin/env bash
# Deploys the TokenBar CloudKit schema (Scripts/cloudkit/schema.ckdb).
#
# Requires a CloudKit management token (create one at
# https://icloud.developer.apple.com/dashboard → account menu → Tokens,
# or via `xcrun cktool save-token`). Pass it via CLOUDKIT_MANAGEMENT_TOKEN
# or save it first with `xcrun cktool save-token`.
#
# Usage: Scripts/cloudkit/deploy_schema.sh [development|production]
set -euo pipefail

ENVIRONMENT="${1:-development}"
case "$ENVIRONMENT" in
  development|production) ;;
  *) echo "ERROR: environment must be development or production" >&2; exit 1 ;;
esac

TEAM_ID="${TOKENBAR_CLOUDKIT_TEAM_ID:-}"
CONTAINER_ID="${TOKENBAR_CLOUDKIT_CONTAINER:-}"
EXPECTED_CONTAINER_ID="iCloud.com.y0shua1ee.tokenbar"
SCHEMA_FILE="$(cd "$(dirname "$0")" && pwd)/schema.ckdb"

if [[ -z "$TEAM_ID" || -z "$CONTAINER_ID" ]]; then
  echo "ERROR: TokenBar CloudKit deployment is disabled until TokenBar owns an Apple team and container." >&2
  echo "Set TOKENBAR_CLOUDKIT_TEAM_ID and TOKENBAR_CLOUDKIT_CONTAINER explicitly after provisioning." >&2
  exit 1
fi
if [[ "$CONTAINER_ID" != "$EXPECTED_CONTAINER_ID" ]]; then
  echo "ERROR: Refusing to deploy TokenBar schema to unexpected container: $CONTAINER_ID" >&2
  echo "Expected TOKENBAR_CLOUDKIT_CONTAINER=$EXPECTED_CONTAINER_ID" >&2
  exit 1
fi

TOKEN_ARGS=()
if [[ -n "${CLOUDKIT_MANAGEMENT_TOKEN:-}" ]]; then
  TOKEN_ARGS=(--token "$CLOUDKIT_MANAGEMENT_TOKEN")
fi

echo "Validating schema against $ENVIRONMENT..."
xcrun cktool validate-schema ${TOKEN_ARGS[@]+"${TOKEN_ARGS[@]}"} \
  --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" --file "$SCHEMA_FILE"

echo "Importing schema into $ENVIRONMENT..."
xcrun cktool import-schema ${TOKEN_ARGS[@]+"${TOKEN_ARGS[@]}"} \
  --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT" --file "$SCHEMA_FILE"

echo "Done. Current $ENVIRONMENT schema:"
xcrun cktool export-schema ${TOKEN_ARGS[@]+"${TOKEN_ARGS[@]}"} \
  --team-id "$TEAM_ID" --container-id "$CONTAINER_ID" \
  --environment "$ENVIRONMENT"
