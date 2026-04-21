#!/bin/bash
# Reports healthy when SQL Server accepts logins and the MyMeetings database exists.

set -euo pipefail

SQLCMD=""
for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
  if [[ -x "$candidate" ]]; then
    SQLCMD="$candidate"
    break
  fi
done

if [[ -z "$SQLCMD" ]]; then
  exit 1
fi

PASSWORD="${SA_PASSWORD:?}"

extra=()
if [[ "$SQLCMD" == *tools18* ]]; then
  extra+=(-C)
fi

COUNT="$("$SQLCMD" "${extra[@]}" -S localhost -d master -U sa -P "$PASSWORD" \
  -h-1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) AS c FROM sys.databases WHERE name = N'MyMeetings'" \
  | tail -n 1 | tr -d ' \r')
[[ "${COUNT:-0}" =~ ^[0-9]+$ ]] || exit 1
[[ "$COUNT" -ge 1 ]]
