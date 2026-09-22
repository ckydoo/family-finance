# 🚀 START HERE — Run Mhuri Hub on your device

**Family finance management · live + offline-first · USD + ZiG · Envelopes ·
Savings circles · Shopping lists · Teen Zone · Kids Mode**

This folder contains everything: the product spec, UI mockups, the Flutter
app source, and the Supabase backend schema. The app is a real client of
your Supabase project — every account is a real login, every family is
shared across devices. There is no demo mode.

---

## 1. What you need (once)

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19+ → check with `flutter doctor`
- A phone with USB debugging enabled (**Android is easiest**) *or* an Android emulator / iOS simulator
- A Supabase project with the backend installed (see `backend/README.md` + run migrations `001`–`004`)
- Internet for the first `flutter pub get`

## 2. Connect it to your Supabase

1. **Local development:** copy `app/.env.example` to `app/.env` and fill in
   `SUPABASE_URL` and `SUPABASE_ANON_KEY`. The file is ignored by git and is
   already included in Flutter's asset list.
2. **CI/release build flags:**
   `flutter run --dart-define=MHURI_SUPABASE_URL=… --dart-define=MHURI_SUPABASE_ANON_KEY=…`

A build with neither source shows a setup error screen — it never runs
"offline pretend" mode.

## 3. Run it (3 commands)

```bash
cd mhuri-money/app

# One-time: generate the android/ios platform folders around this source
flutter create --project-name mhuri_money --platforms android,ios .

flutter pub get

# Plug in your phone (or start an emulator), then:
flutter run
```

Run the tests too (they build their own local data; nothing external):

```bash
flutter test
```

> If `flutter analyze` reports anything on your Flutter version, paste the
> output back to me and I'll fix it — different Flutter versions occasionally
> have small API differences.

## 4. First real run

| # | Do this | You'll see |
|---|---|---|
| 1 | Open the app | **Login** — create an account (email + password, confirm via inbox) |
| 2 | Family setup | **Create a family** (you're the owner) or **join with a code** from the owner |
| 3 | Add a real envelope | Budgets → new envelope, e.g. *Groceries* |
| 4 | Tap the amber **＋** | Quick add → real amount in **USD or ZiG** → pick envelope → Save |
| 5 | Second phone, second account | Join with the code → same family, same envelopes, same budget truth |
| 6 | **Lists** → tick items → **Finish shopping** | One expense posted to the Groceries envelope |
| 7 | Settings → **Language** | English, chiShona, isiNdebele, Español, Français, Português |

Kids Mode exit PIN: factory default `1234` until a parent sets a real one
(Family → kid profile).

## 5. What's in this folder

```
mhuri-money/
├── START_HERE.md          ← you are here
├── PRODUCT_SPEC.md        full product specification (16 sections)
├── ROADMAP_TO_8.md        the build-here plan to a ~8/10 product (milestones M0–M8)
├── mockups/               5 high-fidelity concept screens
├── app/                   the Flutter app (run this)
│   ├── lib/               ~5,500 lines of Dart
│   ├── test/              money rules, sync, persistence + screen smoke tests
│   └── README.md          deep dive: structure, spec-traceability, next steps
└── backend/
    ├── schema.sql         Supabase schema — 21 tables, role-based row security
    └── README.md          10-minute backend setup
```

## 6. Current limitations (by design)

- Reminders are device-local (bills, budgets, kids, goals, savings circle, meeting, weekly digest — set them up in Settings); server push comes later
- Receipts/OCR & PDF share: post-8 backlog · recurring expenses are review-based by design
- Accounts are device-local "records only" per spec §5
- FX rate: server snapshot (run migration 004 + seed a `rate_snapshot` row) or a custom rate in Settings
- Translations would love a native-speaker review

Everything else on the roadmap is in `PRODUCT_SPEC.md` §11.
