#!/usr/bin/env bash
# Load .env.codelogic and run run-sql-analyze.sh (agent must reach DB host, e.g. mymeetingsdb on compose network).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/.env.codelogic" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$ROOT/.env.codelogic"
  set +a
fi

exec "$ROOT/scripts/codelogic/run-sql-analyze.sh"
