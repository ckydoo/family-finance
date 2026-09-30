# Google sign-in and notifications setup

The app-side integration is complete. These dashboard settings are still
required for each Supabase environment.

## Google sign-in

1. In Google Cloud, configure the OAuth consent screen and create a **Web
   application** OAuth client.
2. Add this authorized redirect URI, replacing the project reference:
   `https://<project-ref>.supabase.co/auth/v1/callback`.
3. In Supabase Dashboard, open **Authentication > Providers > Google**, enable
   Google, and paste the Google client ID and client secret.
4. In **Authentication > URL Configuration > Redirect URLs**, add
   `mhuri://auth-callback` (keep `mhuri://reset-callback` for password reset).
5. Ensure `mhuri` remains registered as a URL scheme in both native runners.

The mobile app opens Supabase's `/auth/v1/authorize?provider=google` endpoint.
Supabase completes Google OAuth and returns the session to
`mhuri://auth-callback`; the app validates that callback and stores the session
using the same local token store as email/password authentication.

## Local notifications

No Firebase project is needed for the current device-local reminders. Android
13+ and iOS ask for notification permission when reminders are enabled.
Android is configured to restore scheduled reminders after reboot or app
update. Verify on a physical device from **Settings > Send a test
notification**; simulators may not match production permission behavior.

`FCM_PROJECT_ID` is reserved for future server-push notifications and is not
used by the current local reminder feature.
