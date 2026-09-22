#!/usr/bin/env bash
# Mhuri Hub — database backup export (roadmap #20).
# Run on YOUR machine: either logged-in Supabase CLI, or DATABASE_URL set
# (Supabase dashboard → Connect → connection string / pooler).
# NEVER commit the dump or the connection string.
set -euo pipefail
: "${MHURI_BACKUP_DIR:=$HOME/mhuri-backups}"
mkdir -p "$MHURI_BACKUP_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)

if command -v supabase >/dev/null 2>&1 && [ -n "${SUPABASE_PROJECT_REF:-}" ]; then
  echo "── dumping via Supabase CLI (project $SUPABASE_PROJECT_REF)"
  supabase db dump --project-ref "$SUPABASE_PROJECT_REF" \
    --file "$MHURI_BACKUP_DIR/mhuri-data-$STAMP.sql"
  supabase db dump --project-ref "$SUPABASE_PROJECT_REF" --role-only \
    --file "$MHURI_BACKUP_DIR/mhuri-roles-$STAMP.sql"
else
  : "${DATABASE_URL:?set DATABASE_URL=\"postgresql://…\" (Supabase → Connect), or install the Supabase CLI and set SUPABASE_PROJECT_REF}"
  echo "── dumping via pg_dump"
  pg_dump --no-owner --clean --if-exists "$DATABASE_URL" \
    > "$MHURI_BACKUP_DIR/mhuri-data-$STAMP.sql"
fi

echo "✅ backup: $MHURI_BACKUP_DIR/mhuri-data-$STAMP.sql"
echo "Next: keep at least 4 weekly dumps; run the restore drill in"
echo "backend/BACKUP_RESTORE.md against a scratch project once."
