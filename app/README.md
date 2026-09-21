# Mhuri Hub — Flutter MVP Scaffold

**Family finance management for every kind of family** · offline-first demo ·
USD + ZiG dual-currency · envelopes · goals & savings circles · shared shopping lists ·
sealed Kids Mode.

> Companion docs: see `../PRODUCT_SPEC.md` (full product specification) and
> `../mockups/` (high-fidelity concept screens this UI follows).

---

## What this is

A **runnable Phase-0 scaffold** of the product spec: the full adult app shell,
Kids Mode, and the core money flows, running on **in-memory demo data** (the
David & Maya family, international personas). Backend sync (Drift + Supabase)
is intentionally not wired yet — the state layer is isolated in
`lib/core/state/app_state.dart` so it can be swapped for Riverpod + Drift
without touching feature code.

### Implemented from the spec

| Spec module | Status in this scaffold |
|---|---|
| A — Family Space & roles | ✅ role-based routing (owner/adult → adult app, **teen → Teen Zone**, kid → Kids Mode), "View as" demo switcher, invite code |
| B — Income | ✅ income transactions, mixed USD/ZiG |
| C — Expenses | ✅ quick add (< 8s flow), currency toggle + live conversion, payment-method tags (mobile money, cash, bank…), member attribution |
| D — Budgets (envelopes) | ✅ envelope cards with pace (on track / watch / reached), summary bar, **move money with reason**, personal (🔒) envelopes, rollover labels, mixed-currency envelope (ZiG limit) |
| E — Savings & circles | ✅ goals with progress rings + contributions, kid jars + teen jar, savings-circle (ROSCA) rotation tracker (records only) |
| F — Shopping lists | ✅ shared list, states (to buy / in cart / done), dual-currency estimate, budget-check vs envelope, **finish → log expense** loop |
| G — Kids Mode | ✅ sealed shell: jar, stars, chores (claim → parent confirms), wish list, **ask-parent approval flow**, PIN exit (demo PIN `1234`) |
| H — Teen Zone | ✅ own jar with **50% savings match**, earnings log + bar chart, **expense proposals → parents' pending queue**, read-only envelope peek, spend/save/give plan |
| I — Reports | 🟡 **report card** (income vs spent, saved, envelope-health ring, cash-leak %, top envelopes) — share-as-PDF in Phase 2 |
| J — Sync/settings | 🟡 demo only: "waiting to sync" outbox banner; language picker (EN / chiShona / isiNdebele) live on Teen Zone & Report labels; full gen-l10n rollout in Phase 2 |
| Persistence (M1) | ✅ **local SQLite (sqflite, zero-codegen)** — every mutation writes through; app restarts keep all data; fails soft to demo mode |
| Auth & env (M2) | ✅ `.env` demo/live contract, phone-OTP login (hand-written GoTrue REST), session restore, hashed PINs, login gate — live only when `.env` says so |
| Sync (M3) | ✅ outbox + pull-cursor engine (hand-written PostgREST), family create/join by invite code, live mutation queues, Home sync banner is real — server SQL in `../backend/migrations/` |
| Completeness (M4) | ✅ onboarding, recurring expenses with Post/Skip review, payday-aligned cycles + rollover carry math, Family Meeting screen, CSV export, empty/loading states |
| Notifications (M5) | ✅ device-local reminders: bills 3-day, envelope 80%/empty, kid requests, savings-circle Sunday, goal milestones, meeting eve, Sunday digest — quiet hours + per-category prefs in Settings |
| Quality wall (M7) | ✅ 5 core flows as tests, widget tests per screen, sync backoff + parked-batch recovery, error hook, icon/splash branding |
| International (M6) | ✅ 6 languages (EN/SN/ND/ES/FR/PT) via gen-l10n, language picker, elder large-text mode |
| Backend | 🟡 `../backend/schema.sql` — runnable Supabase schema (20 tables, RLS roles, rate snapshots, activity log); app wiring is the next milestone |

### The 5-minute demo script

1. **Home** — Family Pool in USD & ZiG (tap ⇄ to swap), safe-to-spend,
   envelope chips, recent activity; the 📊 header icon opens the **Report
   card** (envelope health, cash leak, where the money went).
2. **Budgets** — open *Transport* (amber "Watch") → **Move money** from
   *Emergency buffer* with a reason → watch the bars update.
3. Tap **＋** → quick add an expense in **ZiG** (see the ≈ USD preview) →
   note the "waiting to sync" banner → tap it to "sync".
4. **Lists** — tick items → **Finish shopping → log expense** → the Groceries
   envelope jumps.
5. **Savings** — add a contribution to *School Fees — Term 2*; check the
   savings-circle card (Round 4 of 8 — David collects).
6. **Family → View as Zoe (teen)** — **Teen Zone**: see the 50% savings
   match, **log an earning**, then **propose an expense** ($15 movie night).
7. **Family → View as Leo** — sealed **Kids Mode** (yellow). Do a chore,
   then **Ask Mom/Dad for money**.
8. Back as **David** (PIN `1234`): the **smart card** on Home now shows the
   kid request / teen proposal → **Approve** → the request lands in Leo's
   jar; the proposal is logged to the family budget.
9. **Family → Language** — switch to *chiShona* or *isiNdebele* and reopen
   the Teen Zone / Report card to see translated labels (demo scope).

## Design system (typography & theme)

The app uses **Poppins** (bundled in `assets/fonts/poppins/`, SIL OFL
license included) as its app-wide font, with a full Material 3 theme in
`lib/core/theme/app_theme.dart`: type scale, stadium buttons, rounded
inputs with focus rings, 24-radius cards, 28-radius sheets with drag
handles, rounded snackbars, and platform page transitions (Cupertino on
iOS, Zoom on Android). Design tokens (`kRadius*`, `kHairline`,
`kCardShadow`, wash colors) keep new screens coherent — prefer them over
ad-hoc values.

**Icons:** the UI uses Material icons everywhere. Visual entities carry a
stable SEMANTIC icon key in the data layer — `'cart'`, `'school'`,
`'fuel'`, `'man'`, `'bank'`, `'autorenew'`… — never an emoji
(`core/widgets/app_icons.dart` is the single key→icon map; use
`iconForKey(...)` / `AppIconBadge`, never render `thing.emoji` raw).
Emojis exist only in OS-notification text (they render in the system tray,
outside the app) and `→`/`✓` text glyphs.

## Internationalization (M6)

Six languages ship in `lib/l10n/app_*.arb`: English, chiShona, isiNdebele,
Español, Français, Português. `flutter gen-l10n` runs automatically on
`flutter pub get` / `flutter run` / `flutter test` (it is wired via
`generate: true` in pubspec + `l10n.yaml`), generating into
`lib/l10n/generated/`. Users switch language in Settings (⚙ on the Family
tab); the choice persists.

**To add a language** (e.g. Swahili):
1. Copy `lib/l10n/app_en.arb` → `app_sw.arb`, set `"@@locale": "sw"`, translate.
2. Add `'sw': 'Kiswahili'` to `kLanguageNames` in `lib/core/l10n/app_strings.dart`.
3. Run the app — done. The language picker and locale routing pick it up.

Note: if `flutter gen-l10n` on your Flutter version complains about the
`synthetic-package` option in `l10n.yaml`, simply delete that one line —
newer toolchains generate real files by default.

## Branding (one-time, after `flutter create`)

The icon and splash artwork already live in `assets/branding/` and are
wired in `pubspec.yaml` — generate the platform launcher icons and native
splash with:

```
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
(The splash now has a dark variant — regenerating also removes the white launch flash in dark mode.)

```
```

## Notifications on Android (one-time, after `flutter create`)

flutter_local_notifications v22 needs two tweaks in `android/app/build.gradle`
(or `.kts`): enable **desugaring** and add the desugar library —

```gradle
android {
    defaultConfig { multiDexEnabled true }
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
}
dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

…and in `android/app/src/main/AndroidManifest.xml`, inside `<manifest>`
(before `<application>`), add the boot-reschedule permission (the plugin
already ships `POST_NOTIFICATIONS` + `VIBRATE` itself):

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Exact alarms are NOT used (inexact `inexactAllowWhileIdle` mode), so no
`SCHEDULE_EXACT_ALARM` permission is needed. iOS needs no manifest edits —
the permission prompt appears on first init.

## Run it

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.19+ recommended, Dart 3).

```bash
cd mhuri-money/app

# Generate the android/ios platform folders around this source tree:
flutter create --project-name mhuri_money --platforms android,ios .

flutter pub get
flutter run
```

Run the unit tests (money math, conversion rules):

```bash
flutter test
```

## Project structure

```
lib/
  main.dart                    entry point
  app.dart                     MaterialApp + role gate (adult vs Kids Mode)
  core/
    theme/app_theme.dart       design tokens (teal #0E7C66, amber #F4A81D…)
    money/money.dart           Money (integer minor units) + USD/ZiG conversion
    models/models.dart         Member, Envelope, Tx, Goal, SavingsCircle, Chore…
    data/seed_data.dart        the demo family (personas from the spec)
    state/app_state.dart       AppState + AppScope (swap for Riverpod later)
    utils/when.dart            date formatting ("Today, 10:15 AM")
    widgets/                   TxTile, RingProgress
    db/app_database.dart       local SQLite schema (hand-written, no codegen)
    db/persistence.dart        mappers + seed/load/upserts for every entity
    config/app_env.dart        .env parser — demo vs live mode contract
    auth/auth_service.dart     interface + demo auth (code 1234)
    auth/supabase_auth_service.dart  hand-written GoTrue REST client (OTP)
    auth/auth_controller.dart  session lifecycle for the UI
    auth/pin_store.dart        salted SHA-256 PINs (Kids Mode exit, profiles)
    sync/sync_mappers.dart     7-entity domain ↔ server JSON registry
    sync/outbox.dart           ordered idempotent mutation queue
    sync/supabase_sync_client.dart  PostgREST upsert/cursor pull/rpc (no SDK)
    sync/sync_engine.dart      push→pull→apply; bootstrap; statuses; timer
    widgets/empty_state.dart   shared friendly empty states
    features/onboarding/       3-slide first run (live only, skippable)
    features/meeting/          guided Family Meeting agenda
    features/budgets/recurring_ui.dart  recurring rules: rows + add sheet
    core/notifications/reminders.dart   pure reminder planner (J2/J3) — tested
    core/notifications/notifier.dart    flutter_local_notifications bridge
    features/settings/                  Settings: notifications, quiet hours,
                                        month-start day, CSV export
    assets/branding/                    app icon + splash art (M7)
    l10n/                               ARB translations (6 languages) + l10n.yaml
    l10n/generated/                     gen-l10n output (auto-built, do not edit)
  features/
    shell/adult_shell.dart     bottom nav: Home · Budgets · (＋) · Savings · Lists
    home/home_screen.dart      pool card, envelope chips, activity, smart card
    budgets/budgets_screen.dart
    savings/savings_screen.dart
    lists/lists_screen.dart
    activity/activity_screen.dart
    members/members_screen.dart (roles, View as, language picker)
    quickadd/quick_add_sheet.dart
    teen/teen_zone.dart        teen jar, match, earnings chart, proposals
    reports/reports_screen.dart  monthly report card
    kids/kids_mode.dart
  core/l10n/app_strings.dart   EN/SN/ND demo strings (→ gen-l10n in Phase 2)
test/
  money_test.dart              currency & conversion rules
  widget_test.dart             app boots to adult Home
  persistence_test.dart        M1 restart-roundtrip (needs SQLite on host)
  env_test.dart                .env parsing & demo/live fallback rules
  auth_test.dart               demo auth, GoTrue REST (FakeClient), PINs
  sync_test.dart               M3: mappers, outbox, engine push/pull, spaces
  m4_test.dart                 cycles, rollover carry, recurring, onboarding
  notify_test.dart             reminder planner: bills, budget, kids, quiet hours
  flows_test.dart              the 5 core demo flows, end to end (M7)
  widget_screen_test.dart      every main screen pumps + key content (M7)
  reliability_test.dart        sync backoff, parked batches, error hook (M7)
  strings_test.dart            ARB parity (6 languages) + locale switching (M6)
```

Companion: `../backend/` — Supabase `schema.sql` (runnable) + setup guide.

## Key invariants implemented (keep these!)

- **Never floats for money.** All amounts are `Money` = integer minor units +
  currency (`lib/core/money/money.dart`).
- **No silent conversion.** A transaction stays in the currency it happened
  in; conversions are display-only and always shown with the rate
  (`rateLabel`). Historical reports must snapshot the rate (Phase 1).
- **The savings-circle tracker never holds money** — it is a records-only tool.
- **Kids Mode is sealed**: no family balances, all spending is request-based,
  exit is PIN-gated.

## Next steps (Phase 1 → spec §11)

1. ~~Local persistence~~ ✅ done in M1 (sqflite, hand-written schema).
2. Next up (M3): **outbox queue + sync engine** (spec §9.2) → **Supabase**
   (PostgreSQL schema in spec §8, row-level security keyed on membership).
3. Auth: phone OTP for adults, profile-PIN for kids on a parent device.
4. Add EN/SN/ND `.arb` files under `lib/l10n/` and enable `flutter gen-l10n`.
5. Golden tests for the core screens; then the 30-family closed beta.
