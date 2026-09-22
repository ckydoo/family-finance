# Backups & restore drill (roadmap #20)

State of the family's data lives in exactly three places: the Supabase
Postgres project, avatar files in Supabase Storage, and each device's local
Drift cache (regenerable — never backed up). Only the first two need backups.

## 1. Enable the safety nets (dashboard, one-time — YOUR action)

1. **PITR** (point-in-time recovery): Project → *Database → Backups*. On the
   Pro plan this restores to any minute in the last 7 days. If PITR is not
   available on the plan, the weekly dumps in §2 are the fallback — do not
   skip them.
2. **Weekly logical dumps**: run `backend/scripts/backup.sh` (Supabase CLI or
   `pg_dump` + `DATABASE_URL`) at least weekly — e.g. a phone reminder or
   cron: `0 19 * * 0 $HOME/mhuri-money/backend/scripts/backup.sh`. Keep ≥ 4
   dumps. Dumps contain financial rows — store them encrypted (encrypted
   disk/container), never in the repo, never in chat.

## 2. Restore drill — execute ONCE, note the date here

A backup that has never been restored is a hope, not a backup. Drill:

1. Create a **scratch Supabase project** (never the production one).
2. Restore the newest dump into it:
   `psql "$SCRATCH_CONNECTION_STRING" -f mhuri-data-YYYYMMDD-HHMMSS.sql`
   (with a CLI roles dump: apply `mhuri-roles-*.sql` first).
3. Verify the restored project with the repo's own gates:
   - `./backend/scripts/run_smoke.sh` (rebuilds from zero and runs
     `backend/tests/integrity_smoke.sql`) → expect **27/27 PASS**
     (the same suite that gates CI proves RLS, deletion rules and RPCs on
     the restored data).
   - Spot-check counts: `select count(*) from space;` and one real family's
     envelope/transaction counts match production.
   - Point a dev build at the scratch project:
     `cp app/.env.example app/.env`, set its `SUPABASE_URL`/`SUPABASE_ANON_KEY`
     to the scratch project's, `ENV=dev`, `flutter run` — log in with a real
     account and confirm budgets/lists render.
4. Destroy the scratch project. Record below.

| Drill date | Dump used | Smoke result | Verified by |
|---|---|---|---|
| _date_ | _file_ | _/27_ | _initials_ |

## 3. What is NOT backed up (by design)

- Device-local Drift caches — rebuilt by full sync from the server.
- Auth passwords — Supabase-managed hashes; users reset via the recovery
  email flow (#1).
- `.env` / tokens — re-entered by hand; that is why they are gitignored.

## 4. Deletion vs backups

Account deletion (007/008 RPCs) removes identity + personal rows in the
**production** database. Existing dumps still contain pre-deletion rows —
acceptable for family-scale use because dumps are encrypted and private;
the privacy policy's deletion promise applies to the live service. When a
dump ages past the retention window, delete the file.
