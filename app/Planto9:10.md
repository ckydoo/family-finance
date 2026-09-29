## Plan to reach a genuine 9/10

The app’s foundation is solid. What remains is mostly production hardening, consistency, and proving that every workflow survives real-world use.

### Phase 1 - Make CI completely green

Goal: establish a clean baseline before adding more features.

- Reduce `flutter analyze` from roughly 102 warnings/info to zero.
- Fix every `use_build_context_synchronously` warning, prioritizing dialogs and bottom sheets.
- Remove unused imports, dead code, and avoidable non-`const` widgets.
- Complete the missing Spanish, Ndebele, Portuguese, and Shona translations.
- Run:
  - `flutter analyze --fatal-infos`
  - complete Flutter test suite
  - Android release build
  - iOS simulator build
- Prevent merging when any check fails.

Deliverable: one reproducible, fully green CI pipeline.

### Phase 2 - Finish the critical money workflows

Goal: guarantee financial correctness and prevent duplicate actions.

- Make all money mutations idempotent:
  - add transaction
  - shopping checkout
  - savings contribution
  - transfer between envelopes
  - approve/decline requests
  - Mukando collection
- Disable submit buttons immediately after the first tap and show progress.
- Add server-side idempotency keys and unique constraints.
- Wrap related financial writes in database transactions.
- Enforce envelope limits on the backend as well as in the UI.
- Define a clear overspend policy:
  - warn and require confirmation, or
  - block based on family settings.
- Recalculate Family Pool from one authoritative ledger source.
- Add reconciliation tests proving balances equal all accepted ledger entries.
- Ensure offline retries cannot create duplicates.

Deliverable: balances remain correct through retries, double taps, restarts, and offline recovery.

### Phase 3 - Complete account and family lifecycle

Goal: make every account state recoverable and understandable.

- Verify the entire path:
  - create account
  - confirm email
  - sign in
  - forgot/reset password
  - create family
  - invite/join family
  - restart and restore session
  - leave family
  - transfer ownership
  - log out
  - delete account
- Add a dedicated “Check your email” confirmation screen with resend and change-email actions.
- Unify onboarding invitations with the main invitation system.
- Enforce invite expiry, single use, revocation, intended recipient, and role assignment server-side.
- Require ownership transfer or explicit family deletion before an owner can leave.
- Add reauthentication before account deletion.
- Clearly explain what deletion removes, anonymizes, or preserves.
- Test expired links, revoked invites, deleted users, removed members, and restored sessions.

Deliverable: no dead end between first launch and permanent account deletion.

### Phase 4 - Prove permissions and security

Goal: ensure permissions are real enforcement, not only hidden buttons.

Create an automated role matrix for:

- Owner
- Admin
- Parent
- Teen
- Child
- Viewer

Test each role against:

- balances
- budgets
- transactions
- savings
- lists
- invites
- member management
- settings
- audit history
- account/family deletion

Then:

- Deny unauthorized operations in database policies and RPCs.
- Validate all financial values and roles server-side.
- Ensure profile preview never grants the previewed member’s permissions.
- Add rate limiting for authentication, invitations, and sensitive actions.
- Rotate any credentials that were previously pasted or committed.
- Confirm `.env` files are ignored and CI scans secrets.

Deliverable: a modified client cannot bypass family permissions.

### Phase 5 - Make offline sync trustworthy

Goal: replace “saved on this device” uncertainty with understandable recovery.

- Define conflict rules for each data type.
- Prefer append-only ledger entries for financial data.
- Use tombstones consistently for deletions.
- Display sync states such as:
  - Saved
  - Syncing
  - Synced
  - Needs attention
- Provide a recovery screen for parked or rejected changes.
- Never discard local changes silently.
- Add forced logout and token-revocation handling.
- Test two devices editing the same:
  - transaction
  - envelope
  - shopping list
  - savings goal
  - family member
- Test offline creation, deletion, reconnection, retries, and app termination.

Deliverable: two devices converge without duplicate transactions or unexplained data loss.

### Phase 6 - Premium frontend consistency

Goal: make the interface feel intentionally designed rather than screen-by-screen assembled.

- Consolidate shared components:
  - modal/bottom-sheet shell
  - page header
  - form field
  - primary/secondary/destructive buttons
  - empty state
  - status banner
  - money card
  - confirmation dialog
- Give every sheet:
  - visible close button
  - drag-to-dismiss where safe
  - barrier dismissal where safe
  - keyboard-aware scrolling
  - constrained height
  - unsaved-change confirmation when necessary
- Remove overcrowding from sheets by using progressive disclosure.
- Ensure every clickable card has visible affordance and pressed feedback.
- Make savings creation visible on the empty state.
- Keep advanced features such as Mukando activation in Settings.
- Standardize spacing, radius, icon weight, shadows, type scale, and animation.
- Add loading skeletons and polished success/error states.

Deliverable: all major screens use one coherent design language.

### Phase 7 - Accessibility and localization

Goal: work reliably beyond the default iPhone and English configuration.

- Test text scaling at 100%, 150%, and 200%.
- Add semantic labels and hints to icons, cards, charts, and custom controls.
- Verify minimum 44×44 touch targets.
- Check contrast for text, progress bars, disabled states, and warnings.
- Support screen-reader focus order.
- Avoid color as the only status indicator.
- Test narrow phones, small-height devices, tablets, and keyboard-open layouts.
- Complete all translations and verify long translated strings.
- Add golden/layout tests for known overflow-prone screens.

Deliverable: no overflows and no inaccessible critical actions.

### Phase 8 - Auditability and observability

Goal: make failures diagnosable and sensitive actions traceable.

- Record server-side audit events for:
  - role changes
  - approvals
  - ownership transfers
  - member removal
  - account/family deletion
  - balance adjustments
- Keep audit entries append-only and protected from ordinary users.
- Add crash reporting and structured error reporting.
- Redact tokens, passwords, personal data, and financial notes from logs.
- Add operational metrics for sync failure, duplicate rejection, authentication failure, and API latency.
- Replace generic errors with friendly messages plus internal diagnostic IDs.

Deliverable: production problems can be traced without exposing private data.

### Phase 9 - Release validation

Before calling the app premium, run a real-device matrix:

- Clean install and upgrade from the previous version.
- iPhone small/large and at least two supported Android sizes.
- Poor network, airplane mode, session expiry, and server error.
- Two-user and two-device family workflows.
- Every role.
- Every supported language.
- Logout, deletion, restoration, and ownership transfer.
- Double tapping every money action.
- Backgrounding or killing the app during saves.
- App Store/Play Store privacy, permissions, and account-deletion compliance.

## Recommended order

1. Green CI and analyzer  
2. Financial correctness and idempotency  
3. Account/family lifecycle  
4. Authorization and security  
5. Offline sync  
6. Frontend/component polish  
7. Accessibility/localization  
8. Observability and release testing  

Do not spend the next cycle adding major features. Completing these phases would move the app from approximately **7.5/10 to 9/10 territory**, with financial correctness, lifecycle handling, and multi-device reliability producing the biggest improvement.