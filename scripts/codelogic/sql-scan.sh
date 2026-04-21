#!/usr/bin/env bash
# Runs inside the CodeLogic SQL agent container (image: codelogic_sql).
# For SQL Server, put databaseName in the JDBC URL; -d is for Oracle only.
set -euo pipefail

JDBC_URL="${CODELOGIC_SQL_JDBC_URL:?Set CODELOGIC_SQL_JDBC_URL (e.g. jdbc:sqlserver://mymeetingsdb:1433;databaseName=MyMeetings;encrypt=false;trustServerCertificate=true)}"

declare -a ARGS=(
  analyze
  -c "$JDBC_URL"
  -a "${CODELOGIC_APPLICATION:-ModularMonolith}"
  -s "${CODELOGIC_SQL_SCAN_SPACE:-ModularMonolith-sql}"
)

if [[ -n "${CODELOGIC_SQL_USER:-}" ]]; then
  ARGS+=( -u "$CODELOGIC_SQL_USER" )
fi
if [[ -n "${CODELOGIC_SQL_PASSWORD:-}" ]]; then
  ARGS+=( -pwd "$CODELOGIC_SQL_PASSWORD" )
fi

if [[ "${CODELOGIC_SQL_EXPUNGE_SCAN_SESSIONS:-0}" == "1" ]]; then
  ARGS+=( --expunge-scan-sessions )
fi

exec "${ARGS[@]}"
