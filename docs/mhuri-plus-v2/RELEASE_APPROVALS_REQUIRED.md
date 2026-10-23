# Release Approvals Required — Mhuri Plus v2

**Date:** 2026-10-22  
**Target:** linked Supabase production project  
**Status:** production release blocked pending the approvals and evidence below.

## 1. Migration ledger reconciliation and staging rehearsal

Approval is required to inspect and reconcile the empty linked migration ledger. Before production, rehearse the complete effective migration chain in an isolated environment and capture schema/RLS tests. Do not blindly mark migrations as applied.

## 2. Apply migrations `051` and `052`

After reconciliation and rehearsal, approve a reviewed production apply:

- `051_post_050_security_and_entitlement_alignment.sql` fixes personal-account read/write and transaction-split privacy, removes the legacy push trigger, tightens grants, and adds commitment sync timestamps.
- `052_plus_commitment_write_authorization.sql` requires active `smart_commitments` entitlement for commitment, occurrence, and payment writes while preserving member read access to existing records.

Back up and capture pre/post policy definitions before applying.

## 3. Deploy entitlement functions

Approve deployment and smoke testing of `verify-family-entitlement` and `google-play-rtdn`. Confirm required secrets and service-account permissions without exposing secret values.

## 4. Google Play licensed testing

Approve/configure products `mhuri_plus_monthly` and `mhuri_plus_annual`, then verify purchase, acknowledgement, family propagation, renewal, grace period, hold, cancellation, expiry, restore, and RTDN delivery on a physical Android device with a license tester.

## 5. Release candidate and publication

Only after the preceding gates pass: review and commit the branch, build the billing-enabled candidate, complete final device smoke tests, and separately approve track upload/promotion. Billing enablement and publication are not authorized by this document.
