# Linked Supabase live-schema audit

Audit date: 2026-10-22 (Africa/Harare)

## Method and safety

Inspected the linked project with read-only `supabase db query --linked`
catalog queries. No Docker, `pg_dump`, migration repair, DDL, data writes, or
secret writes were used. One aggregate query counted duplicate envelope
groups; no row contents were retrieved. The schema snapshot used for the
column comparison is `supabase/db_schema.sql`, cross-checked against later
local migrations where that snapshot is stale.

## Summary

The live schema substantially matches the app’s local migration chain, but it
is not an exact migration-chain state. Two important differences need review:

1. The unique index from migration 015, `envelope_space_name_unique`, is
   missing. There are currently zero duplicate active shared-envelope groups,
   but concurrent duplicate creation is not prevented by the database.
2. An extra `activity_log.important-family-push` trigger is not in the local
   migrations. It issues an extra HTTP request to the same family-push Edge
   Function used by migration-managed `trg_activity_push`. Its configured
   request body is empty, so the current function appears to ignore that
   request rather than send a duplicate notification. Its stored definition
   nevertheless contains a literal webhook credential. Treat that credential
   as exposed: rotate it and remove/replace the extra trigger after confirming
   ownership and intended behavior. The credential value is deliberately
   omitted here.

These differences, plus the missing migration ledger, mean migration history
must not be stamped as fully applied based on this audit alone.

## Catalog comparison

| Area | Live result | Comparison |
|---|---|---|
| Public app tables | 34 | Exact table-name set declared by local migrations 000–046 |
| Columns | Names, types, and nullability match the migration chain | `supabase/db_schema.sql` is stale: it has 33 tables and omits `mukando_payment`, `mukando.participant_ids`, chat reply columns from 040, and `edited_at` from 041; those expected migration additions are present live |
| RLS | Enabled on all 34 public app tables | No public app table is missing RLS |
| Public RLS policies | 77 | Names match the local migration chain; all seven expected storage policies are also present |
| Constraints | 209 total: 83 checks, 84 foreign keys, 34 primary keys, 8 unique | All are validated; none are marked `NOT VALID` |
| Public indexes | 59 | All are valid and ready; explicit local index `envelope_space_name_unique` is the one missing index |
| Functions | 62 signatures, including overloads | Migration-defined app functions are present (the migration-004 helper is intentionally dropped); extra `rls_auto_enable()` is present |
| Public triggers | 61 | All 60 expected migration-created triggers are present; `activity_log.important-family-push` is the extra trigger |
| Billing schema | No entitlement or purchase-verification tables | Billing proposal remains unapplied |
| Migration ledger | `supabase_migrations.schema_migrations` is absent | CLI migration history is empty; applied order cannot be proven |

## Additional remote-only object

The database has an enabled event trigger named `ensure_rls`, backed by
`public.rls_auto_enable()`. It automatically enables RLS on newly created
public tables. The function is `SECURITY DEFINER`, has no normal table-trigger
bindings, and has execute grants for `anon` and `authenticated`; direct calls
are not the event-trigger path. This behavior is not represented in local
migrations and should be documented/owned by the project maintainer before
any migration-history repair.

## Recommended remediation order

1. Rotate the webhook credential that is embedded in the extra trigger.
2. Confirm whether the extra push trigger is intentional; if not, remove it
   through an owner-approved migration after checking push delivery behavior.
3. Restore the missing envelope uniqueness guard in a reviewed migration. The
   current duplicate-group count is zero, but recheck immediately before
   creating the unique index.
4. Identify the trusted migration-history source and reconcile every migration
   before creating or repairing the migration ledger. Do not bulk-mark 000–046
   applied solely because the table/column inventory matches.
5. Only then promote/apply the family-entitlement proposal. Google Play and
   RTDN secrets are also still absent, so purchases must remain disabled.

This audit is a live catalog comparison, not an execution of all 47 migration
files against a disposable shadow database. It establishes object inventory,
column shapes, RLS coverage, constraint/index health, and identified drift; it
does not certify every check-expression or policy predicate byte-for-byte.
