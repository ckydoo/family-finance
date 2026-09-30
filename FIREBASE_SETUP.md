# Firebase Messaging and Analytics deployment

The client and Supabase push pipeline are implemented, but Firebase must be
connected with environment-specific credentials before they activate.

## 1. Create and connect Firebase apps

1. Create/select a Firebase project and enable Google Analytics.
2. From `app/`, install the CLIs if needed and run `flutterfire configure`.
3. Select Android and iOS. Use the existing identifiers:
   - Android package: `com.codzlabzim.mhuri`
   - iOS bundle ID: `com.codzlabzim.mhuri`
4. Put `google-services.json` at `app/android/app/google-services.json`.
5. Add `GoogleService-Info.plist` to the iOS Runner target in Xcode (enable
   "Copy items if needed").
6. In Xcode, Runner > Signing & Capabilities, add **Push Notifications** and
   **Background Modes > Remote notifications**.
7. In Firebase Console > Project settings > Cloud Messaging, upload an APNs
   authentication key for the iOS app.

This repository initializes the native default Firebase app. The Android
Google Services Gradle plugin activates automatically when
`google-services.json` exists.

## 2. Apply the token table

Apply `backend/migrations/018_push_devices.sql` to staging first, then
production. Signed-in clients can write only their own token. Only the service
role used by the Edge Function can read tokens.

## 3. Configure and deploy the sender

1. Firebase Console > Project settings > Service accounts > Generate new
   private key.
2. Never add that JSON file to the app or Git. Store the entire compact JSON as
   a Supabase secret:

   ```sh
   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='<one-line-json>'
   supabase secrets set PUSH_WEBHOOK_SECRET='<long-random-value>'
   ```

3. Deploy the function without JWT verification; database webhooks have no user
   JWT and the function authenticates the custom secret header:

   ```sh
   supabase functions deploy send-family-push --no-verify-jwt
   ```

## 4. Create the database webhook

In Supabase Dashboard > Database > Webhooks:

- Name: `important-family-push`
- Table: `activity_log`
- Event: `INSERT`
- Method: `POST`
- URL: `https://<project-ref>.supabase.co/functions/v1/send-family-push`
- Header: `x-webhook-secret: <the same PUSH_WEBHOOK_SECRET>`

The sender currently handles `tx.create`, `goal.contribute`, `request.create`,
`request.approve`, and `request.decline`. It excludes the actor for shared
family events and targets the requester for request decisions. Notification
copy intentionally contains no amounts, balances, names, or other sensitive
lock-screen data.

## 5. Test

Use two real devices signed into two members of one staging family. Enable
notifications in Mhuri Settings, then create a transaction on device A. Device
B should receive the push. Use Firebase Analytics DebugView to confirm
`screen_view`, `login`, `push_received`, and `push_open` events. Analytics can
take hours to appear in standard reports.

FCM sending uses the HTTP v1 API and a server-held service account. Never send
FCM messages directly from Flutter and never ship the service-account key.
