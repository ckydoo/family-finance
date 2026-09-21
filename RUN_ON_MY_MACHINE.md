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

## Step 1 — First boot, demo mode (no accounts, no internet needed)

```bash
cd mhuri-money/app
flutter pub get        # also auto-runs flutter gen-l10n (generates lib/l10n/generated/)
flutter run
```

**Expect:** branded splash → the seeded demo family (Taylor) → Home with
envelopes, smart cards, stars. No login screen — demo never logs in.

Try: quick-add an expense → pull-to-refresh → switch language (Family tab →
Settings → language row) → Kids Mode (exit PIN **1234**) → Teen Zone.

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
4. In `app/`:
   - `cp .env.example .env` and fill in:
     ```
     APP_ENV=live
     SUPABASE_URL=https://xxxx.supabase.co
     SUPABASE_ANON_KEY=eyJ...
     ```
   - `pubspec.yaml`: **uncomment** the `- .env` line under `assets:`
     (it is commented on purpose for demo mode).
5. Phone login: Supabase Dashboard → **Authentication → Providers → Phone**.
   For real SMS you add a Twilio/MessageBird account; Supabase's built-in
   test provider works for first smoke tests (rate-limited).
6. `flutter run` again — you should now get the **phone login screen**.

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
