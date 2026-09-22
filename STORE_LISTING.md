# Store listing & QA (roadmap #21)

Everything the Play Console / App Store Connect forms ask, answered from the
actual codebase. Fill the bracketed items before submitting.

## Listing copy

- **App name**: Mhuri Hub — Family Money
- **Short description (80 chars)**: Budgets, savings circles (ROSCA), shopping
  lists & kids' money habits — one family, one plan.
- **Full description**: built from PRODUCT_SPEC's promise: offline-first
  family budgets in USD and ZiG, shared envelopes, savings goals and ROSCA
  circles, shopping lists that sync over 2G, bill reminders that fire
  offline, kid/teen modes with parent-approved permissions, and a real
  delete-your-data path. No ads, no tracking.
- **Category**: Finance · **Tags**: budget, family, savings, ROSCA, Zimbabwe
- **Localizations at launch**: en (sn/nd copy is in-app; store listing
  English first, add sn/nd store text when reviewed by native speakers).

## Data safety form (Play) — mapped to reality

| Question | Answer | Because |
|---|---|---|
| Does your app collect or share user data? | Collects, does **not** share | RLS keeps data in the family's own space; no third parties |
| Data collected | Email, name, profile photo (optional), user financial content, app activity (sync events) | see PRIVACY_POLICY.md table |
| Purpose | App functionality, account management | — |
| Encrypted in transit | Yes | Supabase HTTPS/TLS everywhere |
| Users can request deletion | Yes | In-app: Settings → account → Delete (typed confirmation) |
| Committed to Play Families policy? | **Yes** if kids' mode is advertised | kids use a parent's device + PIN; no kid PII collected |

## Content rating questionnaire

No violence, gambling or user-generated sharing beyond the family space.
The savings circle (ROSCA) is a family savings arrangement, not betting —
answer "no" to gambling.

## Screenshots to capture (device, before submission)

1. Home — safe-to-spend + recent activity
2. Budgets — envelope rings mid-month
3. Savings — goal + circle (ROSCA) turn view
4. Lists — shared shopping list
5. Family — members with roles
6. Kids Mode — child's own screen
Take phone + 7" tablet sets, light theme, real-looking but **demo-free**
content (use your own family's test space, blur any real names you would
not publish).

## Pre-submission QA checklist (store QA)

- [ ] `flutter analyze` + `flutter test` green on GitHub Actions
- [ ] Real device: sign-up → family create → invite second device →
      transaction offline → airplane off → sync OK ("✓ Synced")
- [ ] Password recovery email arrives and resets (redirect URLs configured)
- [ ] Invitations: code join + QR join + deep link on a cold install
- [ ] Roles: kid PIN gate, teen limits, permissions actually hide money
- [ ] Delete account: typed DELETE → four phases → login freed → rejoin works
- [ ] Migrations 001→012 applied on the production project (CI proves the
      chain from zero; production parity is your SQL-editor run)
- [ ] Backups enabled + one restore drill recorded (backend/BACKUP_RESTORE.md)
- [ ] Privacy policy hosted at a public URL; contact email filled in
- [ ] fr/pt text overflow check on device; sn/nd fluent review done
- [ ] App version + build number bumped; release signed with the upload key
