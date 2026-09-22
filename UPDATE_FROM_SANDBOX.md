# Updating your local clone (GitHub workflow)

The sandbox where I build **cannot push to GitHub** — it holds no credentials,
and git auth/config does not persist between our messages. (Please also never
paste a GitHub token into the chat.) So GitHub is not a live pipe from here —
the workspace download is the bridge. The loop below takes ~30 seconds.

## One-time setup (your machine)

```bash
git clone https://github.com/<you>/<your-repo>.git
cd <your-repo>            # the folder that contains app/ and backend/
```

If your repo already has an older copy of the project, you're done — that
folder IS your clone.

## Every time I've made changes

1. **Download** the project (the `mhuri-money` folder) from the workspace as
   a zip.
2. **Run the sync script** for your OS from inside your clone:

   **Windows (PowerShell):**
   ```powershell
   .\tools\sync_update.ps1 -Zip C:\Users\you\Downloads\mhuri-money.zip
   ```

   **macOS / Linux:**
   ```bash
   ./tools/sync_update.sh ~/Downloads/mhuri-money.zip
   ```

   The script copies everything over your clone (without deleting anything),
   re-applies `.gitignore`, and shows you `git status` — every change I made
   is visible as a normal diff.

3. **Review, commit, push:**
   ```bash
   git add -A
   git diff --staged        # skim what changed
   git commit -m "Sync from sandbox: <what changed>"
   git push
   ```

## Rules that keep you safe

- **`.env` is gitignored — keep it that way.** Your Supabase keys must never
  enter git history. The sync script will never overwrite your local `.env`.
- `app/lib/l10n/generated/` is gitignored too — it regenerates on
  `flutter pub get` on every machine.
- After syncing, run:
  ```bash
  cd app && dart format lib && flutter pub get && flutter analyze && flutter test
  ```
- If your repo is **public** you can paste the URL here — I can *pull from it*
  in the sandbox to compare your local changes against mine. Pushing stays a
  you-side action.

## Alternative without scripts

Extract the zip over your clone folder manually and run `git status`. The
scripts just automate that (and protect `.env`).

## Go-live round (2026-09-22, unpushed)
- Device builds were silently falling back to demo (no `.env` asset bundled). `AppEnv.load()` now also accepts `--dart-define` overrides (`MHURI_APP_ENV` / `MHURI_SUPABASE_URL` / `MHURI_SUPABASE_ANON_KEY`).
- First live boot purges legacy demo rows + stale markers from upgraded installs (one-time `live_purged_v1` kv guard; never fires once `members_v1` / `space_name` / `auth_user_id` exist).
- Settings shows a sync-mode status card (live vs demo + config error), l10n +3 ×6 → **389**.
- Tests 8 → **10** (purge fires on legacy db; adopted install untouched).

## Demo removal round (2026-09-22, unpushed)
- Demo mode DELETED entirely: no EnvMode, no `DemoAuthService`, no `seed_data.dart`, no demo UI strings (login footer, members tip, invite note, settings mode card all removed). l10n 389 → **383 ×6**.
- App is live-only: config via dart-defines > .env asset > `kSupabaseUrl/kSupabaseAnonKey` constants; no connection → setup error screen (never offline fiction).
- First-boot legacy purge kept (`live_purged_v1`), no longer gated on env.
- Tests: added `test/fake_auth.dart` + `test/seed.dart` (explicit test-only baseline); rewrote env/auth/onboarding/widget/persistence/flows/m4/sync tests for the live-only reality (lib_boot 9 tests; zero `DemoAuthService`/`seed_data` refs).

## Empty-JWT fix (2026-09-22, unpushed)
- Device error "Empty JWT is sent in Authorization header" on Create family — root cause: a failed post-signin token refresh WIPED stored tokens but left the session, so the app looked logged in and sent `Bearer ` + nothing.
- Fixes: (1) controller uses the service-cached session — no second network call after sign-in, no fabricated sessions; (2) restoreSession only clears tokens on a definite 400/401 — transient 5xx keeps the login; (3) `refreshAccessToken()` + self-healing sync token closure; (4) sync client throws `SyncException(401, "Your session has expired — sign in again.")` instead of ever sending an empty credential.
- Tests +4 (transient-keeps-session, dead-token-clears, refresh-renews, client empty-token guard). auth_test 15 → 18.

## Repair after the configure merge (2026-09-22, unpushed)
- The "configure"/merge round restored the .env-asset config (asset-first, constants path removed — kept, it's the right call) but accidentally reverted the empty-JWT auth fixes, leaving a hybrid that could not compile (controller used `service.session`; the interface getter was reverted away).
- This round restores the full auth-fix set (session getter, soft-fail restoreSession, refreshAccessToken, self-healing token closure, empty-JWT client guard + tests) ON TOP of the asset-first config.

## First-run design round (2026-09-22, docs only)
- `FIRST_RUN_SPEC.md` written (9-step onboarding walk-through, nav untouched, accounts deferred, joiner branch, acceptance criteria). No code changes.

## Profile photos + validation sweep round (2026-09-22, unpushed)
- **Avatar upload**: `image_picker` dep (run `flutter pub get`), `avatar_service.dart` (Supabase storage `avatars` bucket, owner-only write, public read), Member.avatarUrl through model/JSON/roster mapper, photo picker + remove in the profile sheet, photo avatars in Home stack + Members lists, `engine.updateMyProfile` PATCH.
- **Unique family names**: migration 005 (unique lower-index + `family_name_taken()` RPC + create_space raises FAMILY_NAME_TAKEN). Inline availability check in the create form; server is the enforce-backstop.
- **Honest auth errors**: GoTrue failures mapped to codes (email_not_confirmed / invalid_credentials / already_registered / rate_limited / weak_password / network) → specific copy in the login screen + "Resend confirmation email" button (/auth/v1/resend).
- **Mukando OPT-IN**: `mukando_enabled` kv (default OFF) — Home smart card hidden until enabled; Savings tab shows a "Turn on mukando" card; Settings has the switch. Choice persists.
- **Validation sweep**: family name ≥2 chars + taken-check, join code required, auth codes above; existing guards confirmed (quick-add amount/member, envelope name/amount, goal/list snackbars).
- l10n +18 ×6 → **401**; generated ×7 refreshed. Tests: live_boot 10→11 (mukando opt-in), auth_test +2 (code mapping, /resend), sync_test +3 (avatar mapper, name-taken, patchRow).
- USER ACTIONS: `flutter pub get` (new dep) · run **migration 005** in Supabase.

## Integrity round: Phase 1 hardening (2026-09-22)
- **Migration chain proven from zero**: new `000_baseline.sql` (table DDL extracted from schema.sql — nothing created the tables before), `008_integrity_profiles_deletion_audit.sql`. CI (`.github/workflows/ci.yml`) now applies 000→008 to a clean Postgres 16 with Supabase-compatible stubs and runs `backend/tests/integrity_smoke.sql` — ALL SIX functional checks pass (create_space defaults incl. automatic 'Groceries' list + audit row; join_space; profile RLS family-scoped; owner blocked while members exist; member delete = leave + tombstone + history retained; sole-owner deletes family + identity completely).
- **schema.sql demoted to reference**: banner added — migrations are the authoritative chain; CI keeps them honest.
- **Profile RLS family-scoped** (was globally readable): 008 replaces `profile_read` (schema.sql + 004's re-add both superseded by running 008 last).
- **Deletion rules** (008): sole owner deletes family+identity; owner with members refused (`OWNERSHIP_TRANSFER_REQUIRED` — client maps it to "make another adult the owner first"); member delete = leave + tombstone profile ("Former member") + sessions revoked + password invalidated + email freed + avatar purged, financial history kept. Old code would FK-fail for anyone with transactions — fixed and tested.
- **leave_family RPC** ready (UI wiring lands with Phase 2 invitations/roles).
- **Sync timeouts**: all REST calls capped at 20s (auth + sync client), avatar upload 60s — dead networks surface as typed offline errors instead of infinite spinners.
- **Sync & data screen** (Settings → Sync & data) replaces the dishonest "Backup — coming soon": status, last sync, pending changes, connected host, honest backup note, real CSV export.
- **Preview-as**: switching members is now labelled "Preview as…" with a banner + Exit on Home; resets on restart; real identity preserved (`exitPreview`).
- l10n +18 ×6 → **447**; generated ×7 refreshed. NOTE: 52 pre-existing ARB keys were never in the generated files (Phase 3 l10n sweep backlog, unchanged this round).
- USER ACTIONS: run **migration 007** (if not yet) and **008** in the Supabase SQL editor, in that order.

## Password recovery round (2026-09-22)
- **The flow a locked-out user needs, end to end**: "Forgot password" emails a reset link that now comes back INTO the app (`mhuri://reset-callback` custom scheme) → recovery session adopted (tokens from the URL fragment, email/sub parsed from the JWT) → **new Reset password screen** (persistent labels, show/hide, strength checklist: ≥8 chars + letter & number, mismatch inline error, double-submit lock) → PUT /auth/v1/user → sign-out → sign-in with confirmation snackbar.
- **Honest failure paths**: single-use/expired link → dedicated expired state with "Send a new reset link"; PKCE-style (?code=) links → same screen, no dead ends; broken token → expired state, never a crash.
- **Mid-flow restart covered**: `pw_reset_pending` kv flag resumes straight into the reset screen if the app was closed between link and new password; cleared on success and sign-out.
- Files: `core/auth/recovery_link.dart` (pure parser, unit-tested), auth service `updatePassword`/`adoptRecoverySession` (+ recover now sends `redirect_to` both as query param AND header), controller mirrors, `features/auth/reset_password_screen.dart`, app.dart deep-link wiring (app_links), Android intent-filter + iOS URL scheme, l10n +14 ×6 → **461** (generated ×7 refreshed).
- Tests: `test/recovery_link_test.dart` (parser: tokens/PKCE/foreign/garbage/JWT claims) + `test/recovery_password_test.dart` (PUT endpoint+headers+body, 401→reset_expired, weak_password mapping, fail-fast without token, adopt persists tokens+marker, signOut clears marker).
- USER ACTIONS: ① `flutter pub get` (new dep **app_links**). ② Supabase dashboard → **Authentication → URL Configuration → Redirect URLs**: add `mhuri://reset-callback` (without it the link silently falls back to the Site URL). No migration this round.
## Shopping-list sync round (2026-09-22)
- **Found the latent bug**: the engine sent `list_id: null` on every item push (kv `default_list_id` was read but NEVER set anywhere) — the server (NOT NULL) rejects them, so shopping items had never actually synced. Fixed end to end.
- **Migration 009** (`009_list_header_sync_tombstones.sql`): `shopping_list.updated_at` + trigger (pull cursor — 001 missed the header table), `deleted_at` tombstones on shopping_list + list_item, indexes, `create_space` now returns `default_list_id`, and a **backfill** giving every pre-008 family a 'Groceries' list.
- **Client**: shopping_list HEADER is now a synced entity (adapter + local table, db v5 + guarded upgrade, pull order = header before items). Creating a family → list id stored from the RPC; joining → list id learned from the header pull (`_captureDefaultList`); adopting a family clears any stale id first.
- **Deletes now sync**: `deleteItem` writes a tombstone (never a hard delete) — other devices remove their copy on pull; ✕ button on every list row (44×44 target, l10n tooltip + confirmation snackbar). l10n +2 ×6 → **463**.
- Smoke suite grew to **9 checks** — new: device A sees default list + pushes item; device B sees header+item and tombstone-deletes; device A sees the delete (convergence). Plus the backfill verified standalone (old family gets Groceries; family with a list untouched).
- NOTE for devices that tested lists before this fix: some item edits may sit "parked" in the outbox with the old null list_id — they never reached the server; re-add those items.
- USER ACTIONS: run **migration 009** in the Supabase SQL editor.
## Invitations + ownership round (2026-09-22)
- **Invites are now real records, not a static code** (migration `010_invites_ownership.sql`): `family_invite` table (role-bound: adult/co_parent/teen/kid/viewer · optional email bind · 7-day expiry · revoke · SINGLE-USE · max 5 open per family). Old family code still works — nothing breaks.
- **Anti-enumeration**: `join_invite` answers the SAME `INVALID_CODE` for unknown/expired/revoked/used/email-mismatch — a guessed or dead code can't be probed. `ALREADY_IN_FAMILY` guard stops join-bombs.
- **Ownership transfer**: `transfer_ownership(new_owner)` swaps roles AND moves the family's static code (unique index!) with the crown — old `join_space` keeps working. Audited (`role.transfer`). Owner can now hand over BEFORE deleting their account (completes the 008 rule loop).
- **App**: new Invite screen (role chips, optional email, QR via `qr_flutter`, share via `share_plus`, copy, open-invites list with revoke, history) — entry in Members → the ⋯ sheet (owner-only server-side). "Make owner" with confirm dialog in a member's popup (owner → adult members). Deep link `mhuri://join?c=MHRI-XXXXXX`: QR/WhatsApp link lands in the app → join step prefilled (kv `pending_invite_code`), even across login. Parser: `parseInviteCode` (+ tests: uppercase, wrong-scheme, garbage).
- **Optional email Edge Function**: `supabase/functions/invite-email/index.ts` (Resend; deploy + `RESEND_API_KEY` per header comments). WhatsApp/SMS/QR share stays the primary channel — nothing depends on the function.
- Smoke suite: **18 checks green** (8 new: invite create/read, non-owner blocked, member-join guard, accept with bound email → role=teen, single-use reuse refused, revoked refused with same error, transfer moves code+roles+audit (+ back), account-without-family deletes cleanly).
- deps: `qr_flutter ^4.1.0`, `share_plus ^11.0.0` (run `flutter pub get`). l10n +30 ×6 → **487** (generated ×7). CI RPC guard now expects 9 RPCs.
- USER ACTIONS: run **migration 010** in the SQL editor. Optional: deploy invite-email Edge Function.
## Role enforcement + audit round (2026-09-22)
- **The onboarding switches are REAL policy now** (migration `011_role_enforcement_audit.sql`): a `role_perm(space, key, default)` helper lets RLS read `family_space.settings->role_permissions` at query time. Defaults mirror the onboarding map exactly, so existing families see no change until an owner flips a switch.
- **What RLS now enforces**: teen transactions (default ON) and kid transactions (default OFF) on transaction insert/update; budget visibility (envelope_read) and wallet visibility (account_read) per child_budget/teen_budget/child_wallet/teen_wallet. Before this, tx_write allowed teens always and kids never — the switches promised things the server forbade; that inconsistency is gone.
- **Audit completion (#9)**: trigger-written activity_log rows — `tx.create` (transaction insert), `goal.contribute` (goal_tx insert), `request.approve` / `request.decline` (kid_request state change, actor = decided_by). Appended, never blocking; hash columns remain placeholders (no tamper-evidence claim).
- **Smoke suite: 24 checks green** (6 new: teen tx allowed-by-default AND audited; kid tx refused by default; owner flips child_transactions ON → kid can transact; teen_transactions OFF → teen refused; child_budget OFF → kid sees no envelopes while owner still does; approval lands in the audit trail). The enforcement tests run as the real `authenticated` role — postgres would have bypassed RLS.
- **Client**: engine pulls family settings on full sync (`_pullFamilySettings`) → `AppState.applyRolePermissions` + `perm()` getters with identical defaults (kidCanTransact / teenCanTransact / kidCanSeeBudget / teenCanSeeBudget); Teen Zone's envelope peek now honours `teenCanSeeBudget`. UI + RLS agree; server remains the boundary.
- Disposition: no per-mutation snackbar guard added in AppState — the kid/teen shells have no direct transaction entry (kids act through requests, which stay allowed); RLS is the hard boundary and sync surfaces rejections honestly. Documented here as the deliberate choice.
- USER ACTION: run **migration 011** in the SQL editor.
## Sync reliability round (2026-09-22)
- **401 → refresh → retry exactly once** (#8): SyncEngine gained `retryAuth`; when a push/pull dies with an auth error, the engine forces a token refresh and replays the pass once before surfacing "sign in". Wired to `auth.refreshAccessToken()` in app.dart.
- **Parked changes are VISIBLE now** (never silently dropped): Sync & data shows an orange "Changes that need you" card listing every parked outbox change — kind + the user's own name/reason/note (never a table name or UUID), tries + date, per-item **Retry** (resets attempts, forces a sync) and **Discard** (confirm dialog: honest "stays only on this phone, will never reach the cloud"). Discard is the only way a row leaves the outbox besides success.
- **Reinstall reconciliation** (#8): migration `012_restore_my_space.sql` — the auth token alone answers "am I still in a family?" (space + name + code). A reinstalled phone (or second device) skips family setup entirely: engine `restoreFamily()` adopts the membership and full-syncs — never re-creates, never duplicates. Smoke checks: owner restores from token alone; outsider gets a clean null.
- **Per-entity conflict rules documented** (`backend/SYNC_CONFLICTS.md`): push-then-pull convergence (last PUSH wins), append-only goal_tx, one-way kid_request state machine, tombstone rule for every future delete UI ("write deleted_at + push — never DELETE").
- **Explicit dispositions**: tombstones for envelope/goal/kid_request/earning are NOT built — those have no delete UI today (the one live delete surface, list items, is tombstoned since the sync round); the doc pins the pattern so the first delete UI ships with its column + migration. No separate diagnostics screen — Sync & data now carries status + last sync + pending + parked + host (the plan's "detail rows", in the honest screen).
- Smoke suite: **27 checks green** (2 new for restore). l10n +13 ×6 → **500** (generated ×7). CI RPC guard now expects 10 RPCs.
- USER ACTION: run **migration 012** in the SQL editor.
## Deletion UX + Phase-3 opener round (2026-09-22)
- **#10 Account-deletion UX completed** (on top of the now-correct 008 RPC): ① "What happens when you delete" sheet BEFORE the typed-DELETE dialog — owner text (whole family space deleted) vs member text (leave + tombstone "Former member", others keep data) + sessions-revoked line; ② the existing typed-DELETE tier kept; ③ non-dismissible **progress dialog** showing the four server phases (leave → personal details → sign-ins → account), all tick on completion, pops with the outcome.
- **l10n sweep COMPLETE** (Phase 3 item): the last 10 never-generated ARB keys (kidsGoalSaved, kidsHi, kidsWishItem, loginSentCode, recSkipped, safeToSpend, scheduledOn, setCurrencySub, syncPill, teenSplitHint) are now in the generated files — **every ARB key now has code, zero backlog**.
- **family_setup_screen fully localized** (~33 hardcoded English strings out): all steps, fields, role chips (display via roleAdult/roleParent/roleTeen/roleChild/roleViewer; stored values unchanged), invite share text/subject, permission toggle labels, CTAs. l10n +37 ×6 → **537** (generated ×7).
- **Phase 3 #11 started — shared component kit**: `lib/core/widgets/ui.dart` (MhuriCard, SectionHeader, PrimaryButton, EmptyHint). Adopted in-place: Sync & data's two cards → MhuriCard; Settings' `_header` → SectionHeader (identical look). New code must use the kit; remaining screens migrate during the Phase-3 pass.
- Backend untouched this round — smoke suite still 27/27. **No new migration.**
- REMINDER: **migration 012** (previous round) is still outstanding on your device.
## Phase-3 completion round (2026-09-22)
- **Fake QR REMOVED (prototype sweep)**: the family-setup invite step showed a dashed icon box labelled "Scan to join" — now a REAL QR of `mhuri://join?c=<code>` (same deep link as the Invite screen; empty-code state keeps the label). `_DashedPainter` deleted.
- **Forms hardening (#13)**: unsaved-changes guards on family setup (PopScope, warns ONLY when name/family fields have text) and the new-envelope sheet (close routes through the guard, armed on first keystroke) — copy: "Discard changes? / You have not saved yet. Leave anyway?" (stay/leave). Verified: persistent labels everywhere, currency keyboards already `numberWithOptions(decimal: true)` on all money fields (plain `.number` uses are PINs/quantities — correct), inline error boxes on setup/invite/login, double-submit locks (`_busy`) on all async forms.
- **Component kit (#11)**: `confirmDialog()` added (danger variant); both new guards adopt it. Kit now: MhuriCard · SectionHeader · PrimaryButton · EmptyHint · confirmDialog.
- **A11y audit (#15)**: zero icon-only buttons without tooltips (semantics ✓); 44×44+ targets present (list ✕, invite actions); largeText scaler + labeled bottom nav; reduced-motion already respected in motion.dart (disableAnimationsOf) + celebrate() + rings — selective 150–250ms durations confirmed. WCAG AA contrast both modes = the one item needing a device render check.
- **Prototype sweep (#16)**: zero "coming soon"/placeholder/demo UI strings — remaining grep hits are code comments only.
- l10n +4 ×6 → **541** (discardChangesTitle/Body, stay, leave; generated ×7, full parity). Backend untouched — 27/27. **No new migration.**
- Phase 3 COMPLETE except: WCAG AA device render check + sn/nd fluent review (needs native speakers) + fr/pt overflow on device — all device-session items.
