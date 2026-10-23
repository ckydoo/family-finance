# Security & RLS Status — Mhuri Plus v2

**Date:** 2026-10-22  
**Scope:** read-only linked-project inspection plus local forward migrations

## Observed linked state

| Area | Observed state | Release status |
|---|---|---|
| Family isolation and membership checks | Existing role-based RLS present | Requires final post-migration regression |
| Chat polls, pins, and search | Migration `050` hardening functions present; premium RPCs check server entitlement | Implemented live |
| Personal account privacy | Old predicate still treats only `personal` as private although valid schema value is `private` | **Blocked until `051`** |
| Personal account writes | `account_personal_write_privacy` absent | **Blocked until `051`** |
| Private transaction splits | `tx_split_personal_account_privacy` absent | **Blocked until `051`** |
| Commitment reads | Active family members can read existing records | Intended |
| Commitment writes | Non-viewer role required, but no active Plus feature check | **Blocked until `052`** |
| Migration provenance | Linked migration ledger returned empty | **Reconciliation required** |

## Intended state after approved migrations

- `051_post_050_security_and_entitlement_alignment.sql` aligns personal-account reads and writes with `sharing = 'private'`, protects transaction splits, removes the deprecated push trigger, tightens grants, and adds commitment sync timestamps.
- `052_plus_commitment_write_authorization.sql` retains family-member reads but requires both a non-viewer role and current server-owned `smart_commitments` entitlement for commitment, occurrence, and payment writes.
- `family_entitlement` remains client read-only; trusted backend functions own entitlement mutations.

## Required verification after apply

Run authenticated role tests for owner, adult, viewer, removed member, cross-family member, and anonymous access. Cover private account read/write, private transaction and split visibility, commitment reads after entitlement expiry, and rejection of commitment writes for Free/expired/missing-feature families. Capture all policy definitions and results.

No migration was applied as part of this audit, so proposed `051`/`052` behavior must not be described as live.
