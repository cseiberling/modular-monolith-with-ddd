#!/usr/bin/env bash
# Run the CodeLogic .NET Docker agent the same way as CI: "docker run … image analyze …"
# Do not override ENTRYPOINT — the image wires "analyze" to the real CLI.
#
# Usage:
#   run-dotnet-analyze.sh <host-publish-dir> <container-path-for--p> [host-ref-dotnet-root]
#
# Examples:
#   ./scripts/codelogic/run-dotnet-analyze.sh ./artifacts/out /app
#   ./scripts/codelogic/run-dotnet-analyze.sh "$PWD/artifacts/out" /app /usr/share/dotnet
#
# Env (required): CODELOGIC_HOST, AGENT_UUID, AGENT_PASSWORD
# Env (optional): CODELOGIC_DATABASE_IDENTITIES (multiline, one DB identity per line),
#                CODELOGIC_DOTNET_IMAGE

set -euo pipefail

HOST_PUBLISH="${1:?host path to dotnet publish output (e.g. ./artifacts/out)}"
CONTAINER_SCAN="${2:?path inside container for -p, e.g. /app or /github/workspace}"
HOST_REF_DOTNET="${3:-}"

IMAGE="${CODELOGIC_DOTNET_IMAGE:-thingsboard.app.codelogic.com/codelogic_dotnet:latest}"

if [[ ! -d "$HOST_PUBLISH" ]]; then
  echo "publish output directory not found: $HOST_PUBLISH" >&2
  exit 1
fi
HOST_PUBLISH="$(cd "$HOST_PUBLISH" && pwd)"

declare -a RUN=(docker run --pull always --rm
  -e CODELOGIC_HOST
  -e AGENT_UUID
  -e AGENT_PASSWORD
  -v "${HOST_PUBLISH}:${CONTAINER_SCAN}:ro"
)

if [[ -n "${HOST_REF_DOTNET}" && -d "${HOST_REF_DOTNET}" ]]; then
  RUN+=(-v "${HOST_REF_DOTNET}:/ref-dotnet:ro")
fi

declare -a DB_ARGS=()
if [[ -n "${CODELOGIC_DATABASE_IDENTITIES:-}" ]]; then
  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line//$'\r'/}"
    [[ -z "${line// }" ]] && continue
    DB_ARGS+=( -d "${line}" )
  done <<< "${CODELOGIC_DATABASE_IDENTITIES}"
fi

declare -a REF_ARGS=()
if [[ -n "${HOST_REF_DOTNET}" && -d "${HOST_REF_DOTNET}" ]]; then
  REF_ARGS+=(
    --ref-path /ref-dotnet/shared/Microsoft.NETCore.App
    --ref-path /ref-dotnet/shared/Microsoft.AspNetCore.App
  )
fi

APP="${CODELOGIC_APPLICATION:-ModularMonolith}"
SPACE="${CODELOGIC_SCAN_SPACE:-ModularMonolith}"

exec "${RUN[@]}" "${IMAGE}" \
  analyze -p "${CONTAINER_SCAN}" \
    -a "${APP}" \
    -s "${SPACE}" \
    -f CompanyName.MyMeetings. \
    -f CompanyNames.MyMeetings. \
    -f DatabaseMigrator. \
    -m CompanyName.MyMeetings. \
    -m CompanyNames.MyMeetings. \
    -m DatabaseMigrator. \
    "${DB_ARGS[@]}" \
    "${REF_ARGS[@]}" \
    --expunge-scan-sessions
