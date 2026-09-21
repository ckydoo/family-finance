# 🚀 START HERE — Run Mhuri Hub on your device

**Family finance management · offline-first demo · USD + ZiG · Envelopes ·
Savings circles · Shopping lists · Teen Zone · Kids Mode**

This folder contains everything: the product spec, UI mockups, the Flutter
app source, and the Supabase backend schema.

---

## 1. What you need (once)

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.19+ → check with `flutter doctor`
- A phone with USB debugging enabled (**Android is easiest**) *or* an Android emulator / iOS simulator
- Internet for the first `flutter pub get`

## 2. Run it (3 commands)

```bash
cd mhuri-money/app

# One-time: generate the android/ios platform folders around this source
flutter create --project-name mhuri_money --platforms android,ios .

flutter pub get

# Plug in your phone (or start an emulator), then:
flutter run
```

Run the tests too (should pass: money rules + boot smoke test):

```bash
flutter test
```

> If `flutter analyze` reports anything on your Flutter version, paste the
> output back to me and I'll fix it — different Flutter versions occasionally
> have small API differences.

## 3. The 5-minute demo script

| # | Do this | You'll see |
|---|---|---|
| 1 | Open the app | **Home** — Family Pool in USD & ZiG, safe-to-spend, envelope chips |
| 2 | Tap **⇄** on the pool card | Display currency swaps USD ⇄ ZiG |
| 3 | **Budgets** tab → open *Transport* | Envelope detail → **Move money** from Emergency buffer, give a reason |
| 4 | Tap the amber **＋** button | Quick add → type an amount in **ZiG** → see ≈ USD preview → pick envelope → Save |
| 5 | Look at Home again | "⏳ 1 change waiting to sync" banner → tap it to "sync" (offline-first demo) |
| 6 | **Lists** tab → tick items → **Finish shopping** | The checked items become one expense; the Groceries envelope bar jumps |
| 7 | **Savings** tab | Goals with rings + **Savings circle — Round 4 of 8** card → "Mark this round collected" |
| 8 | Tap the 📊 icon (top right) | **Report card** — envelope health ring, cash-leak %, where money went |
| 9 | Tap the **avatar stack → Family** | Members & roles. Tap **View as → Zoe** (teen) |
| 10 | Teen Zone | 50% savings match, earnings chart → **Log earning**, then **Propose expense** |
| 11 | Back to Family → **View as → Leo** (kid) | Sealed **Kids Mode** (yellow) — do a chore, then **Ask Mom/Dad for money** |
| 12 | Family → View as → David, enter PIN **1234** | The Home **smart card** now shows the requests → **Approve** both |
| 13 | Family → **Language** → chiShona | Reopen Teen Zone / Report card → translated labels (demo scope) |

**Demo PIN to exit Kids Mode: `1234`**

## 4. What's in this folder

```
mhuri-money/
├── START_HERE.md          ← you are here
├── PRODUCT_SPEC.md        full product specification (16 sections)
├── ROADMAP_TO_8.md        the build-here plan to a ~8/10 product (milestones M0–M8)
├── mockups/               5 high-fidelity concept screens
├── app/                   the Flutter app (run this)
│   ├── lib/               ~5,500 lines of Dart
│   ├── test/              money rules + boot smoke test
│   └── README.md          deep dive: structure, spec-traceability, next steps
└── backend/
    ├── schema.sql         Supabase schema — 21 tables, role-based row security
    └── README.md          10-minute backend setup (when you're ready to sync)
```

## 5. Known demo limitations (by design — Phase 1 not started)

- Data **persists on-device** (M1 ✅); login + `.env` live-mode (M2 ✅); **two-phone family sync is built (M3 ✅)** — activate by running the two SQL files on Supabase + filling `.env` (see `backend/README.md`)
- One shared demo family; "View as" simulates the other members
- Reminders are device-local (bills, budgets, kids, goals, savings circle, meeting, weekly digest — set them up in Settings); server push comes later · receipts/OCR & PDF share: post-8 backlog · recurring expenses are review-based by design
- The app speaks 6 languages — English, chiShona, isiNdebele, Español, Français, Português. Change it in Settings (⚙ on the Family tab). Translations would love a native-speaker review.

Everything else on the roadmap is in `PRODUCT_SPEC.md` §11.
