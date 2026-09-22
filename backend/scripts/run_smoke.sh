#!/usr/bin/env bash
# Rebuild a scratch DB from zero (shim + full migration chain) and run the
# 27-check integrity smoke — the same gates CI runs. Needs psql.
#   ./backend/scripts/run_smoke.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
DB="${MHURI_SMOKE_DB:-mhuri_smoke}"
PG="${PGUSER:-postgres}"
psql -q -c "DROP DATABASE IF EXISTS $DB;" "$PG"
psql -q -c "CREATE DATABASE $DB;" "$PG"
psql -q -v ON_ERROR_STOP=1 -d "$DB" -f backend/scripts/supabase_shim.sql
for f in backend/migrations/*.sql; do
  echo "── $f"
  psql -q -v ON_ERROR_STOP=1 -d "$DB" -f "$f"
done
psql -v ON_ERROR_STOP=1 -d "$DB" -f backend/tests/integrity_smoke.sql
