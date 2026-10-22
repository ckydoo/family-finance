# Mhuri Money - Backend (Supabase / PostgreSQL)

Phase-1 backend per **PRODUCT_SPEC.md §8 (Data Model) + §9 (Architecture) + §10 (Security)**.

## Contents

- `schema.sql` - full schema: 20 tables, CHECK-constrained enums, soft-delete
  trash, updated-at trigger, hash-chained activity log, **row-level security**
  for the family role model (owner / adult / teen / kid / viewer), and storage
  bucket stubs for receipts, voice notes and mukando proof photos.

## Setup (10 minutes)

1. Create a project at [supabase.com](https://supabase.com) (region `af-south-1`
   is closest to Zimbabwe).
2. SQL Editor → run the migration chain IN ORDER: `migrations/000_baseline.sql`,
   then every numbered migration through `016`. Each file is a single
   paste-and-run. (schema.sql is a
   human-readable reference of the end state - do NOT run it against the
   database.) CI applies the same chain to a clean Postgres on every push.
3. Auth → Providers → **Email** (email + password; no phone OTP).
4. Storage → the `avatars` bucket is created by migration 005.
5. Copy the project URL + anon key into the Flutter app (see *Wiring* below).

### Assisted member accounts

The app's existing QR/code invitation remains the default. Owners and parents
also have a separate **Create account for member** action backed by the
`create-family-member` Edge Function. Deploy it to each environment:

```bash
supabase functions deploy create-family-member
```

Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` to deployed
functions. Never copy the service-role key into `app/.env`: Flutter contains
only the project URL and anon key. The function validates the caller's access
token and active family role before using the admin API. Only owners may grant
adult/parent roles; parents may provision teen, child, or viewer accounts.

## Design decisions (why it looks like this)

| Decision | Reason |
|---|---|
| `bigint` minor units + `currency` everywhere | Never store floats (spec §5.1); conversion is display-only |
| Text + CHECK enums instead of native enums | Cheap, safe migrations as the model evolves in beta |
| `space_role()` SECURITY DEFINER helper | Avoids recursive RLS policy scans on `membership` |
| Soft delete (`transaction.deleted_at`) | 7-day trash + audit trail (spec §3.4) |
| `activity_log` with `prev_hash`/`hash` | Audit trail of family events (create/join/leave + money moves as they get wired). Columns exist for hash-chaining, but rows are appended, not yet chained or verified - do not claim tamper-evidence until that ships |
| Kids see only their own rows (`tx_read`, `req_read`) | Privacy by role enforced **server-side**, not just hidden in UI (spec §10) |
| `rate_snapshot(day, source)` | RBZ daily rate history; monthly reports snapshot month-end rates and never re-value (spec §5.3) |

## Server-side jobs to add next

1. **Daily rate upsert** - Supabase Edge Function (cron): fetch RBZ mid-rate →
   `insert into rate_snapshot (day, source, usd_zwg) values (current_date,'rbz',…)
   on conflict (day, source) do update`.
2. **`log_activity` RPC** - inserts into `activity_log` computing
   `hash = sha256(prev_hash || action || entity_id || detail || at)`.
3. **Trash purge** - scheduled SQL: delete transactions `where deleted_at < now() - interval '7 days'`.
4. **Backup reminder cron** - weekly `pg_dump` to cold storage.

## Plus billing foundation (not enabled)

The Phase 1 billing work is intentionally fail-closed and is not ready for
deployment or purchase activation. The reviewed schema is now in
`migrations/047_family_entitlements.sql`; it is not applied to the linked
project yet. The live project's migration ledger is absent, so reconcile the
deployment history and repair tracking only from verified records before
applying migration 047. Do not fabricate migration history.

The `verify-family-entitlement` Edge Function verifies the caller and active
family membership, then reads the server-owned family entitlement. When
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `MHURI_ANDROID_PACKAGE_NAME`, and the
monthly/annual product ID secrets are set, it verifies posted purchase tokens
through the Google Play Publisher API and stores only a SHA-256 token hash.
Without those secrets it fails closed. `google-play-rtdn` handles subscription
lifecycle events: it verifies Google's Pub/Sub OIDC identity, then re-queries
Play before updating entitlements. Its `verify_jwt = false` setting is scoped
to that endpoint only; configure the Pub/Sub push OIDC service account and
audience to exactly match `GOOGLE_PLAY_PUBSUB_SERVICE_ACCOUNT` and
`GOOGLE_PLAY_RTDN_AUDIENCE` before deploying it. Required function secrets are
`GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `MHURI_ANDROID_PACKAGE_NAME`,
`GOOGLE_PLAY_MONTHLY_PRODUCT_ID`, `GOOGLE_PLAY_ANNUAL_PRODUCT_ID`,
`GOOGLE_PLAY_PUBSUB_SERVICE_ACCOUNT`, and `GOOGLE_PLAY_RTDN_AUDIENCE`.

Flutter's `MHURI_BILLING_ENABLED` define defaults to false; keep it false
until production product/store configuration, RTDN delivery, legal/store
setup, and end-to-end tests are ready.

### Plus feature access

Migration `048_plus_chat_tools.sql` adds family-scoped polls, votes, pins, and
an advanced-search RPC. Poll creation, new pins, and advanced search are
server-checked against the active family entitlement; voting on an existing
open poll and removing pins remain available after downgrade. Existing text
chat, basic search, reports, CSV exports, and savings goals stay Free. Migration
048 has been applied directly to the linked project; because the remote
migration ledger is absent, no history row was fabricated and reconciliation
is still needed before future CLI-managed migrations.

The current Plus UI also adds a 30-day observed cash-flow estimate, category
comparisons, and savings-goal completion estimates based on recent
contributions. They are estimates, explicitly labeled as such, and are shown
only when the server-verified feature keys are present.

## Flutter Plus experience

Settings now opens a family-scoped Plus page with Google Play plan pricing,
purchase, restore, and server-refreshed entitlement status. Purchases remain
disabled unless the Android build explicitly sets
`--dart-define=MHURI_BILLING_ENABLED=true`; do not enable that define until the
schema migration is reconciled and applied, Google Play products and publisher
credentials are configured, RTDN is deployed, and an end-to-end Play test has
verified purchase, renewal, cancellation, expiry, and restore. Product IDs can
be overridden using `MHURI_PLUS_MONTHLY_PRODUCT_ID` and
`MHURI_PLUS_ANNUAL_PRODUCT_ID` build defines and must match the server-side
monthly/annual product ID secrets exactly.

## Before public launch (security checklist)

- [ ] Replace the demo `profile_read` policy with a membership-join view.
- [ ] Extend `tx_read` so `account.sharing = 'private'` rows only return to the
      owner (plus a `private_summary` RPC returning totals only).
- [ ] Rate-limit OTP + WhatsApp OTP fallback (spec §14).
- [ ] Signed-URL expiry ≤ 15 min for receipts/voice notes.
- [ ] Zimbabwe Data Protection Act data-subject export/deletion functions.
