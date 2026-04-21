#!/bin/bash
set -euo pipefail

resolve_sqlcmd() {
  local candidate
  for candidate in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
    if [[ -x "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

SQLCMD="$(resolve_sqlcmd)" || {
  echo "ERROR: sqlcmd not found (looked under /opt/mssql-tools18 and /opt/mssql-tools)."
  exit 1
}

PASSWORD="${SA_PASSWORD:?}"

sqlcmd_extra=()
if [[ "$SQLCMD" == *tools18* ]]; then
  sqlcmd_extra+=(-C)
fi

echo 'Starting SQL Server...'
/opt/mssql/bin/sqlservr &

echo 'Waiting for SQL Server to accept connections...'
for _ in $(seq 1 90); do
  if "$SQLCMD" "${sqlcmd_extra[@]}" -S localhost -d master -U sa -P "$PASSWORD" \
    -Q "SELECT 1" -b -o /dev/null 2>/dev/null; then
    echo 'SQL Server is ready.'
    break
  fi
  sleep 1
done

echo 'Creating database (if needed)...'
"$SQLCMD" "${sqlcmd_extra[@]}" -S localhost -d master -i /scripts/CreateDatabase_Linux.sql \
  -U sa -P "$PASSWORD" -b

echo 'Database setup finished.'

exec tail -f /dev/null
