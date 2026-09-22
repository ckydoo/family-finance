# Seamless end-to-end audit — real user, real DB (2026-09-22)
NO CODE CHANGES YET. This is the gap map for "a normal user, beginnning to
end, no demos, no mocks" — device-tested against the live schema
(supabase_live_schema.sql) and the current boot path.

## Verdict
Single-device, single-user: the flow is already real (auth → family setup →
empty app → real entries → server pull). The seams are all in
**multi-user identity** and **cross-device completeness**. Ranked:

## 🔴 Sprint A — identity seam — ✅ DONE (2026-09-22)
1. **member_id FK breaks every push.** Live `transaction.member_id` (and
   goal_tx/list_item/kid_request/earning/created_by) FK→user_profile(id).
   The app pushes LOCAL uuids → server rejects. DONE — `onSpaceAdopted` now ids the owner as `auth.session.userId` (+newUuid fallback for tests). Proven in live_boot_test.
2. **No member pull.** Pull fetches no `user_profile` rows, so a second
   family member's transactions can't resolve to a name locally. DONE — `_pullMembers()` after every full sync: membership + user_profile pull (RLS `membership_read`/`profile_read`) → `membersFromServer` mapper (co_parent→adult, email-prefix names, me-first) → `setFamilyMembers` merge (local renames win, 'Member' guard, me binding, members_v1 persisted).
3. **Join path doesn't learn the family name.** `join_space` returns only
   the id; nothing pulls `family_space.name` → app shows "My family" until
   a future pull adds it. DONE — `_adoptSpace` fetches `family_space.name` when null (join path) via new `eqFilters` on pullRows; `adoptSpaceName` updates UI + kv.

## 🟠 Sprint B — cross-device completeness — ✅ DONE (2026-09-22)
4. DONE — tx pushes now piggyback `envelope_tx` rows; `_fullSync` pulls the junction (envelope-scoped) and mirrors links into local txs (`applyEnvelopeLinks`, persisted, no re-queue).
5. DONE — `_pullRate` fetches the newest snapshot every full sync; precedence user-custom > server snapshot > default; persisted kv `server_rate`; boot hydrates it.
6. Accounts intentionally stay device-local (spec: wallets never sync) —
   product decision already made; keep.

## 🟡 Sprint C — polish seams
7. DONE — Home banner (live && !hasSpace) → `reopenFamilySetup()` re-enters the setup flow (kv flag flipped back).
8. DONE — migration 004 replaces both RPCs with email-prefix names + installs the full idempotent RLS policy set (incl. envelope_tx, rate_snapshot read) on live DBs created from 001 alone.
9. open — P4 Sync Details screen (specified in UX_POLISH_PHASE.md).
10. open — mukando round_order names across devices (post-8).

## ✅ Already seamless (verified)
Auth (signup/confirm/sign-in/restore) · family setup create/join (real
RPCs) · offline-first writes via outbox · 8s→15min backoff · empty-state
guards (Home/QuickAdd/Budgets/Savings/Lists/Activity) · local identity
persistence (members_v1/space_name/me_id) · delete-account RPC + migration ·
demo fixtures fully quarantined from live builds.
