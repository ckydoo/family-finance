# Runbook — what to do on YOUR machine

You have the code (`mhuri-money/` with `app/` + `backend/`). Work top to bottom.
Paste me the output at every 📋 marker — I fix anything that flags, same session.

---

## Step 0 — Prerequisites (once)

1. Install Flutter SDK (latest **stable**): https://docs.flutter.dev/get-started/install
2. `flutter doctor` — resolve the red lines for **your** platform
   (Android toolchain is enough to start; Xcode only if building for iOS).
3. Put the project somewhere with **no spaces in the path**
   (`C:\dev\mhuri-money` ✅ · `C:\My Stuff\mhuri-money` ❌ — Flutter is picky).

---

## Step 1 — First boot (needs your Supabase connection — the app is live-only)

```bash
cd mhuri-money/app
flutter pub get        # also auto-runs flutter gen-l10n (generates lib/l10n/generated/)
flutter run
```

**Expect:** branded splash → **Login** (email + password). No seeded family —
the app boots empty until you sign up and create/join a family.

If you see a dark "setup needed" screen instead, the build has no Supabase
connection — see "GO LIVE ON A DEVICE" at the bottom for the three ways to
provide it.

Try after signing in: create a family → add an envelope → quick-add an
expense → switch language (Family tab → Settings) → Kids Mode (exit PIN
**1234** until a parent sets a real one) → Teen Zone.

📋 If `flutter gen-l10n` or anything here errors — paste me the full output.

---

## Step 2 — THE CHECKPOINT (this is the one that has never run)

```bash
flutter analyze
flutter test
```

**Expect:** analyze = 0 issues (or minor style lints — paste them anyway).
Tests = **101 passing**.

📋 Paste me both outputs in full. This unlocks: SCREENSHOTS regen, golden
tests, and the 9.5 rating step. Do not proceed to live mode before this.

---

## Step 3 — Branding generation (one-time)

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

**Expect:** launcher icon on your device/home screen; dark-mode launch has
**no white flash** (dark splash variant was added for this).

---

## Step 4 — Android notification tweaks (one-time)

In `android/app/build.gradle` (or `.kts`):

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

In `android/app/src/main/AndroidManifest.xml`, inside `<manifest>` (before
`<application>`):

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

Then Settings → Reminders → "Send a test notification" proves the chain.

---

## Step 5 — Go live (Supabase, ~15 min)

1. Create a project at supabase.com (free tier is fine).
2. **SQL Editor → New query → paste the whole of `backend/schema.sql` → Run.**
   Expect: success, no errors. (20 tables, RLS policies, triggers.)
3. **Project Settings → API**: copy the Project URL and the `anon` key.
4. In `app/`: `cp .env.example .env`, then fill in `SUPABASE_URL` and
   `SUPABASE_ANON_KEY`. The ignored file is already included under `assets:`
   in `pubspec.yaml`.
5. Auth is **email + password** (Supabase GoTrue, already wired). If
   signups demand confirmation, add an SMTP provider under
   Authentication → SMTP so the inbox mail actually arrives.
6. `flutter run` again — sign up and create your family.

📋 Paste me anything that errors — especially the SQL run and first login.

---

## Step 6 — The two-device proof (the real end-to-end)

Two phones (or phone + emulator), both running the app in live mode:

1. Phone A: Family tab → **Create family space** → note the invite code.
2. Phone B: login → **Join with code**.
3. Phone B: turn on airplane mode → quick-add an expense (snackbar says
   "Saved ✓ — works offline").
4. Phone B: airplane mode off → wait or tap **Sync now**.
5. Phone A: the expense appears. **That's the moat working.**

Also verify: kid claims chore on B → parent confirms on A → stars move.

---

## If something fails

- `flutter analyze` / `flutter test` output → paste to me (I fix same-session).
- gen-l10n complaints about an ARB → paste the exact error + Flutter version.
- SQL errors in Supabase → paste the message; do NOT hand-edit the schema.
- Never edit `lib/l10n/generated/*` — it regenerates on every build.

---

## GO LIVE ON A DEVICE

The app is live-only — there is no demo mode. It needs your Supabase
connection at build time; a build without one shows a setup error screen.
Two ways (pick one):

**Option A — .env asset (local development):** `cd app && cp .env.example
.env`, fill it in, then build. The file is already declared in pubspec and is
ignored by git.

**Option B — build flags:**
```
flutter run \
  --dart-define=MHURI_SUPABASE_URL=https://<your-ref>.supabase.co \
  --dart-define=MHURI_SUPABASE_ANON_KEY=<your-anon-key>
```

**Verify:** login screen appears (not a seeded family). Sign up with a real
email, create the family, record one transaction — then check Supabase →
Table Editor: the row is in the `transaction` table. Migrations 001–004 must
have run (004 = RLS, required for all pulls).

**Upgrading a phone that had old data?** Uninstall first (or clear storage);
if you can't, the first boot self-heals by wiping leftover local rows once
(`live_purged_v1` guard) and real adopted families are never touched.
