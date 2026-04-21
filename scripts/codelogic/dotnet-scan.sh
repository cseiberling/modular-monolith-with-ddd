#!/usr/bin/env bash
# Called inside the CodeLogic .NET agent container. Published binaries are mounted at /app.
set -euo pipefail

declare -a ARGS=(
  analyze
  -p /app
  -a "${CODELOGIC_APPLICATION:-ModularMonolith}"
  -s "${CODELOGIC_SCAN_SPACE:-ModularMonolith}"
  -f CompanyName.MyMeetings.
  -f CompanyNames.MyMeetings.
  -f DatabaseMigrator.
  -m CompanyName.MyMeetings.
  -m CompanyNames.MyMeetings.
  -m DatabaseMigrator.
)

# One identity per line (from CodeLogic UI → NodeDetails). Improves DB relationship mapping.
if [[ -n "${CODELOGIC_DATABASE_IDENTITIES:-}" ]]; then
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line//$'\r'/}"
    [[ -z "${line// }" ]] && continue
    ARGS+=( -d "$line" )
  done <<< "${CODELOGIC_DATABASE_IDENTITIES}"
fi

if [[ -d /ref-dotnet/shared/Microsoft.NETCore.App ]]; then
  ARGS+=( --ref-path /ref-dotnet/shared/Microsoft.NETCore.App )
fi
if [[ -d /ref-dotnet/shared/Microsoft.AspNetCore.App ]]; then
  ARGS+=( --ref-path /ref-dotnet/shared/Microsoft.AspNetCore.App )
fi

if [[ "${CODELOGIC_EXPUNGE_SCAN_SESSIONS:-1}" == "1" ]]; then
  ARGS+=( --expunge-scan-sessions )
fi

exec "${ARGS[@]}"
