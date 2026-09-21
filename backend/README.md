# Mhuri Money — Backend (Supabase / PostgreSQL)

Phase-1 backend per **PRODUCT_SPEC.md §8 (Data Model) + §9 (Architecture) + §10 (Security)**.

## Contents

- `schema.sql` — full schema: 20 tables, CHECK-constrained enums, soft-delete
  trash, updated-at trigger, hash-chained activity log, **row-level security**
  for the family role model (owner / adult / teen / kid / viewer), and storage
  bucket stubs for receipts, voice notes and mukando proof photos.

## Setup (10 minutes)

1. Create a project at [supabase.com](https://supabase.com) (region `af-south-1`
   is closest to Zimbabwe).
2. SQL Editor → paste `schema.sql` → **Run**. (Idempotency: run on a fresh
   project; for an existing one, wrap sections in migrations instead.)
3. Auth → Providers → **Phone** (OTP). Add Email as a fallback for the beta.
4. Uncomment the `storage.buckets` insert at the bottom of `schema.sql`.
5. Copy the project URL + anon key into the Flutter app (see *Wiring* below).

## Design decisions (why it looks like this)

| Decision | Reason |
|---|---|
| `bigint` minor units + `currency` everywhere | Never store floats (spec §5.1); conversion is display-only |
| Text + CHECK enums instead of native enums | Cheap, safe migrations as the model evolves in beta |
| `space_role()` SECURITY DEFINER helper | Avoids recursive RLS policy scans on `membership` |
| Soft delete (`transaction.deleted_at`) | 7-day trash + audit trail (spec §3.4) |
| `activity_log` with `prev_hash`/`hash` | Tamper-evident family activity feed; app verifies chain on read |
| Kids see only their own rows (`tx_read`, `req_read`) | Privacy by role enforced **server-side**, not just hidden in UI (spec §10) |
| `rate_snapshot(day, source)` | RBZ daily rate history; monthly reports snapshot month-end rates and never re-value (spec §5.3) |

## Server-side jobs to add next

1. **Daily rate upsert** — Supabase Edge Function (cron): fetch RBZ mid-rate →
   `insert into rate_snapshot (day, source, usd_zwg) values (current_date,'rbz',…)
   on conflict (day, source) do update`.
2. **`log_activity` RPC** — inserts into `activity_log` computing
   `hash = sha256(prev_hash || action || entity_id || detail || at)`.
3. **Trash purge** — scheduled SQL: delete transactions `where deleted_at < now() - interval '7 days'`.
4. **Backup reminder cron** — weekly `pg_dump` to cold storage.

## Wiring the Flutter app (Phase 1, next milestone)

```bash
flutter pub add supabase_flutter drift drift_flutter path_provider \
                flutter_secure_storage sqlite3_flutter_libs
flutter pub add --dev drift_dev build_runner
```

1. Initialise in `main()` with `Supabase.initialize(url: …, anonKey: …)`.
2. Generate the Drift database from `lib/core/db/` (tables mirror `schema.sql`)
   with `dart run build_runner build`.
3. Implement the outbox (spec §9.2): local write → queue →
   `Supabase.rpc('sync_flush', …)` on connectivity; the existing
   `AppState.pendingOps` counter is the UI hook.
4. Turn on `Supabase.initialize` behind a config flag; the in-memory seed stays
   as the offline/demo mode and for widget tests.

## Before public launch (security checklist)

- [ ] Replace the demo `profile_read` policy with a membership-join view.
- [ ] Extend `tx_read` so `account.sharing = 'private'` rows only return to the
      owner (plus a `private_summary` RPC returning totals only).
- [ ] Rate-limit OTP + WhatsApp OTP fallback (spec §14).
- [ ] Signed-URL expiry ≤ 15 min for receipts/voice notes.
- [ ] Zimbabwe Data Protection Act data-subject export/deletion functions.
