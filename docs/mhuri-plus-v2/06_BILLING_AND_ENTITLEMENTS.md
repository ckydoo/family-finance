# Billing & Entitlements — Mhuri Plus v2

**Date:** 2026-10-22  
**Branch:** `codex/mhuri-plus-v2`  
**Default Public Billing Flag:** `MHURI_BILLING_ENABLED = false` (Compile-time `--dart-define`)

---

## 1. Subscription Model & Pricing Display

- **Plans:**
  - Monthly (`mhuri_plus_monthly`): Proposed reference price **$2.99 / month**
  - Annual (`mhuri_plus_annual`): Proposed reference price **$24.99 / year**
- **Free Trial:** None (`No free trial` explicitly disclosed in UI).
- **Family Coverage:** One Mhuri Plus subscription covers one family (`space`). All members of that family receive Plus feature access while the family entitlement is active.
- **Play Store Price Authority:**
  - `BillingService` queries `InAppPurchase.instance.queryProductDetails({'mhuri_plus_monthly', 'mhuri_plus_annual'})`.
  - When live Google Play `ProductDetails` are returned, actual localized checkout prices (`ProductDetails.price`) are displayed on the plan cards.
  - When billing is disabled (`MHURI_BILLING_ENABLED=false`) or Play Store products are not yet loaded, the UI clearly labels `$2.99/month` and `$24.99/year` as reference prices (`Actual checkout price comes from Google Play`).

---

## 2. Verified Feature Keys (`kPlusV2Features`)

Both `supabase/functions/verify-family-entitlement/index.ts`, `supabase/functions/google-play-rtdn/index.ts`, and `app/lib/core/billing/entitlement.dart` grant and verify the following 11 feature keys for `mhuri_plus`:

1. `smart_commitments` — Smart Bills & Commitments (schedules, occurrences, partial payment linking, multi-day reminders)
2. `cash_flow_forecast` — Payday-to-Payday Planner & What-If Scenarios
3. `period_preparation` — Automated Preview-First Period Preparation
4. `financial_health` — Evidence-Backed Financial Health Check
5. `savings_projections` — Advanced Savings Contribution Schedules
6. `debt_planning` — Debt Payoff Scenarios & Comparisons
7. `family_polls_pins` — Family Chat Polls and Pinned Messages
8. `advanced_chat_search` — Family Chat Advanced Search & Filters
9. `enhanced_family_chat` — Photos, emoji/stickers, message editing, and task/budget/shopping references. Family text chat, replies, and deleting your own messages stay free.
9. `advanced_insights` — Advanced insight surfaces
10. `advanced_reports` — Advanced reports
11. `enhanced_reports` — Enhanced report surfaces

---

## 3. Lifecycle & Edge Function Hardening

### `verify-family-entitlement` (`supabase/functions/verify-family-entitlement/index.ts`)
- **Action `status`:** Returns the current `family_entitlement` row for `familyId` after verifying the caller is a member of `space_member`.
- **Action `verify` / `restore`:**
  - Authenticates caller JWT and verifies family membership.
  - Validates `productId` (`mhuri_plus_monthly` or `mhuri_plus_annual`) and `purchaseToken` against Google Play Developer API (`purchases.subscriptionsv2.get`).
  - Maps Google Play subscription states (`SUBSCRIPTION_STATE_ACTIVE`, `SUBSCRIPTION_STATE_IN_GRACE_PERIOD`, `SUBSCRIPTION_STATE_ON_HOLD`, `SUBSCRIPTION_STATE_PAUSED`, `SUBSCRIPTION_STATE_CANCELED`, `SUBSCRIPTION_STATE_EXPIRED`) to Mhuri `EntitlementStatus`.
  - **Same-family renewal & expired token re-use:** Blocks cross-family purchase token hijacking while permitting a family to re-subscribe if an earlier verification row in another family is already `expired`, `revoked`, or `rejected`.
  - Acknowleges unacknowledged Google Play subscriptions when active/in-grace.

### `google-play-rtdn` (`supabase/functions/google-play-rtdn/index.ts`)
- Processes real-time developer notifications from Google Cloud Pub/Sub.
- Authenticates via `GOOGLE_PLAY_RTDN_TOKEN` or Google OIDC JWT (`GOOGLE_PLAY_RTDN_OIDC_AUDIENCE`).
- Re-queries Google Play Developer API for authoritative subscription state and updates `billing_purchase_verification` and `family_entitlement`.

---

## 4. Client Lifecycle States & Offline Resilience (`plus_screen.dart` & `app_state.dart`)

- **Lifecycle Banners (`_LifecycleBanner` in `app/lib/features/settings/plus_screen.dart`):**
  - Displays clear, actionable banners for `grace` (payment issue — grace period active), `onHold` (account on hold — Plus paused), `paused` (subscription paused), `cancelled` (cancelled — active until expiry date), `expired`, and `revoked`.
- **Offline Snapshot Indicator:**
  - When operating from the 72-hour bounded offline entitlement snapshot (`entitlement.isOfflineSnapshot == true`), `PlusScreen` displays an informational offline verification badge showing when the entitlement was last verified.
  - Offline snapshots are read-only. `canWritePlusFeature` rejects premium mutations until the server entitlement is verified again; migration `052` provides matching database enforcement for commitment writes once approved and applied.
- **Free vs. Plus Transparency (`_PlanComparisonCard`):**
  - Explicitly lists permanently Free capabilities alongside Mhuri Plus v2 capabilities so users know existing features are never removed.

