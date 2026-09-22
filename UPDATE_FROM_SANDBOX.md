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
- App is live-only: config via ignored `.env` asset or CI dart-defines; no connection → setup error screen (never offline fiction).
- First-boot legacy purge kept (`live_purged_v1`), no longer gated on env.
- Tests: added `test/fake_auth.dart` + `test/seed.dart` (explicit test-only baseline); rewrote env/auth/onboarding/widget/persistence/flows/m4/sync tests for the live-only reality (lib_boot 9 tests; zero `DemoAuthService`/`seed_data` refs).
