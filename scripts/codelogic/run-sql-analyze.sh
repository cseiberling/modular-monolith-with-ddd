#!/usr/bin/env bash
# Run CodeLogic SQL agent without overriding ENTRYPOINT (same pattern as the .NET runner).
#
# CodeLogic SQL agent vs .NET agent (only these may differ between installers):
#   CODELOGIC_SQL_HOST, CODELOGIC_SQL_AGENT_UUID, CODELOGIC_SQL_AGENT_PASSWORD
# If empty, the script reuses CODELOGIC_HOST, AGENT_UUID, AGENT_PASSWORD from the .NET block.
#
# Database connection for "analyze -c" / "-u" / "-pwd" (SQL Server user being scanned):
#   CODELOGIC_SQL_JDBC_URL, CODELOGIC_SQL_USER, CODELOGIC_SQL_PASSWORD

set -euo pipefail

IMAGE="${CODELOGIC_SQL_IMAGE:-thingsboard.app.codelogic.com/codelogic_sql:latest}"
JDBC_URL="${CODELOGIC_SQL_JDBC_URL:?Set CODELOGIC_SQL_JDBC_URL}"

EFFECTIVE_HOST="${CODELOGIC_SQL_HOST:-${CODELOGIC_HOST:?Set CODELOGIC_HOST or CODELOGIC_SQL_HOST}}"
EFFECTIVE_UUID="${CODELOGIC_SQL_AGENT_UUID:-${AGENT_UUID:?Set AGENT_UUID or CODELOGIC_SQL_AGENT_UUID}}"
EFFECTIVE_AGENT_PWD="${CODELOGIC_SQL_AGENT_PASSWORD:-${AGENT_PASSWORD:?Set AGENT_PASSWORD or CODELOGIC_SQL_AGENT_PASSWORD}}"

declare -a RUN=(docker run --pull always --rm
  -e "CODELOGIC_HOST=${EFFECTIVE_HOST}"
  -e "AGENT_UUID=${EFFECTIVE_UUID}"
  -e "AGENT_PASSWORD=${EFFECTIVE_AGENT_PWD}"
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
