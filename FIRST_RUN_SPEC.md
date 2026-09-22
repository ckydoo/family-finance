# FIRST-RUN SPEC — Mhuri onboarding walk-through (v1 design, 2026-09-22)

> Status: DESIGN LOCKED FOR REVIEW — no code changes yet.
> Source: user's "Mhuri — Short First-Time User Flow" + review decisions.
> Binding rules: bottom nav is NOT changed (Home | Budgets | Lists | Savings |
> Family + existing ＋). No demos, no mock data — a real account from minute one.

## 0. Principles

1. **The mandatory path is 4 inputs**: Welcome → Account → Family → Money in.
   Everything else is optional, skippable, or arrives by sync.
2. **The flow is a walk-through, not a restructure.** It ends by handing the
   user to the tabs that already exist.
3. **Creator answers the money questions; joiners never do.** One family, one
   pool, defined once.
4. **Never silently discard a financial entry** (spec hardening rule): every
   optional step that is skipped says what it does ("You can add these
   anytime in Budgets").

## 1. The flow (step by step)

| # | Screen | Content & behaviour | Skippable? |
|---|---|---|---|
| 1 | **Splash** | Mhuri mark + *"Family money, together."* (existing splash, add tagline line) | — |
| 2 | **Welcome** | Brand, one-line value, **Get Started** (create) / **Sign In** (returning). | — |
| 3 | **Create account** | **Name → Email → Password** (name is NEW — becomes the user_profile display name; kills the email-prefix guess). Sign In keeps email+password only. | — |
| 4 | **Create or Join family** | Existing FamilySetup. Create: family name + household type. Join: invite code. | — |
| 5 | **Invite family** *(optional, creator only)* | Invite code + **Share on WhatsApp** (primary CTA) + Copy code. **Skip** → next. Joiners never see this step (they were invited). | ✔ |
| 6 | **Money Coming In** | *"How much money are you working with this month?"* One amount (USD or ZiG) + optional note. Writes the family pool seed as the creator's first income entry ("Money in — start of month"), visible in Activity, editable forever. | — |
| 7 | **Accounts** | **DEFERRED to v2** (disposition below). Not in the first run. | — |
| 8 | **Spending plan** *(optional)* | Suggested categories (Groceries, Transport, Housing, Utilities, School fees) as one-tap chips → each gets an amount → optional **monthly due date**, which quietly creates a recurring rule (= a bill). "Add custom category" at the end. Skipping shows: *"No plan yet — Budgets is ready when you are."* | ✔ |
| 9 | **Setup complete** | Payoff, two lines: *"Done — Moyo Family is set up. $600 this month, 4 categories."* → **Go to Home**. | — |

## 2. After Home (existing tabs, unchanged)

- **Home** now has one new *card*: **Upcoming bills** — read from the existing
  recurring rules (step 8's due dates feed it; empty state: "No bills yet").
- Everything else is current behaviour: envelopes show in **Budgets**, goals
  in **Savings**, the ＋ quick-add ("tell Mhuri once") moves envelope, pool,
  activity and syncs to every device.

## 3. Step 7 disposition — Accounts & balances

**Decision (my recommendation, adopted — reversible):** balance entry is
**out of the first run** and deferred as an optional v2 feature.

- Why: step 6 already captures the same truth (the month's pool = cash +
  EcoCash + bank together). Asking twice is form fatigue; syncing balances
  would change spec §5 (accounts device-local, records-only) and creates a
  two-people-one-pool conflict.
- When built (v2): Accounts are **per-person, device-local, private**
  (spec §5 unchanged) — a personal ledger of Cash / EcoCash / Bank / Savings
  balances. Family sees the pool, never each other's wallets.
- If the user prefers balances IN the first run (shared or private), this
  section gets revised — say so and it changes before any code.

## 4. The joiner branch (binding)

```
Creator:  1→2→3→4→(5 invite)→6→(8 plan)→9→Home
Joiner:   1→2→3→4(join code)→9→Home   ← everything else arrives by sync
```

- Joiners skip 5, 6, 8. After joining, the pull delivers the family name,
  pool, envelopes and bills; joiner's Home shows the family's real numbers.
- If the joiner is first to Home before the creator finishes, Home shows the
  existing honest empty/loading states (already built).
- Rule enforced in one place: `isCreator = (this session created the space)`
  — the onboarding router uses it to pick the branch.

## 5. Copy rules (tone: a person, not a form)

- "Money Coming In" — keep, it's human.
- Buttons: **Get Started / Sign In / Share on WhatsApp / Skip / Go to Home**.
- Every skip states the recovery point ("…anytime in Budgets").
- Family name example in helper text: *e.g. Moyo Family*.

## 6. Acceptance criteria (for the future build sprint)

1. Fresh install → mandatory path only → Home in ≤ 4 inputs, ~60 seconds.
2. Home after onboarding shows: Money left (from step 6), Upcoming bills
   (if step 8 added dates), Goals preview, Recent activity (the money-in
   entry), spending plan chips in Budgets (if step 8).
3. Joiner device: joins with code → sees the SAME pool, plan and bills —
   without ever answering a money question.
4. Name entered at step 3 appears in Family tab and on the other device's
   roster (no 'Member', no email-prefix guess).
5. WhatsApp share opens `https://wa.me/?text=…` with the invite code;
   copy-code works without WhatsApp.
6. Skipping any optional step loses nothing and says where to find it later.
7. No nav changes; no demo data anywhere; all strings through l10n (6 languages).

## 7. Explicitly out of scope for the build sprint

- Balance/account ledgers (v2, §3).
- Changing the bottom nav, moving Family/Lists anywhere.
- Bank/EcoCash API integration (no rails — manual recording only, per spec).
- Any demo/mock content in live builds (real-data directive stands).
