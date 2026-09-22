# Sync conflict rules (per entity)

How the two-device sync resolves conflicts. Two invariants hold for every
entity:

1. **Push wins the write, pull echoes the truth.** `syncNow` pushes first,
   then pulls: after a sync, every device has the server's state. A push
   overwrites a server row (PostgREST `merge-duplicates` on `id`); a pull
   overwrites the local row (SQLite `REPLACE` on `id`). "Last write" is
   therefore *last push*, not last edit — offline edits made after someone
   else pushed lose, visibly (the losing device's value disappears on next
   pull). This is the documented trade-off of the offline-first queue.
2. **Deletes are tombstones.** A hard `DELETE` cannot be pushed after the
   fact, so every deletable entity carries `deleted_at` and devices remove
   their local copy when the tombstone pulls. The one delete surface today
   is list items (list_item.deleted_at); `transaction` has server-side
   soft-delete (7-day trash) and `shopping_list` is tombstoned too.
   **Rule for future delete UIs: write `deleted_at` + push — never DELETE.**
   (envelope/goal/kid_request/earning have no delete UI yet; when one ships,
   add `deleted_at` server-side first, then the UI, using list_item as the
   pattern. A migration 009-style backfill/rollback note comes with it.)

| Entity | Write conflict | Delete | Rationale |
|---|---|---|---|
| `envelope` | Whole-row LWW (push order). Limits/period are owner-edited; simultaneous edits are rare and visible | tombstone (when delete UI ships) | Envelope shape is small; field merging would surprise |
| `goal` | Whole-row LWW | tombstone (when delete UI ships) | Same |
| `tx` | Whole-row LWW; the *creator's* edit wins only by arriving last. `deleted_at` set = trashed everywhere | soft delete (server column exists) | Money rows are append-mostly; amounts are corrected by new rows in practice |
| `goal_tx` | **Append-only** — upserts dedupe on `id` (unique server_id locally); contributions are never edited | none | Immutable contributions keep savings math honest |
| `list_item` | Whole-row LWW per item; `state`+`checked_out` cycle is guarded server-side (007) | **tombstone** (live today) | Fast-moving shared list; per-item rows conflict independently |
| `shopping_list` | Whole-row LWW; name rarely edited | **tombstone** (live today) | Header sync (#8 round) |
| `kid_request` | State machine: `pending → approved/declined` one-way; a later `pending` push cannot resurrect a decided request (pull corrects it) | none | Requests are decisions, not documents |
| `earning` / `chore` / `recurring` / `mukando` | Whole-row LWW | none today | Kid-domain rows, single-editor in practice |

## Ordering guarantees

- One device: outbox replays oldest-first, so same-row edits apply in order.
- Two devices: both push; the server's final state is whichever push landed
  last, then every pull converges to it.
- The 45s poll plus pull-on-resume keeps the converge window under a minute
  online; Sync & data shows exactly where each device stands.
