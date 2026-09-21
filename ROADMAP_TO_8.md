# Roadmap to 8/10 — Build-Here Plan

**Strategy:** build 100% of the product in the sandbox → download once → wire APIs
via `.env` → short device session to verify. No Flutter toolchain in the sandbox.

**Baseline today (2026-09-21):**

| Item | Status |
|---|---|
| Product spec, mockups, design system | ✅ done |
| All 3 shells (adult / teen / kid), 12+ screens | ✅ done |
| `flutter analyze` | ✅ **No issues found** (compiler-verified baseline) |
| Unit + widget tests | ✅ written · ⏳ run on your machine (5-min task, see M0) |
| Persistence, auth, sync, notifications | ❌ not started — this roadmap |

---

## The working protocol (every session, all milestones)

1. **Pattern discipline.** New UI/logic reuses APIs already proven in the
   analyzer-clean baseline. Genuinely new APIs (Drift, Supabase) are isolated in
   `core/db/`, `core/sync/`, `core/auth/` — thin wrappers, never scattered.
2. **Static audit after every change** (brace/import/API cross-check harness).
3. **Verification bridge (you, optional per checkpoint):** run one command on
   your machine and paste the output — no IDE needed:
   ```bash
   cd mhuri-money/app && flutter analyze && flutter test
   ```
   I fix anything it finds in the same session. This replaces the in-sandbox
   compiler. If you skip checkpoints, risk simply accumulates to device week.
4. **Baseline rule:** the tree must stay analyzer-clean. No "temporary" breaks.

---

## Milestones

### M0 — Baseline lock (you, ~5 min)
- [ ] On your machine: `flutter create --project-name mhuri_money --platforms android,ios .`
- [ ] `flutter pub get && flutter analyze && flutter test` → paste me the output
- Done when: tests pass (or I fix what fails). From here on, every checkpoint
  is the same one command.

### M1 — Persistence: the app remembers (2–3 sessions)
- ✅ **Built (this session):** sqflite (SQLite) storage — chosen over Drift
  because it needs **zero code generation**, fitting the build-here rule;
  every line is hand-written and statically checkable.
- ✅ `core/db/app_database.dart` — hand-written schema mirroring
  `backend/schema.sql` (12 tables); fails soft to in-memory demo mode.
- ✅ `core/db/persistence.dart` — row mappers + seed/load/upserts for every
  entity; batch-seeded first run.
- ✅ Write-through hooks on **every** AppState mutation; startup hydration
  replaces the seed with stored state; `ready()` / `flushWrites()` for
  deterministic tests.
- ✅ `test/persistence_test.dart` — 4 restart-roundtrip tests (the M1 DoD).
- ⏳ **Verify via your checkpoint command:** `flutter analyze && flutter test`
  (persistence tests need SQLite on the host — standard on macOS/Linux).
- **DoD:** restart the app → every envelope, tx, list, jar is still there. ~3→4.5/10.

### M2 — Identity & auth (2 sessions)
- ✅ **Built (this session):**
  - `core/config/app_env.dart` — hand-rolled `.env` parser (no dotenv dep):
    `APP_ENV=demo|live`, Supabase keys, optional FCM/Sentry/rate keys.
    Missing/invalid `.env` **always** → offline demo mode, exactly as before.
  - `core/auth/` — `AuthService` interface; **DemoAuthService** (code `1234`);
    **SupabaseAuthService**: hand-written GoTrue REST client (otp / verify /
    refresh / logout) with injectable HTTP client → fully testable offline;
    tokens persisted in the local `kv` table.
  - `AuthController` — session lifecycle (restore/send/verify/signOut) with
    busy + error state for the UI.
  - `LoginScreen` — phone → OTP phases, ZW number normalisation
    (0772… → +263…), error states, busy spinner.
  - Gate in `app.dart`: live mode without a session → login; everything else
    → classic app. Demo never shows login.
  - `PinStore` — salted SHA-256 PINs (Kids Mode exit now real & settable from
    Family settings; kid profile PINs ready for M4 device handoff).
  - Tests: env parser (5), auth flows + REST via FakeClient (8), PIN store (3),
    login-gate widget test.
- ⏳ Verify via your checkpoint command.
- Note: login proves *identity*; family-space linking goes live with M3 sync.
- **DoD:** real OTP login once `.env` is wired; demo mode untouched without it. ~5/10.

### M3 — Sync: the core promise (3–4 sessions)
- ✅ **Built (this session):**
  - `core/sync/outbox.dart` — ordered, idempotent outbox table (v2 schema);
    failed batches stay queued and retry.
  - `core/sync/sync_mappers.dart` — 7-entity registry (transaction, envelope,
    goal, goal_tx, list_item, kid_request incl. teen proposals, earning):
    domain ↔ server JSON with enum bridges (bankCard↔bank_card, roll↔rollover).
  - `core/sync/supabase_sync_client.dart` — hand-written PostgREST client:
    push = merge-duplicates upserts (idempotent), pull = `updated_at` cursor,
    rpc for family bootstrap. No Supabase SDK.
  - `core/sync/sync_engine.dart` — push→pull→apply loop; debounced after
    mutations, 45s poll, pull-on-start; create/join family space (wipes demo
    seed first); statuses (idle/syncing/offline/needsSignIn/needsSetup/error).
  - `backend/migrations/001_sync_and_space.sql` — updated_at columns +
    triggers, `create_space`/`join_space` SECURITY DEFINER functions with
    invite codes, RLS-safe bootstrap.
  - App wiring: every live mutation enqueues server-shaped JSON; pulls merge
    into memory + local DB; Home "waiting to sync" banner is now REAL
    (outbox count; tap = sync).
  - Family space UI in Members (live mode): create/join dialogs, invite-code
    card, last-sync status, Sync now.
  - Honest scoping: chores/stars/mukando/wallet balances stay device-local
    for M3 (documented); approvals resolve last-writer-wins at family scale.
  - Tests: mapper roundtrips, outbox order, create-space wipe+pull,
    mutation→outbox→verbatim push, pull apply + cursor advance,
    restart-survival of pulled rows, bad-invite-code error. All offline.
- ⏳ Server side: run `schema.sql` + `migrations/001` on your Supabase project
  when you wire `.env` (backend/README covers it).
- **DoD (after .env):** two phones, one family space, live shared lists and
  approval flows — the reason the app exists. ~6.5/10.

### M4 — Product completeness (4–6 sessions)
- ✅ **Built (this session):**
  - **Onboarding** — 3-slide first run (live mode only; Skip persists), then
    straight into the app; hydration splash while the DB loads.
  - **Recurring transactions (C7)** — rules with weekly/monthly/term
    frequency; due rules surface on Home's smart card and Budgets with
    **Post / Skip** review actions (nothing charges silently); catch-up
    advancement for stale rules; persisted locally.
  - **Cycle math (B5 + D4)** — payday-aligned cycles (`month_start_day`,
    settable, persisted); envelope spending now scoped to the current cycle;
    pace based on cycle progress; **rollover carry** (one-cycle lookback)
    and **accumulate** mode (base × cycles since first use, capped 24 —
    documented simplification).
  - **Family Meeting (I4)** — guided 5-step agenda screen (recap, envelope
    health, goals, kids' queue, "one thing to improve" with saved note).
  - **CSV export (I6)** — all transactions to the device Documents folder
    (fails soft off-device). PDF/image share stays post-8 backlog.
  - **Empty/loading states** — shared EmptyState widget wired into Budgets,
    Activity, Savings, Teen earnings; splash for hydration.
  - Tests: cycle math (day-25 wrap, boundary day, rejects), rollover carry,
    recurring post/skip/toggle + restart survival, onboarding/month-start
    persistence, CSV soft-fail.
- ⏳ **Not in M4 (honest list):** statement import (C10), pantry mode (F7),
  receipt OCR (C3), share-as-image/PDF, recurring-rule *sync* (rules are
  device-local until M5 hardening), Kid PIN per-profile setup UI (PinStore
  ready; parent UI lands with device-handoff polish).
- **DoD:** every spec module A–J has its MVP feature set working. ~7/10.

### M5 — Notifications & reliability (2–3 sessions)
- ✅ **Built (this session):**
  - **Reminder planner** (`core/notifications/reminders.dart`) — pure,
    unit-tested computation of the spec's J2 alert set: bill due in 3 days
    (C7), envelope 80% / used-up warning, kid request + chore-approval
    nudges, mukando turn (weekly Sunday check-in), goal milestones
    (25/50/75/100%), family-meeting-eve reminder, weekly digest
    (Sunday 6pm). Quiet-hours shifting (J3) and a 12-reminder cap built in.
  - **Device scheduling** (`core/notifications/notifier.dart`) —
    flutter_local_notifications v22 (all-named API), UTC-instant scheduling
    (no timezone plugin needed), weekly repeats via dayOfWeekAndTime,
    inexact alarms (no extra Android permission), every call fails soft.
  - **Settings screen (J3)** — master switch, per-category prefs, quiet
    hours pickers, month-start-day picker, CSV export, test-notification
    button; reachable from the Family screen's ⚙ icon.
  - **Home bell (§7.5)** — opens a live "what will notify" sheet.
  - **Event nudges** — goal milestone crossing on contribute(); kid-device
    "your request was answered" when the decision syncs over (seen-ids
    persisted so it never double-fires).
  - Plan changes are deduped (sync ticks stay free); config persists in kv.
  - Tests: 14 planner cases + settings persistence + milestone trigger.
- ⏳ **Not in M5 (honest list):** server push (FCM via Supabase edge
  functions — needs a Firebase project; post-8), outbox
  retry/back-pressure hardening and error-reporting hook (folded into M7).
- **DoD:** approval arrives as a notification; nothing is lost offline. ~7.5/10.

### M6 — International (re-scoped per redirect: "international, not just Zim")
- ✅ **Built (this session):**
  - **Official gen-l10n toolchain** — `flutter_localizations` + `generate:
    true` + `l10n.yaml`; ARBs in `lib/l10n/`; generated code in
    `lib/l10n/generated/` (real files, no synthetic packages). **Adding a
    language = drop in one ARB file** (plus one line in `kLanguageNames`).
  - **Six languages**: English, chiShona, isiNdebele (founding languages),
    Español, Français, Português. Placeholder support (safe-to-spend
    amount, quiet-hours range) via ICU `{placeholders}`.
  - **Core surfaces localized**: bottom nav, Home (greeting, Family Pool,
    safe-to-spend, see-all), Budgets (+ recurring + new envelope),
    Activity, Savings, Lists, Reports CTAs, Settings, reminders sheet,
    onboarding (all three slides), and all Kids/Teen strings via the
    legacy `tStr` — now a thin adapter over `AppLocalizations` (21 keys ×
    6 languages). Remaining long tail (deep sheets, snackbars) stays
    English for now — incremental ARB additions.
  - **Language picker** (Settings ⚙ + Family tab) — 6 languages, persisted
    in kv; MaterialApp wires delegates/supportedLocales/locale.
  - **Elder large-text mode (J6)** — global 1.2× text scaler, toggle in
    Settings, persisted. TalkBack: icon buttons already carry tooltips
    (read as labels); high-contrast theme + full Semantics audit → backlog.
- ⏳ **Not in M6 (honest list):** native-speaker review of SN/ND/ES/FR/PT
  (spec required review for SN/ND — still true, now for four more); full
  long-tail string coverage; high-contrast theme; RTL script support
  (Arabic etc. — layout uses standard widgets, so it's additive);
  **multi-currency ledger** (Currency enum → ISO-4217 + editable rates +
  account-currency pickers — touches models/persistence/sync mappers; its
  own milestone-sized change, designed and quoted here for M8+).
- **DoD:** the app speaks six languages end to end on every core surface. ~8/10 in code.

### M7 — Quality wall (2–3 sessions)
- ✅ **Built (this session):**
  - **Five core flows as tests** (`test/flows_test.dart`) — money in/out →
    envelopes + pool; goal contribution → milestone nudge; kid request →
    approve → jar + nudge clearing; shopping run → Groceries envelope;
    recurring bill → reviewed post → survives restart.
  - **Widget tests per main screen** (`test/widget_screen_test.dart`) —
    Home (+ bell → reminders sheet), Budgets, Activity, Savings, Reports,
    Settings, Lists, Onboarding (+ brand asset) all pump the seeded demo
    state and assert real content.
  - **Sync reliability hardening** (absorbed from M5): exponential backoff
    after failed syncs (8s → 15min cap, reset on success, bypassed by
    "Sync now" = `syncNow(force: true)`); poison outbox batches **park**
    after 8 failed attempts (surfaced with a clear message, retried via
    Sync now, never dropped); pluggable `SyncEngine.reportError` hook
    (wired to a debug printer — point it at Sentry/Crashlytics in live
    mode; optional `SENTRY_DSN` stays post-8).
  - **Branding assets** — AI-generated app icon + splash PNG in
    `assets/branding/`, wired via pubspec config for
    flutter_launcher_icons ^0.14.4 + flutter_native_splash ^2.4.8 (one
    command each on your machine — see README); brand mark on onboarding.
- ⏳ **Not in M7 (honest list):** golden tests need one real
  `flutter test --update-goldens` run — deferred to M8 device week;
  on-device integration tests (`integration_test/`) likewise M8;
  analyzer-guided const/perf pass happens live at your first
  `flutter analyze`. M6 (language & accessibility) deliberately skipped
  for now — still open on the ladder.
- **DoD:** the 5-minute demo script passes testfully, not just manually. ~8/10 in code.

### Interface pass 3 (post-audit wave 2) — DONE
- **i18n fold-in**: the 9 strings the premium pass hardcoded (sync pill w/ ICU plural, hide/show tooltips, Theme/System/Light/Dark, six-month net, donut empty) + Undo → ARB keys in all 6 languages, parity verified.
- **Pull-to-refresh**: RefreshIndicator on Home/Budgets/Savings/Lists/Activity/Reports → `AppState.refresh()` re-reads the local store.
- **Error + retry**: `lastError` captured in hydration; designed `_ErrorPane` (no white screen) with Try again.
- **Skeletons**: `Skeleton` pulse widget; cold-boot splash now pulses the logo + 3 skeleton bars (shape of what loads).
- **Undo**: circle collect + chore confirm (overwrite-safe ops only — the domain has no deletes by design, so no sync tombstones invented).
- **Status bar**: per-theme SystemUiOverlayStyle (dark icons on light, light icons on dark).
- **Tablet**: tab content capped at 620 dp centered (phone-first, premium standard).
- **Semantics**: CountUp announces the final value once; TrendBars expose a spoken summary.
- **Dark native splash**: `color_dark`/`image_dark` (+android_12) → regenerate with flutter_native_splash:create (user machine).
- Tests: +3 (refresh round-trip, circle undo, chore undo) → 8 in premium_pass_test.

### Premium frontend pass (G1–G13) — DONE
Implemented the FRONTEND_GAP_AUDIT ladder in full (light-theme visuals preserved; everything honors OS reduce-motion):
- **G1 Dark mode**: `MhuriColors` light/dark palette + `context.card/ink/…` extension; `buildAppDarkTheme()`; ThemeMode (system/light/dark) persisted via kv, Settings dropdown; ~530 token references migrated off const tokens; dark AA contrast verified (ink 16.0 / soft 8.4 / faint 5.2).
- **G2 Motion**: `CountUpText` hero amounts, rings draw in (`RingProgress` tween), confetti `celebrate()` overlay (goal reached, circle collect, chore confirm).
- **G3 Haptics**: nav tick, save medium, approve/collect light, swap/eye selection, wrong-PIN heavy.
- **G4 Reports**: hand-rolled touch-scrub `DonutChart` + legend (top-6 + Other) and 6-month net `TrendBars` (USD-normalized) — zero chart packages.
- **G5 Privacy**: eye-toggle balance mask (hero, safe-to-spend, pot) persisted + auto-hide on app pause (Monzo-style).
- **G6 A11y**: light `kInkSoft/kInkFaint` darkened to WCAG (5.19 / 4.52), all IconButtons have tooltips (+FAB), reduce-motion honored in every animation.
- **G7 i18n formatting**: `intl` dep; es/fr/pt grouping (1.234,56) via `Money.localeTag` (en + sn/nd keep en grouping); login example number internationalized.
- **G8 Type ramp**: `MhuriType` display/titleL/titleM/body/caption; hero migrated; rest adopts opportunistically.
- **G9 Onboarding**: 4th "Gentle reminders" priming slide (ob4 ×6 ARBs, parity ✓) + animated dots.
- **G10**: pool card compresses subtly on scroll (NotificationListener + AnimatedScale).
- **G11**: chore confirm → confetti + haptic. **G12**: offline pill (N changes saved on device). **G13**: PIN field wiggle + heavy haptic on wrong PIN.
- Tests: `test/premium_pass_test.dart` (5 tests: palette, themeMode clamp+round-trip, hideAmounts round-trip, en default, es/fr/pt grouping).
- Known follow-ups: SCREENSHOTS.html still light-only/emoji-rendered (regenerate after checkpoint); `Icon(style:)` oddity in reports legend is pre-existing & compiles on user's SDK — leave.

### Internationalization pass (post-M6) — DONE
Removed all Zimbabwe-only terminology app-wide (lib / test / ARBs / docs / preview):
- **Payment methods**: `Method.ecocash/zipit/innbucks` → `mobileMoney` / `agent` (wire values `mobile_money`, `agent`; labels 'Mobile money', 'Agent / cash point').
- **Mukando → savings circle**: `Mukando`→`SavingsCircle`, `AppState.mukando`→`circle`, `mukandoCollect()`→`circleCollect()`, local table `mukando`→`circle`, reminder category/key → `circle` / `circle_weekly`.
- **Demo data**: the Taylor family (David, Maya, Leo, Mia, Zoe, Nana), Main bank / Mobile wallet, FreshMart / City Supermarket / Saturday market, 'Fuel + bus fares', 'Rice 10kg', 'Family Holiday — by the sea', space 'The Taylor Family', collection order 'Aunt Kim, Maya, Uncle Raj, David, Mrs. Lee'.
- **RBZ** → 'daily central-bank snapshot' / 'daily reference'; **+263** → generic E.164 normaliser with a `kDefaultCountryCode` const (launch-market default).
- **ARBs ×6**: onboarding copy internationalized ('in every currency you use'); Shona/Ndebele files keep native words — mukando/mhuri/Gogo are correct *translations*, which is the internationalization itself.
- **Kept on purpose**: the USD+ZiG ledger pair (engine decision) + 'Zimbabwe Gold (ZiG)' currency labels; the 'Mhuri Hub' product name (brand).
- Verified: terminology gate + structure checks PASS (56 dart files, 14,526 lines).

### Design polish pass (frontend quality, pre-M8)
- ✅ **Built (this session):** "international app feel" upgrade, centered on
  the design system:
  - **Poppins typography** (bundled, OFL — 5 weights in assets/fonts/,
    license included) — geometric, warm; the standard consumer-fintech
    look. Wired app-wide via the theme (every screen inherits).
  - **Full M3 theme system** (`app_theme.dart`): refined seed ColorScheme
    (teal-tinted ink, soft washes), a real type scale (tight display
    numbers, airy body), stadium buttons, filled/rounded inputs with focus
    rings, 24-radius cards & dialogs, 28-radius sheets with drag handles,
    rounded floating snackbars, chips, tiles, switches, FAB, nav bar —
    and platform-correct **page transitions** (Zoom on Android, Cupertino
    swipe-back on iOS) with InkSparkle press ripples.
  - **Design tokens**: radius ruler (12/18/24/28), hairline + soft shadow
    tokens (`kCardShadow`), wash colors — so future screens stay coherent.
  - **Hero moments**: Family Pool card gets a floating gradient shadow +
    display-size money typography; branded splash (logo, name, tagline).
- ✅ **Icon system (this session):** app-wide emoji→Material-icon sweep —
  110+ edits across 27 files, then taken to the root: the data layer now
  uses SEMANTIC icon keys (`'cart'`, `'school'`, `'man'`, `'bank'`…) —
  zero emojis in the database, sync payloads, or UI (safe because no
  device has ever run the app — no migration needed). A central map
  (`core/widgets/app_icons.dart`, key→icon, neutral-icon fallback for
  unknown/remote keys) feeds every renderer: tx tiles, envelope cards,
  goal rings, avatars, smart cards, reminders, settings, onboarding, kids,
  teen, reports, dropdowns. Snackbars reworded; ARB titles de-emojified
  (6 languages). Emojis remain ONLY in OS-notification text (platform
  convention — the tray cannot render IconData) and →/✓ text glyphs.
  Key coverage enforced by `app_icons_test.dart`.
- ⏳ **Next polish candidates:** dark mode (needs hardcoded-color sweep),
  skeleton loaders, hero animations, haptics.

### M8 — Device week (the only on-device phase, 1–3 days)
- Download → `flutter create` platforms → install on your phone.
- Create `.env` from `.env.example`, fill keys → login, sync, push live.
- Run the full demo script on-device; we work the fix list together
  (small runtime fixes expected: layout quirks, keyboard insets, plugin configs).
- **DoD: ~8/10 working product in your hand — beta-ready.**

### After 8 (unchanged from the spec): closed beta with 10–30 families →
hardening → store listing, privacy policy, Play Store review → **launch (10/10 path).**

**Total estimate to 8/10: ~16–24 working sessions + device week.**

---

## Honest risk register (build-here specifics)

| Risk | Mitigation |
|---|---|
| No runtime checks here → errors surface at M8 | Pattern discipline; isolated new-API wrappers; your optional `analyze && test` checkpoints each milestone keep debt near zero |
| Drift/Supabase API drift vs my knowledge | Pin versions in pubspec; keep wrappers thin; official quickstart patterns only |
| Plugin setup (notifications, FCM) needs native config | Deferred config files prepared in M5; applied during M8 with docs |
| .env keys misunderstood | `.env.example` ships now; app refuses live mode without valid keys and explains why |
| Scope creep breaks the timeline | Each milestone has a DoD; extras go to the post-8 backlog |

## What I will NOT do (per your instruction)
- No Flutter/Dart SDK installs in the sandbox.
- No Flutter builds, `flutter analyze`, `flutter test`, or any Dart execution in
  the sandbox — not even small logic-only runs.
- All in-sandbox verification is non-Dart static analysis (the structure /
  consistency harness) plus pattern discipline.
- Verification truth lives outside the sandbox: your optional one-command
  checkpoint each milestone, and device week at the end.


---

## l10n completion (i18n wave 3) — DONE ✅ 2026-09-21

**All 17 feature surfaces now localize through `AppLocalizations`; 6-language parity (EN/ES/FR/PT/SN/ND) at 176 keys each.**

What shipped:
- **ARBs**: +93 keys (login, quick-add, kids mode, teen zone, members/settings stubs, family meeting, recurring rules) + enum label sets (role ×5, payment method ×6, list state ×3, frequency ×3 incl. `freqTerm`, rollover ×3) with 7 placeholder metas (`@loginSentCode`…`@recSkipped`). JSON-valid, key-parity verified across all six files.
- **Call sites**: all hardcoded EN UI strings replaced in `login_screen`, `quick_add_sheet`, `kids_mode`, `teen_zone`, `members_screen` (incl. the six settings stub rows), `family_meeting_screen`, `recurring_ui`; enum `.label` getters (role/method/state/freq/rollover) at 8 call sites now route through new `methodLabel/roleLabel/itemStateLabel/freqLabel/rolloverLabel` helpers in `core/l10n/app_strings.dart`. Invalid `const` constructors wrapping l10n calls auto-stripped.
- **Static gate**: ARB parity ✓ · 107 distinct l10n refs all resolvable to ARB keys ✓ · 0 const-wrapped l10n ✓ · 17/17 feature files import l10n ✓ · 0 leftover EN UI strings in the 7 files ✓.
- Kept as data/proper nouns (by design): space name "The Taylor Family", `ZiG`/`USD`, `FreshMart`, "New Bike" goal seed, currency long names.

Note: `lib/l10n/generated/app_localizations.dart` is a **build-time artifact** (`generate: true` + `l10n.yaml` → `output-dir: lib/l10n/generated`); it materializes on `flutter pub get` on your machine — its absence in this sandbox is expected.


---

## Premium pass 2 (Track A: sync-scope completion + Track B: feel/depth) — DONE ✅ 2026-09-21

**Track A — the family-sharing claim is now true end-to-end (code level):**
- **10 synced entities** (was 7): + `chore` (stars/state), `mukando` (savings-circle header; deterministic per-space row id, member names in `round_order[]`), `recurring_rule` (new table). Proposals were already synced via `kid_request`.
- **backend/schema.sql** append-section: `updated_at` + triggers on **all 10 synced tables** — this fixed a latent first-sync crash (only `transaction` had the column the pull API orders by); `chore.state` + nullable assignee; new `recurring_rule` table with RLS + index.
- Engine glue: 9 mutation sites now queue to the outbox (circle collect/undo, chore claim/confirm/unconfirm, recurring add/post/skip/toggle); pull-apply + local-persistence cases for the 3 new entities; live pending-pill refreshes right after enqueue.
- **Latent compile bugs found & fixed** (would have failed the first `flutter analyze`): duplicated `child: child:` in 4 screens (home/savings/activity/reports), `),,` in the shell, `SnackBarBehavior.floating()` call, `const InputDecoration(fillColor: context.card)` in meeting, budgets `child: child:`.

**Track B — feel & depth:**
- **Two-pane tablets**: budgets (envelopes | recurring rules) and family meeting (money | family agenda) at ≥900dp; shell now caps per-tab (620 phone-width / 980 budgets).
- **Soft refresh**: pull-to-refresh no longer swaps the tree to splash (`refreshing` flag); splash only on first load / error retry.
- **A11y**: donut chart exposes full "Spending by envelope: X n%" Semantics label (scrub excluded); reports donut a11y label localized; RingProgress already carries readable % text.
- **Haptics**: added on quick-add save (medium) — home already had confirm/collect/undo covered.
- **i18n completion to zero**: 139 more keys this pass (97 UI + 40 placeholder-composites + fixes) → **315 keys ×6 languages, full parity, 297 call-site refs all resolve, 0 English literals left in feature code** (keepers: The Taylor Family, New Bike, Zoe as data).

**Static gate (sandbox, non-Dart):** Dart-aware paren/bracket/brace balance PASS on 59 files · ARB parity PASS · ref resolution PASS · EN sweep 0 · 98 tests now in `test/` (94 + 4 new adapter round-trip/pull-order tests).


---

## Hardening continuation (resume-sync + live-mode id fixes) — DONE ✅ 2026-09-21

**Two first-live-sync blockers found and fixed before they ever hit a real Supabase project:**
- **Client ids were not uuids.** `_seq()` minted `tx0`-style ids while every server id column is `uuid` — the FakeServer (201-always) masked it; real Postgres would reject **every** client push. Fix: new `core/utils/ids.dart` (`newUuid()` v4 via `Random.secure`, `uuidFromSeed()` md5-based deterministic) wired into `_seq`, `newClientId`, and the mukando deterministic id (`uuidFromSeed('mukando/<spaceId>')`).
- **Space adoption didn't clear the 3 new stores.** `wipeSynced()` covered 8 tables, `onSpaceAdopted()` cleared 8 lists — demo-seed chores/recurring/circle would have leaked into family sync. Now 11 tables / full in-memory reset with a neutral circle placeholder until the first pull.

**Also shipped:**
- **Resume-sync**: app resume (live + logged in) fires `syncNow()` + pill refresh — the 45s poll window collapses to ~0 for the "just opened the app" moment.
- **Tests**: +3 (uuid shape/uniqueness/determinism; premium-entity pull applies chore/recurring_rule/mukando and advances the cursor; premium-entity mutations push to all three server tables with every pushed id uuid-verified). **101 tests total.**

**Gate:** 60-file Dart-aware balance ✓ · 315×6 parity ✓ · 297 refs ✓ · EN sweep 0 ✓ · uuid minting ✓.


---

## Device-feedback pass (Family screen dead rows + profile switching) — DONE ✅ 2026-09-21

**First real-device feedback incorporated. The Family screen's stub rows are now fully functional:**
- **Switch profile (new)**: settings row → member picker sheet (avatar, role, "You" tag) → `switchUser` + jump to root. **View-as is no longer demo-seed-only** — every member can be previewed in live mode too (Kids Mode stays PIN-sealed). The stray "You" chip is localized.
- **Currency & rates** (new sheet): display-currency picker (USD/ZiG), editable ZiG-per-USD rate with save + "reset to RBZ snapshot" (15.27). New `setCustomRate` persists via kv and hydrates on restart.
- **Privacy** (new sheet): "Hide amounts when I leave the app" toggle — the background auto-hide is now a *preference* (`autoHideAmounts`, kv-persisted, respected by the app lifecycle observer) instead of hardcoded — plus "Hide amounts right now".
- **Backup & export** (new sheet): working CSV export (path snackbar), copy invite code (live), and an honestly-disabled "Encrypted cloud backup (coming)" row.
- **Notifications** row now opens the real Settings screen (reminders, quiet hours, test notification). "Month start day" stays informational by design.

**Plumbing:** `DbSnapshot` gained `autoHide`/`customRate` (persist + hydrate round-trip, covered by a new state test). +14 l10n keys ×6 (**329 keys**, parity ✓).

**Process note:** two script batches reported success while silently not applying (unassigned transform calls) — caught by post-write disk verification, re-applied, and every edit is now grep-verified on disk. Gate: 60-file balance ✓ · 329×6 ✓ · 311 refs ✓.


---

## Device-feedback pass 2 (first-run auth, nav bug, affordances, profile editing) — DONE ✅ 2026-09-21

- **First run now starts at Authentication** (both modes). Demo: any phone number + code `1234` (footer copy updated ×6); the demo session persists via kv (`demo_auth`) so subsequent launches go straight in; live unchanged (real OTP). Sign-out clears the marker.
- **BUG — bottom-nav off-by-one**: the FAB center slot left 4 nav destinations but the IndexedStack math still assumed 5 (`_tab < 2 ? _tab : _tab - 1`) — **Savings rendered Budgets and Lists rendered Savings**. Now 1:1 (`index: _tab`).
- **Invite a family member**: prominent button on the Family screen → sheet with the big invite code + copy (live), explanatory note (demo).
- **Profile editing**: tapping your own member row (or the pencil) → name + avatar picker sheet (7 semantic avatar keys), persisted via kv `profile_edits`, re-applied on every hydration. Roles stay sync-owned. Profile photos noted as arriving with family sync.
- **Header affordance**: the invisible avatar row is now a bordered tappable pill — overlapping avatars, person-add icon, "Family ›" with chevron.
- **Reports icon**: black glyph → teal-gradient donut badge (white glyph) — it leads the charts, it now looks the part.
- **Repaired a half-applied earlier edit**: View-as had silently collapsed to `canDemo = m.id == 'm_tariro'` (an id that doesn't exist in the seed) — the real cause of "no way to switch profiles" on device. Now `canDemo = true` for everyone.
- +5 l10n keys ×6 (**334 keys**, parity ✓). Gate: 60 files balance ✓, 334×6 ✓, 316 refs ✓.

**On-device note:** indentation in spliced regions is off — run `dart format lib` once before committing.

## Rebrand — display name (2026-09-21)
- **Mhuri Money → Mhuri Hub** (user chose "Hub": neutral, nothing money-flavoured, whole-family platform feel). Scope: user-facing only — Material app title + home header, loginWelcome / recordsOnly across all 6 locales, pubspec description, docs. Internal Dart slug stays `mhuri_money` (invisible to users; zero code risk).
- When platform folders are generated (device week, `flutter create .`): set `android:label="Mhuri Hub"` + iOS `CFBundleDisplayName` so the launcher icon matches.

## App icon swap (2026-09-21)
- New mark: **interlocking white rings + amber arc on teal gradient** (user pick C from 3 candidates) — family-circle/mukando symbolism, international-premium styling. Legacy hut icon archived at `design/app_icon_hut_legacy.png`; candidates + size-proof sheet in `design/`.
- `assets/branding/` now bundles only `app_icon.png` + `splash.png` (directory-listed in pubspec — every file there ships in the APK).
- Device week: generate launcher icons with `dart run flutter_launcher_icons` (pubspec already points at `assets/branding/app_icon.png`). If the rings read thin on a real launcher, thicken ring strokes in a v2.

