# UX-Polish Phase — spec & disposition (2026-09-22)
User directive: focused polish phase, priorities fixed. Every item has an explicit
disposition — nothing silently deferred.

## P1 — Sheets → full-screen forms · **DONE this round**
- Quick Add is now a FULL-SCREEN page (`quick_add_sheet.dart`): pinned header
  (44px close + title), body scrolls, **Save pinned above the keyboard**.
- Essentials first: type → amount+currency (with conversion) → envelope → person.
- Date/note/method live behind **"More details"** (collapsed by default; note+
  method inside — date comes with M8 device-week pass).
- Dismiss paths: close button, system back, (full-screen = no swipe/tap-out by design).
- **Discard guard** fires only when data was entered (PopScope + typed dialog:
  "Keep editing" / "Discard"), never after save.
- Still sheets (by design): confirmations, language picker, profile switching,
  small filters. Move money & envelope details → **Next round** (files listed below).

## P2 — Discoverability · **partial this round, rest Next**
- DONE: Family Pool card is tappable → Reports, with a visible
  **"View balance details" + chevron** row (eye icon stays hide/show only).
- DONE: first-use tooltip for the central + (one-time, kv `fab_tip_seen`,
  4s toast, all 6 languages).
- DONE: pressed state on the Pool card (InkWell).
- DONE: nav labels can't overflow (FittedBox) — done in previous round.
- Next round: "Manage family" label audit on the pill (chevron already there),
  empty-state CTAs (savings goals / lists), grey-text audit,
  chevron/pencil/eye consistency sweep.

## P3 — Accessibility & 200% text · **started this round**
- DONE: bottom nav switches to **icon-only mode** when text scale ≥ ~1.7
  (icons enlarge to 26, labels hidden) — overflow impossible at any scale.
- DONE: semantic tooltips on all icon-only controls in shell/pool card.
- Next round (needs device): full 200% pass over Home/Budgets/Savings/Lists/
  Reports (Row→Expanded/Flexible/Wrap, fixed-height removal, 48dp targets,
  contrast on pale grey/green + yellow, bold-text & reduced-motion checks).

## P4 — Offline recovery · **Next round (designed, not yet coded)**
- One tappable sync chip → **Sync Details screen** (pending/failed lists from
  outbox, last-sync time, manual retry + exponential backoff in SyncEngine).
- States: Saved on device · Waiting to sync · Sync failed — tap to retry.
- Auth-expiry vs network distinguished via 401 handling in SupabaseSyncClient.
- Form draft preservation + export-before-wipe. Files: home banner,
  `sync_engine.dart`, `supabase_sync_client.dart`, new `sync_details_screen.dart`.

## P5 — Destructive-action tiers · **Next round**
- Sign out: confirm only if unsynced ops exist. Delete transaction: confirm+Undo
  (addTx path already append-only). Delete envelope: reassign-target explainer.
- Delete account (backend migration 002 exists): type-DELETE dialog, unsynced
  summary + export offer, buttons disabled while processing, retry-safe server call.
- Language: "Delete permanently" — no generic Yes.

## New l10n keys (×6): moreDetails, lessDetails, discardTitle, discardBody,
keepEditing, discard, viewDetails, fabTip → **342 keys/locale**.
