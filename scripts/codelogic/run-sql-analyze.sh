#!/usr/bin/env bash
# Run CodeLogic SQL agent without overriding ENTRYPOINT (same pattern as the .NET runner).
#
# CodeLogic server: always CODELOGIC_HOST (same host for .NET and SQL).
# SQL agent credentials (if your SQL installer differs from the .NET installer):
#   CODELOGIC_SQL_AGENT_UUID, CODELOGIC_SQL_AGENT_PASSWORD — if empty, reuse AGENT_UUID / AGENT_PASSWORD.
# Scan space: use CODELOGIC_SCAN_SPACE (same as .NET) so app + DB scans land in one place.
# Optional: CODELOGIC_SQL_FORCE_REGISTRATION=1 to run "agent-register -f" before "analyze" (stuck registration).
# Database: CODELOGIC_SQL_JDBC_URL, CODELOGIC_SQL_USER, CODELOGIC_SQL_PASSWORD

set -euo pipefail

IMAGE="${CODELOGIC_SQL_IMAGE:-thingsboard.app.codelogic.com/codelogic_sql:latest}"
JDBC_URL="${CODELOGIC_SQL_JDBC_URL:?Set CODELOGIC_SQL_JDBC_URL}"
HOST="${CODELOGIC_HOST:?Set CODELOGIC_HOST}"
EFFECTIVE_UUID="${CODELOGIC_SQL_AGENT_UUID:-${AGENT_UUID:?Set AGENT_UUID or CODELOGIC_SQL_AGENT_UUID}}"
EFFECTIVE_AGENT_PWD="${CODELOGIC_SQL_AGENT_PASSWORD:-${AGENT_PASSWORD:?Set AGENT_PASSWORD or CODELOGIC_SQL_AGENT_PASSWORD}}"

APP="${CODELOGIC_APPLICATION:-ModularMonolith}"
SCAN_SPACE="${CODELOGIC_SCAN_SPACE:-ModularMonolith}"

declare -a RUN=(docker run --pull always --rm
  -e "CODELOGIC_HOST=${HOST}"
  -e "AGENT_UUID=${EFFECTIVE_UUID}"
  -e "AGENT_PASSWORD=${EFFECTIVE_AGENT_PWD}"
)

if [[ -n "${CODELOGIC_DOCKER_NETWORK:-}" ]]; then
  RUN+=( --network "${CODELOGIC_DOCKER_NETWORK}" )
fi

force_reg() {
  case "${CODELOGIC_SQL_FORCE_REGISTRATION:-0}" in
    1|true|True|yes|Yes) return 0 ;;
    *) return 1 ;;
  esac
}

if force_reg; then
  echo "Running agent-register -f (CODELOGIC_SQL_FORCE_REGISTRATION is set)..." >&2
  "${RUN[@]}" "${IMAGE}" agent-register -f
fi

declare -a CMD=(
  analyze
  -c "${JDBC_URL}"
  -a "${APP}"
  -s "${SCAN_SPACE}"
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
