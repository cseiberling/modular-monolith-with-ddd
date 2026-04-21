#!/usr/bin/env bash
# Run CodeLogic SQL agent without overriding ENTRYPOINT (same pattern as the .NET runner).
#
# Required env: CODELOGIC_HOST, AGENT_UUID, AGENT_PASSWORD, CODELOGIC_SQL_JDBC_URL
# Optional: CODELOGIC_APPLICATION, CODELOGIC_SQL_SCAN_SPACE, CODELOGIC_SQL_USER, CODELOGIC_SQL_PASSWORD,
#           CODELOGIC_SQL_IMAGE, CODELOGIC_SQL_EXPUNGE_SCAN_SESSIONS

set -euo pipefail

IMAGE="${CODELOGIC_SQL_IMAGE:-thingsboard.app.codelogic.com/codelogic_sql:latest}"
JDBC_URL="${CODELOGIC_SQL_JDBC_URL:?Set CODELOGIC_SQL_JDBC_URL}"

declare -a RUN=(docker run --pull always --rm
  -e CODELOGIC_HOST
  -e AGENT_UUID
  -e AGENT_PASSWORD
)

if [[ -n "${CODELOGIC_DOCKER_NETWORK:-}" ]]; then
  RUN+=( --network "${CODELOGIC_DOCKER_NETWORK}" )
fi

declare -a CMD=(
  analyze
  -c "${JDBC_URL}"
  -a "${CODELOGIC_APPLICATION:-ModularMonolith}"
  -s "${CODELOGIC_SQL_SCAN_SPACE:-ModularMonolith-sql}"
)

if [[ -n "${CODELOGIC_SQL_USER:-}" ]]; then
  CMD+=( -u "${CODELOGIC_SQL_USER}" )
fi
if [[ -n "${CODELOGIC_SQL_PASSWORD:-}" ]]; then
  CMD+=( -pwd "${CODELOGIC_SQL_PASSWORD}" )
fi
if [[ "${CODELOGIC_SQL_EXPUNGE_SCAN_SESSIONS:-0}" == "1" ]]; then
  CMD+=( --expunge-scan-sessions )
fi

exec "${RUN[@]}" "${IMAGE}" "${CMD[@]}"
