#!/usr/bin/env bash
# Local helper: load .env.codelogic and run run-dotnet-analyze.sh (recommended over Compose for this agent).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env.codelogic" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env.codelogic"
  set +a
fi

PUBLISH="${CODELOGIC_PUBLISH_PATH:-$ROOT/out}"
REF="${CODELOGIC_REF_DOTNET_HOST:-}"
if [[ -z "${REF}" && -d /usr/share/dotnet ]]; then
  REF=/usr/share/dotnet
fi

# Mount publish output at /scan — NOT /app (the image uses /app for entrypoint.sh and the agent).
CONTAINER_SCAN="${CODELOGIC_CONTAINER_SCAN_PATH:-/scan}"
exec "$ROOT/scripts/codelogic/run-dotnet-analyze.sh" "$PUBLISH" "${CONTAINER_SCAN}" "${REF}"
