# Linked database migration-history reconciliation

Read-only inspection performed 2026-10-22 through `supabase db query --linked`.
No database DDL, data, migration metadata, or secrets were changed.

## Observed state

- `supabase_migrations.schema_migrations` is absent (`to_regclass` returned
  null); the linked CLI migration list is empty.
- The linked database has 34 base tables in `public`.
- `public.family_space` and `public.membership` exist. `family_space.id` is a
  non-null UUID; `membership.space_id` and `membership.user_id` are non-null
  UUIDs.
- Billing tables `public.family_entitlement` and
  `public.billing_purchase_verification` are absent.
- The latest local migration's marker objects exist remotely:
  `can_manage_child_profile(uuid)`, `update_child_profile(...)`, plus the
  three `avatar_owner_{write,update,delete}` storage policies. Their function
  bodies and policy predicates match
  `migrations/046_parent_managed_kid_avatars.sql` on inspection.
- Other recent objects `set_family_month_start(uuid, integer)` and
  `space_role(uuid)` also exist.

## What this establishes (and what it does not)

This is evidence that the remote schema includes objects from local migration
046, and that the billing proposal's referenced family tables/UUID types are
present. It does not prove every earlier migration was applied in order, that
the remote schema has no unrelated/manual changes, or that a migration ledger
was intentionally omitted. Do not infer or fabricate applied migration rows
from the 046 marker objects alone.

## Safe next reconciliation step

Identify the database's deployment history/source of truth with the project
maintainer, then compare each migration's intended objects against live
catalog state before repairing migration tracking. Supabase CLI schema diff
needs a local shadow database (Docker); direct linked SQL can inspect catalog
objects but cannot automatically certify the entire migration chain. Until
that inventory is complete, do not run `migration repair`, promote the billing
proposal to a numbered migration, or apply it to the linked database.
