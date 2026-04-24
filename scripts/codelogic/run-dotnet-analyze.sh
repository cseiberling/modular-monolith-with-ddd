#!/usr/bin/env bash
# Run the CodeLogic .NET Docker agent the same way as CI: "docker run … image analyze …"
# Do not override ENTRYPOINT — the image wires "analyze" to the real CLI.
#
# Usage:
#   run-dotnet-analyze.sh <host-publish-dir> <container-path-for--p> [host-ref-dotnet-root]
#
# Examples (second arg must NOT be /app — that path is used by the image for entrypoint.sh):
#   ./scripts/codelogic/run-dotnet-analyze.sh ./out /scan
#   ./scripts/codelogic/run-dotnet-analyze.sh "$PWD/out" /github/workspace /usr/share/dotnet
#
# Env (required): CODELOGIC_HOST, AGENT_UUID, AGENT_PASSWORD
# Env (optional): CODELOGIC_DATABASE_IDENTITIES (multiline, one DB identity per line),
#                CODELOGIC_DOTNET_IMAGE

set -euo pipefail

HOST_PUBLISH="${1:?host path to dotnet publish output (e.g. ./out)}"
CONTAINER_SCAN="${2:?path inside container for -p (use /scan or /github/workspace — never /app; image uses /app)}"
HOST_REF_DOTNET="${3:-}"

IMAGE="${CODELOGIC_DOTNET_IMAGE:-thingsboard.app.codelogic.com/codelogic_dotnet:latest}"

if [[ ! -d "$HOST_PUBLISH" ]]; then
  cat >&2 << EOF
publish output directory not found: $HOST_PUBLISH

Docker bind-mounts need a real path on the host (same idea as --ref-path: the folder must exist before docker run).

Create it first, for example:
  docker compose --profile publish run --rm dotnet-publish
  or from the repo root:
  dotnet publish src/CompanyName.MyMeetings.sln -c Release -o out \\
    -p:NuGetAudit=false /p:TreatWarningsAsErrors=false -p:DeployOnBuild=false -p:DeployOnPublish=false

Then set CODELOGIC_PUBLISH_PATH or pass that directory as the first argument.
The scan mounts it at ${CONTAINER_SCAN} inside the agent (e.g. /scan). Do not mount over /app — the image keeps entrypoint.sh there.
EOF
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

set -x
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
    --rescan \
    --expunge-scan-sessions
