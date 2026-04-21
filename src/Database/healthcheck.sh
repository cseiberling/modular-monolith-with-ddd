#!/bin/bash
# Healthy when SQL Server accepts sa and the MyMeetings database is online.

set -euo pipefail

SQLCMD=""
for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
  if [[ -x "$candidate" ]]; then
    SQLCMD="$candidate"
    break
  fi
done

[[ -n "$SQLCMD" ]] || exit 1

PASSWORD="${SA_PASSWORD:?}"

extra=()
if [[ "$SQLCMD" == *tools18* ]]; then
  extra+=(-C)
fi

"$SQLCMD" "${extra[@]}" -S localhost -d MyMeetings -U sa -P "$PASSWORD" \
  -Q "SET NOCOUNT ON; SELECT 1" -b -o /dev/null
