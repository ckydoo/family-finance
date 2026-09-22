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

