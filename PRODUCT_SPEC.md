# Mhuri Money — Product Specification & Design Document

**Family Finance Management for Every Kind of Family**
Version 1.0 · September 2026 · Target platform: Flutter (Android & iOS)

> "Mhuri" means *family* in Shona. Mhuri Money helps couples and families in Zimbabwe
> (and beyond) manage income, expenses, budgets, savings and shopping lists together —
> in USD and ZiG, online or offline, with a safe, fun mode for kids.

---

## Table of Contents

1. [Vision & Problem Statement](#1-vision--problem-statement)
2. [Target Users & Personas](#2-target-users--personas)
3. [Family Roles & Permissions Model](#3-family-roles--permissions-model)
4. [Feature Specifications](#4-feature-specifications)
5. [Multi-Currency Design (USD + ZiG)](#5-multi-currency-design-usd--zig)
6. [UX Design: Navigation, Flows & Design System](#6-ux-design)
7. [Screen-by-Screen Specification](#7-screen-by-screen-specification)
8. [Data Model](#8-data-model)
9. [Technical Architecture](#9-technical-architecture)
10. [Security, Privacy & Compliance](#10-security-privacy--compliance)
11. [Product Roadmap](#11-product-roadmap)
12. [Monetization](#12-monetization)
13. [Success Metrics (KPIs)](#13-success-metrics-kpis)
14. [Risks & Mitigations](#14-risks--mitigations)
15. [Future Enhancements (v3+)](#15-future-enhancements)
16. [Appendix: Mockups](#16-appendix-mockups)

---

## 1. Vision & Problem Statement

### 1.1 Vision

Give every family — nuclear, extended, single-parent, blended, or child-free — one calm,
shared place to see their money, plan it together, and teach kids good habits along the way.

### 1.2 The problem

Managing family money today is fragmented and stressful:

| Pain point | Today's reality |
|---|---|
| **Money is split everywhere** | Cash at home, bank account, EcoCash wallet, ZIPIT, mukando circle — no single view of "what do we actually have?" |
| **Two currencies** | Prices are quoted in USD and ZiG (ZWG); families must mentally convert and track both |
| **Couples don't sync** | One partner pays school fees, the other buys groceries; nobody knows the true position until money runs out |
| **Budgets live in notebooks** | Or in a heads-of-household memory. Invisible to everyone else, lost when the notebook is lost |
| **Inflation pressure** | Prices move; a budget set in January is fiction by March without easy re-planning |
| **Kids are excluded** | Children get pocket money with zero financial education; chores and rewards are informal |
| **Existing apps don't fit** | International apps (YNAB, Mint) assume one country, one currency, card-centric banking, and no shared family model |

### 1.3 Product principles

1. **The family is the account** — everything is designed around a shared Family Space, not an individual wallet.
2. **Dual-currency is native, never a bolt-on** — every amount can live in USD or ZiG and be seen in both.
3. **Offline-first** — the app must be fully usable with no data or electricity; it syncs when connectivity returns.
4. **Role-based trust** — partners see everything they agree to see; kids see only what is safe and fun.
5. **Low-literacy & low-data friendly** — big touch targets, icons + color, works on low-end Android phones.
6. **Calm, not shameful** — overspending is flagged kindly ("Fuel budget reached"), never with red alarm guilt.

---

## 2. Target Users & Personas

### Persona 1 — Tendai & Rudo (the planning couple) 👨‍👩‍👧‍👦

- **Who:** Married couple, 34 & 31, two kids (Tino, 8; Anesu, 5). Both work — Tendai in an office, Rudo runs a small business.
- **Income:** Tendai paid in USD; Rudo's earnings mixed USD/cash/EcoCash.
- **Goals:** Stop money "disappearing" mid-month; agree on budgets without arguments; save for Term 2 school fees ($900) and a chest freezer.
- **Frustrations:** "I asked him what's left and he said 'check with Rudo'." Each keeps separate records.

### Persona 2 — Mai Chipo (the single parent) 👩‍👦

- **Who:** Widow/single mother, 45, teacher; three children in school; receives remittances from a brother in the UK.
- **Goals:** Stretch one income across school fees, food and uniforms; track remittances separately; involve her 15-year-old gently.
- **Needs:** Solo mode (no partner required), remittance tracking, strong privacy for what she saves.

### Persona 3 — Tino (the kid) 🧒

- **Who:** 8 years old, gets $5/week pocket money + earns stars for chores.
- **Goals:** Save for a soccer ball ($25) and a bike ($120); see his jar grow.
- **Constraints:** Cannot see family balances, cannot move money, needs approval for anything real. **Bright, playful Kids Mode only.**

### Persona 4 — Sekuru James (the elder / extended family) 👴

- **Who:** Grandfather, 68, manages contributions to the extended-family mukando and funeral society; limited literacy with apps.
- **Goals:** Record who contributed what; know the round's totals; big text, simple screens.
- **Needs:** "Elder/Viewer" role, simplified UI mode, voice-note notes on entries.

### Persona 5 — The blended / co-parenting family 🤝

- **Who:** Divorced parents sharing costs for two children, living in different cities.
- **Goals:** Transparently split school fees, medical aid and clothes; keep a shared record without sharing their personal spending.
- **Needs:** "Co-parent Space" — a shared sub-space limited to child-related envelopes only (v2.5).

### Persona 6 — The child-free couple / roommates 👩‍👩

- **Who:** Two working partners, no kids; shared rent, groceries, car.
- **Goals:** Split shared expenses fairly, keep personal spending private.
- **Needs:** Family Space works fine with 2 adults and 0 kids; "shared vs personal" envelopes.

**Market sizing note:** ~1.6M+ urban households in Zimbabwe, >90% adult mobile money penetration,
heavy reliance on informal savings groups (mukando/round) — a strongly underserved segment for
family-oriented money tools.

---

## 3. Family Roles & Permissions Model

Every user belongs to one or more **Family Spaces**. Each space has members with roles:

### 3.1 Roles

| Role | Who | Capabilities |
|---|---|---|
| **Owner** | Family head (can be a couple — up to 2 co-owners) | Everything: manage members, roles, delete space, export data, approve settings |
| **Adult / Partner** | Spouse, partner, adult child (18+) | Full read of shared space; add/edit transactions, budgets, lists; cannot remove members or delete space |
| **Teen (13–17)** | Teenagers | Personal jars & wish lists, view (optional) chosen shared envelopes, propose expenses for approval, chore board. **No** access to family balances by default |
| **Kid (6–12)** | Young children | Kids Mode only: jar, stars, chores, wish list. Everything request-based |
| **Elder / Viewer** | Grandparents, caregivers, accountant-aunt | Read-only + contribute to mukando records; simplified UI option |
| **Co-parent (external)** | Non-resident parent (v2.5) | Access only to a dedicated "Co-parent Space" with child-related envelopes |

### 3.2 Privacy controls (per couple agreement)

Couples differ. Mhuri Money supports three sharing levels, set per member and per account:

- **Full transparency** — partner sees all shared + personal accounts (default for shared accounts).
- **Shared-only** — partner sees shared envelopes/accounts; personal accounts show only a "spent this month" number, never line items.
- **Private pockets** — each adult may mark accounts/goals as private; the space shows a summary placeholder "🔒 Private · $120" so totals still reconcile without revealing detail.

> Design rule: **totals must always reconcile.** If a member hides detail, the app still shows the
> amount is allocated — transparency about *that it exists*, privacy about *what it is*.

### 3.3 Approval workflows (kids & teens)

- Kid requests money / a purchase → parent(s) get push notification → Approve / Decline with a note → kid sees result in Kids Mode with a friendly explanation.
- Teen-proposed expense enters the adult budget as a "pending" card.
- All approvals are logged in Family Activity ("Mom approved $25 for Tino's soccer ball").

### 3.4 Conflict & safety rules

- Deleting a transaction requires Owner or the transaction's creator; it goes to a 7-day trash with an activity log entry.
- Any role/permission change notifies all Owners.
- Data export is Owner-only and notifies all adults.

---

## 4. Feature Specifications

Features are grouped into modules. **MVP = modules A–E.**

### Module A — Family Space & Onboarding

| # | Feature | Detail |
|---|---|---|
| A1 | Create Family Space | Name, household type (couple / single parent / extended / blended / partners), currency defaults (USD primary, ZiG secondary), month start day (default 1st — configurable for payday-aligned budgeting, e.g. 25th) |
| A2 | Invite members | Phone number (app share / SMS) or QR code shown on the "Members" screen; join by code |
| A3 | Roles & permissions | Assign per §3; change with Owner approval; kids get friendly avatars |
| A4 | Solo mode | A single-adult space works fully — no partner needed to use any feature |
| A5 | Multiple spaces | A user can belong to 2+ spaces (e.g., nuclear family + extended family mukando space) with a space switcher |
| A6 | Profiles | Name, avatar (illustrated set + photo), language (English / Shona / Ndebele at launch), UI size (normal / large for elders) |
| A7 | Family Activity feed | Tamper-evident log of who did what: added expense, approved request, changed budget, completed goal |

### Module B — Income Tracking

| # | Feature | Detail |
|---|---|---|
| B1 | Income sources | Named sources (e.g., "Tendai salary", "Rudo tuckshop", "UK remittances", "Mukando payout", "Rent from cottage") with recurrence (weekly / fortnightly / monthly / irregular) |
| B2 | Expected vs received | Each month shows expected income; users mark received in USD or ZiG; missed/late income is highlighted kindly |
| B3 | Multi-currency income | Record in the currency received; the space shows combined totals in the display currency (user-chosen) at the current rate |
| B4 | Remittance tagging | Tag income as remittance with sender + channel (Western Union, Mukuru, bank) — feeds a "support received this year" summary |
| B5 | Payday alignment | Month cycles can start on any day (e.g., 25th) so budgets match real pay cycles |

### Module C — Expenses & Transactions

| # | Feature | Detail |
|---|---|---|
| C1 | Quick add | 3-tap entry: amount → category (icon grid) → member. Defaults smart (last-used category, keypad with big keys). Target: < 8 seconds |
| C2 | Currency on entry | USD or ZiG toggle on the keypad; live conversion preview shown with the day's rate and timestamp |
| C3 | Receipt photo | Attach photo; OCR-assisted merchant/amount pre-fill (v2) |
| C4 | Split transactions | Split one amount across categories, members, or "who owes what" (e.g., shared grocery run: 60/40) |
| C5 | Payment method tag | Cash · EcoCash · Bank card · Bank transfer · ZIPIT · InnBucks · Other — enables "cash leak" analytics (how much untraceable cash the family spends) |
| C6 | Notes & voice notes | Text note + attach a voice note (elder-friendly) |
| C7 | Recurring expenses | School fees, rent, subs, insurance, DSTV/Netflix, airtime bundles — auto-posted with a review step; reminders 3 days before |
| C8 | Edit / delete rules | Per §3.4; all edits versioned in activity log |
| C9 | Receipts & warranties | Long-lived purchases (fridge, solar) can be filed with warranty expiry reminder |
| C10 | Bulk import | Import bank/EcoCash statement CSV/PDF (v2) |

### Module D — Budgets (Envelope Budgeting)

| # | Feature | Detail |
|---|---|---|
| D1 | Envelopes | The core metaphor: every dollar has a job. Envelopes = categories with monthly limits (e.g., Groceries $450, School fees $300, Transport $200, Electricity $60) |
| D2 | Auto-suggestions | On first run, pre-suggest an envelope set for Zimbabwean households (mealie meal & staples, school fees & levies, transport/kombi fuel, electricity/prepaid tokens, airtime & data, medical, tithing/church, mukando contribution, emergency buffer) |
| D3 | Progress & pace | Each envelope shows spent/limit, a pace indicator (on track / watch / over) based on day-of-month, and a projected month-end |
| D4 | Rollover rules | Per envelope: reset monthly / roll over unspent / goal-style (accumulate for school terms) |
| D5 | Term-based budgets | School fees envelopes follow school terms (3 terms/yr) with a term calendar for ZW schools |
| D6 | Overspend kindness | At 100% the envelope shows "Budget reached — here's what you can top up from" with a one-tap move from a flexible envelope (requires partner confirm if enabled) |
| D7 | Move money | Transfer between envelopes with a reason; logged |
| D8 | Shared & personal envelopes | Mark each envelope shared (family) or personal (private per §3.2) |
| D9 | Budget vs actual reports | Monthly report card: biggest moves, category trends vs last month, "cash leak" from C5, safe-to-spend/day figure |
| D10 | Inflation helper | When a category exceeds budget 2 months running, prompt: "Prices went up? Adjust Groceries to $520?" with history of changes |

### Module E — Savings Goals & Mukando

| # | Feature | Detail |
|---|---|---|
| E1 | Goals | Name, target, currency, deadline, cover image/icon, auto-save rule (e.g., $25/week on Friday), owner (family, member, or kid jar) |
| E2 | Contributions | One-tap "add to goal"; contributions logged per member; progress ring + celebrations (confetti at 25/50/75/100%) |
| E3 | Goal types | Sinking fund (school fees), emergency fund (recommended first goal — guided setup), big purchase, family event (wedding, funeral society contributions) |
| E4 | Mukando / Round (ROSCA) tracker | Track a rotation circle: members, contribution amount & frequency, round order, who has collected, whose turn is next, pot total, and payment proof photos. Reminders before each collection date. **Records only — Mhuri Money never holds the money** |
| E5 | Burial society / community funds | Same tracker with monthly dues + claims record |
| E6 | Emergency fund guard | Suggests moving unspent envelope money to the emergency fund at month end (opt-in) |

### Module F — Shopping Lists (connected to money)

| # | Feature | Detail |
|---|---|---|
| F1 | Lists | Multiple lists (Groceries — OK Zimbabwe, Hardware, School supplies, Markets/Musika) |
| F2 | Real-time co-editing | Family members see updates live; assign items; avatars show who added what |
| F3 | Price estimates | Per-item estimated price in USD or ZiG; running estimated total shown in both currencies |
| F4 | Budget check | List total previews against the linked envelope ("This list uses 74% of this month's Groceries envelope") |
| F5 | Complete = expense | "Finish shopping" converts checked items into one expense pre-filled with the estimate, ready for amount correction — closing the loop between list and budget |
| F6 | Repeat lists | Save a list as a template ("Monthly staples") and re-add with one tap |
| F7 | Pantry mode (v2) | Track staples stock at home; auto-suggest re-adds when running low |

### Module G — Kids Mode (6–12)

| # | Feature | Detail |
|---|---|---|
| G1 | Safe sandbox | Kid profile opens a sealed, playful environment. No family balances, no real money movement, PIN-gated exit |
| G2 | My Jar | Digital jar per kid with the real amount parents hold for them (parents deposit from any expense "to kid" action); grows with animations |
| G3 | Stars & chores | Parents define chores with star values; kids check off; parents confirm; stars are visible achievements (weekly star chart) |
| G4 | Wish list | Kid adds wishes with prices (from a parent-curated catalog or custom); app shows "You need 12 more stars / $13 more" in kid math |
| G5 | Requests | "Ask Mom/Dad for money" → structured request (amount, reason) → parent approval flow (§3.3) |
| G6 | Money lessons | Bite-sized story lessons ("What is saving?", "Needs vs wants") unlocked by stars; localized examples |
| G7 | Pocket money automation | Parents set weekly pocket money; auto-deposits to jar; kid sees it count down/grow |

### Module H — Teen Zone (13–17)

| # | Feature | Detail |
|---|---|---|
| H1 | Teen dashboard | Own jars + wish list (like kids) **plus** optional visibility of chosen shared envelopes (e.g., see how "School fees" budget works) — toggled by parents |
| H2 | Expense proposals | Teen can propose an expense (e.g., movie night $15) — enters parents' pending queue |
| H3 | Earning tracker | Log chores/small jobs and earnings; simple earnings chart |
| H4 | Savings matching | Parents can set "we match 50% of what you save" rules — teaches compounding |
| H5 | First budget | Guided mini-budget for their pocket money (spend/save/give split) |

### Module I — Reports, Insights & Family Meetings

| # | Feature | Detail |
|---|---|---|
| I1 | Monthly report card | One-screen summary: income vs spending, savings rate, envelope health, biggest change vs last month, cash-leak % |
| I2 | Trends | 6/12-month category trends; school-terms view; remittance view |
| I3 | Net position | Assets–liabilities simple view (cash, bank, mukando claims; debts/loans tracked as negative goals) |
| I4 | Family meeting mode | A guided 15-minute monthly agenda on one screen: last month recap → this month plan → goals check → chores/pocket money review → "one thing to improve". Exportable as PDF |
| I5 | What-if simulator | "What if we save $30 more/month?" / "What if school fees rise 15%?" simple sliders (v2) |
| I6 | CSV/PDF export | Owner-level export of all data |

### Module J — Sync, Notifications & Settings

| # | Feature | Detail |
|---|---|---|
| J1 | Offline-first sync | Every write goes to a local queue and syncs when online (§9) |
| J2 | Smart notifications | Budget 80% warning, envelope reached, bill due in 3 days, kid request, mukando turn, goal milestone, weekly family digest (Sunday 6pm) |
| J3 | Quiet hours & per-member prefs | DND window; choose which alerts you receive |
| J4 | Data & device | Multi-device per member; device list; logout remote |
| J5 | Backup & restore | Encrypted cloud backup; local backup file export |
| J6 | Accessibility | Dynamic text scaling, high-contrast theme, icon+text everywhere, talkback labels, Shona/Ndebele strings |

---

## 5. Multi-Currency Design (USD + ZiG)

### 5.1 Core rules

1. **Every money field stores:** `{ amount: bigint minor units, currency: 'USD' | 'ZWG' }`. **Never a float.**
2. **No silent conversion.** A transaction is recorded in the currency it happened in, and *stays* in it forever. Display conversion is a view, always annotated with the rate + date used.
3. **One display currency per member** (default USD), switchable anywhere via the ⇄ toggle.
4. **Rate source:** daily RBZ mid-rate bundled/fetched + user's **parallel/market rate** profile (user sets theirs; default suggestion from last known market range). Reports show which rate applied.
5. **Mixed-currency budgets:** an envelope can have its limit in either currency; the family pool totals show both, with a combined "≈" view using the chosen rate, clearly marked ≈.

### 5.2 Display conventions

| Context | Format |
|---|---|
| USD | `US$ 1,240.50` |
| ZiG | `ZiG 18,940` (whole ZiG; cents shown in detail views) |
| Converted | `≈ ZiG 18,940 · rate 15.27 (12 Sep)` |
| Pairs (pool card) | `US$ 1,240.50` and `ZiG 18,940` side-by-side, ⇄ icon swaps emphasis |

### 5.3 Edge cases

- **ZiG volatility:** monthly reports snapshot the month-end rate; historical reports never re-value old months.
- **Split-currency goals:** school fees quoted in USD but paid partly in ZiG — goal accepts contributions in both and shows progress in the goal's base currency.
- **Rounding:** conversions round half-up to 2dp; the receipt's original amount is always authoritative.

---

## 6. UX Design

### 6.1 Navigation map

```
Splash → Onboarding (3 slides) → Create/Join Family Space → Set up members & roles
│
├─ ADULT APP ──────────────────────────────────────────────
│   ├─ Home (dashboard)          ← default tab
│   ├─ Budgets (envelopes)
│   ├─ (+) Quick Add ─→ Expense / Income / Transfer / Goal deposit / List item
│   ├─ Savings (goals, mukando)
│   └─ Lists (shopping)
│   ├─ Activity (transactions, filter, search)   [from Home "Recent activity →"]
│   ├─ Reports                                   [from Home header]
│   ├─ Members & Settings                        [from Home avatar]
│   └─ Family Meeting                            [monthly prompt]
│
├─ TEEN APP (role=teen) ── jars, wishes, proposals, earning, mini-budget
│
├─ KIDS MODE (role=kid) ── sealed playful shell: Jar · Chores · Wishes · Ask
│
└─ ELDER/VIEWER (role=viewer) ── simplified: big-text overview + mukando records
```

Bottom navigation (adults): **Home · Budgets · (＋) · Savings · Lists**

### 6.2 Key flows

**Quick expense (< 8s):** tap (＋) → keypad opens with currency toggle (remembers last) → amount → category icon grid → member chip (defaults to you) → ✓ Done. Works fully offline.

**Shopping → budget loop:** Lists → check items → "Finish shopping" → pre-filled expense (estimated total, Groceries category, linked envelope preview) → adjust actual → ✓ → envelope bar updates on Home.

**Kid request:** Kids Mode → "Ask" → amount + reason → parent push → approve/decline → kid gets friendly result + jar updates if approved.

**Mukando round:** Savings → Mukando card → this month: whose turn → mark paid/collected with proof photo → reminder scheduled for next member.

**Family meeting:** monthly prompt → guided agenda screen → tap through recap → adjust envelopes for next month → confirm → next month starts aligned.

### 6.3 Design system

| Token | Value |
|---|---|
| Primary (trust/growth) | Deep teal `#0E7C66` |
| Primary dark | `#0A5A4B` |
| Accent (action/warm) | Amber `#F4A81D` |
| Danger (kind) | Soft red `#D9534F` (used sparingly, always with a helpful action) |
| Background | Off-white `#F6F5F1` |
| Cards | White, 20px radius, subtle shadow (elevation 2) |
| Text | Charcoal `#1F2937`; secondary `#6B7280` |
| Typography | Geometric sans (Inter / Google Sans style). Numerals tabular for amounts |
| Kids theme | Sunny yellow `#FFC93C`, coral `#FF6B6B`, sky blue, 28px radius, thick borders, illustrated icons |
| Icons | Rounded, filled duotone set; **every icon paired with a text label** |
| Motion | 150–250ms; progress rings animate; confetti only for goals (not ads) |

### 6.4 Accessibility & localization

- Minimum touch target 48dp; elder mode = 18sp base text, simplified tabs.
- Languages at launch: **English, Shona, Ndebele** (currency terms kept in English).
- All screens usable one-handed; bottom-sheet primary actions.
- Works on Android 8+ / 2GB RAM devices; APK < 25MB.

---

## 7. Screen-by-Screen Specification

### 7.1 Onboarding (3 screens + setup)

1. **Welcome** — "Money, managed together." Illustration of a family + phone. CTA: *Create family space* / *Join with code*.
2. **How it works** — 3 cards: See everything in one place · Budget with envelopes · Save & teach kids.
3. **Currency setup** — Primary display currency (USD default), ZiG shown alongside, rate explanation ("We use the RBZ daily rate; you can set your preferred rate").
4. **Space setup** — name, household type, month start day, invite members (skippable — solo mode).

### 7.2 Home / Dashboard (adult) — *see mockup A*

- Header: greeting by time of day ("Makadii, Tendi"), family avatar stack (tap → Members), notification bell.
- **Family Pool card** (teal gradient): balances across tagged accounts shown in **both currencies** side-by-side with ⇄; pill: "Safe to spend today: US$ 38" (computed: flexible money left ÷ days left in cycle).
- **Envelope chips row:** top 3 envelopes by usage with mini progress bars (tap → Budgets).
- **Recent activity:** last 3 transactions (tap → full Activity).
- **Smart card slot:** contextual — bill due in 3 days / mukando turn / goal milestone / monthly meeting prompt.
- Pull-down: quick month switcher + mini report.

### 7.3 Budgets (envelopes) — *see mockup B*

- Month header with cycle dates; summary card "Allocated $980 of $1,200" with segmented bar (spent/remaining/overspend marker).
- Envelope cards: icon, name, spent/limit, progress bar colored by pace (teal on-track, amber watch, red reached), sub-label of rollover/goal mode.
- Tap envelope → detail: transactions in, pace chart, move-money, edit limit, rollover rule, share/private toggle.
- "＋ New envelope" pill; reorder by drag; archive unused.

### 7.4 Activity (transactions)

- Filter chips: member, category, account/method, currency, flag (recurring, remittance, reviewed).
- Grouped by day with day totals; search by note/merchant; swipe: edit / delete (rules apply).
- Transaction detail: full fields, receipt photo, edit history, split breakdown, linked shopping list/goal.

### 7.5 Savings & Goals — *see mockup D*

- Goal cards with progress rings; auto-save badges; contribute sheet (amount, currency, from-envelope optional, note).
- Mukando section: rotation tracker card (round x of y, next collector, pot total), members' status grid, proof photos, reminders.
- Kids' jars summary (parents): each kid's jar + recent requests.

### 7.6 Shopping Lists — *see mockup C*

- List tabs (To buy / In cart / Done); per-item: qty, unit est. price (currency toggle), assignee avatar, checked state.
- Running estimate in both currencies; budget check bar vs linked envelope.
- "Finish shopping → log expense" primary button; save as template; share list via family (automatic) or WhatsApp link (read-only copy, v2).

### 7.7 Quick Add (bottom sheet)

- Mode chips: **Expense** · Income · Transfer · To goal · To list.
- Big keypad, currency toggle USD/ZiG with live ≈ preview, category icon grid, member chips, account/method chips, note + voice note, receipt camera, date (defaults today), "recurring" switch.
- Save works offline → queued banner "Will sync when online".

### 7.8 Kids Mode — *see mockup E*

- Full-screen playful shell; greeting + star count; **My Jar** card with goal ring; **My Chores** checklist with star values (parent-confirm tickles a "waiting for Mom/Dad ✨" state); **Wish list** with savings progress; bottom buttons "Ask Mom/Dad for money" (coral) and "Do a chore" (teal).
- Lessons shelf: story cards unlocked by stars.
- Exit: parent PIN.

### 7.9 Teen Zone

- Dashboard: jars, wish list, proposals status, earnings mini-chart, match-savings progress, mini-budget (spend/save/give pie).
- "Propose an expense" form → parents' pending queue.

### 7.10 Members & Settings

- Member cards (role badge, sharing level, devices); invite by QR/code; role change flow.
- Sharing & privacy (§3.2); notifications; currency & rate settings; language; month start; backup/export; danger zone (leave/delete space).

### 7.11 Reports & Family Meeting

- Report card screen (§I1) shareable as image/PDF to the family WhatsApp group.
- Family Meeting: guided steps, tap-through, editable envelope adjustments, PDF export.

---

## 8. Data Model

Conceptual schema (PostgreSQL/Supabase; local mirror in SQLite/Drift):

```
family_space   (id, name, household_type, month_start_day, base_currency,
                display_rate_profile, created_at, settings_json)

user           (id, phone, name, avatar, language, ui_size, created_at)
membership     (space_id, user_id, role[owner|adult|teen|kid|viewer|co_parent],
                sharing_level[full|shared_only], private_pocket_enabled,
                invite_status, joined_at)

account        (id, space_id, name, kind[cash|ecocash|bank|zipit|innbucks|other],
                owner_member_id|null, currency, sharing[shared|private],
                opening_balance_minor, is_archived)

transaction    (id, space_id, account_id, type[expense|income|transfer],
                amount_minor, currency, category_id, member_id,
                method, occurred_at, note, voice_note_uri, receipt_uri,
                recurring_rule_id|null, split_group_id|null, created_by,
                updated_at, deleted_at)          -- soft delete = 7d trash

category       (id, space_id, name, icon, color, kind[expense|income], is_personal)

envelope       (id, space_id, name, icon, color, limit_minor, limit_currency,
                period[monthly|term|custom], rollover[reset|rollover|accumulate],
                sharing[shared|personal], linked_goal_id|null)
envelope_tx    (envelope_id, transaction_id, allocated_minor, currency)

goal           (id, space_id, name, target_minor, target_currency, deadline,
                owner_member_id|null(family), auto_save_rule_json, icon, status)
goal_tx        (goal_id, member_id, amount_minor, currency, note, at)

mukando        (id, space_id, name, contribution_minor, currency, frequency,
                member_count, started_on, status)
mukando_member (mukando_id, user_id, round_order, has_collected_on, collected_minor)
mukando_event  (mukando_id, round_no, kind[paid|collected], member_id, proof_uri, at)

shopping_list  (id, space_id, name, linked_envelope_id|null, status[active|done], template_of|null)
list_item      (id, list_id, name, qty, est_price_minor, currency,
                added_by, assigned_to|null, state[tobuy|incart|done])

chore          (id, space_id, name, star_value, assignee_member_id, recurrence)
chore_log      (chore_id, date, state[claimed|confirmed], confirmed_by)

kid_request    (id, space_id, kid_member_id, amount_minor, currency, reason,
                state[pending|approved|declined], decided_by, decision_note, at)

rate_snapshot  (date, source[rbz|market], usd_zwg, captured_at)

activity_log   (id, space_id, actor_member_id, action, entity, entity_id,
                detail_json, at, prev_hash, hash)   -- hash-chained for tamper evidence

sync_queue     (local only: op_id, entity, payload, op_type, created_at, retries)
```

**Rules:** amounts are minor units (integer). All tables carry `space_id` for row-level
security. `transaction.updated_at` + `activity_log` give a full audit trail. Delete = soft
delete with 7-day trash.

---

## 9. Technical Architecture

### 9.1 Stack overview

| Layer | Choice | Why |
|---|---|---|
| **Client** | Flutter 3.x (Dart), Material 3 + custom design system | Single codebase Android+iOS; excellent low-end device performance |
| **Local DB** | Drift (SQLite) with reactive streams | True offline-first; UI reacts to local writes instantly |
| **Backend** | Supabase (PostgreSQL + Auth + Realtime + Storage) | Fast MVP; row-level security fits the family/roles model; realtime powers shared lists & activity |
| **Auth** | Phone number (SMS OTP) via Supabase Auth; kids get **profile-PIN login inside a parent device** (no phone number needed) | Kids often use a parent's phone; elders need simple login |
| **Sync** | Local write → outbox queue → Supabase RPC with last-writer-wins + merge handlers for lists/goals; hash-chained activity log | Survives 2G/daily connectivity; conflict-safe co-editing |
| **Rates** | Server cron fetches RBZ rate daily; parallel-rate is a per-space setting; bundled fallback rate offline | Works offline; honest rate labeling |
| **Push** | FCM + local notifications (offline schedules for bills/reminders) | Bill reminders must work offline |
| **State mgmt** | Riverpod | Testable, reactive |
| **CI/CD** | GitHub Actions → internal testing tracks | Weekly release cadence |

### 9.2 Offline-first sync design

1. Every mutation writes to Drift **and** an outbox row (ordered, idempotent `op_id`).
2. A sync engine flushes the outbox when connectivity returns (or on app focus), in order.
3. Conflicts: transactions are append-mostly (rare conflicts, LWW by `updated_at`); lists use
   per-item ops; approvals are single-decision (first write wins, second gets "already decided").
4. UI shows sync state subtly: "✓ Synced · just now" / "⏳ 3 changes waiting to sync".
5. Local reminders/notifications are scheduled on-device so bills and mukando turns fire offline.

### 9.3 Project structure (Flutter)

```
lib/
  core/            design_system/  (tokens, theme, widgets)
                   db/ (drift)  sync/ (outbox engine)  utils/ money.dart
  features/
    onboarding/    family_space/   members/
    income/        expenses/       budgets/
    savings/       mukando/        lists/
    kids_mode/     teen_zone/      reports/     family_meeting/
    settings/      notifications/
  l10n/            app_en.arb  app_sn.arb  app_nd.arb
```

### 9.4 Testing strategy

- Unit: money math (minor units, conversions, rollover, pace calc), sync merge logic.
- Widget: golden tests for all core screens (light/elder/kids themes).
- Integration: offline queue flush, kid approval flow, shopping→expense loop.
- Pilot with 20–50 real families (Harare + Bulawayo + diaspora-remittance households) before public launch.

---

## 10. Security, Privacy & Compliance

| Area | Approach |
|---|---|
| **Authentication** | Phone OTP; kid PIN inside parent device; optional biometric unlock; remote device logout |
| **Authorization** | Supabase Row-Level Security keyed on membership+role; every query filtered by `space_id` + role checks server-side (never trust the client) |
| **Encryption** | TLS in transit; at-rest encryption by provider; receipt/voice files in private storage buckets with signed URLs; local DB encrypted (SQLCipher) for kid-safety on shared devices |
| **Data minimization** | No bank credentials stored (v1 has no bank connections); we never hold or move user money |
| **Privacy by role** | Private pockets enforced server-side: private transaction rows are not returned to members without permission (not just hidden in UI) |
| **Kids' privacy** | Kids Mode has no real balances; minimal data; no ads, no trackers, no external links in kids surfaces (COPPA-aligned posture) |
| **Regulatory** | Zimbabwe Data Protection Act (Ch. 12:07) compliance: consent, data subject access/export, deletion; clear privacy policy in EN/SN/ND |
| **Fraud/abuse** | Rate-limit OTP; audit log (hash-chained) for disputes; anomaly alerts on unusual deletes/exports |
| ** disclaimer** | In-app note: Mhuri Money is a **tracking/planning tool**, not a licensed financial institution; no custody of funds |

---

## 11. Product Roadmap

### Phase 0 — Foundations (Weeks 1–4)
- Finalize this spec → clickable prototype (Figma) → usability test with 8 families.
- Design system in Flutter; project scaffold; CI; Supabase schema + RLS policies.

### Phase 1 — MVP (Weeks 5–14) — *Modules A–E + J core*
- Family space, roles, invite; income & expense tracking (offline-first); envelope budgets
  with rollovers; goals + mukando tracker; basic lists with finish→expense; quick add;
  notifications; USD/ZiG with rate snapshots; EN language.
- **Closed beta:** 30 families, 6 weeks, weekly feedback calls.

### Phase 2 — Family completion (Weeks 15–24)
- **Kids Mode + chores + requests; Teen Zone;** family meeting mode; reports & report card;
  Shona + Ndebele localization; elder/large-text mode; receipt OCR; statement import (CSV).

### Phase 3 — Growth (Weeks 25–36)
- Multi-space (extended family), co-parent space; pantry mode; what-if simulator;
  mukando reminders v2 (per-member schedules); WhatsApp list sharing; widget &
  quick-tile quick add; Play Store + App Store public launch.

### Post-launch quarterly themes
- Bank/wallet read-only connections (where APIs allow), EcoCash SMS auto-parse (on-device),
  AI categorization + "money mentor" tips, merchant price comparisons for staple lists,
  insurance/funeral-society modules, diaspora family spaces (multi-country currencies).

---

## 12. Monetization

| Tier | Price | Contents |
|---|---|---|
| **Free** | $0 | 1 space, 2 adults + all kids, core tracking, 5 envelopes, 2 goals, 1 list, 30-day history |
| **Mhuri Plus** | ~$1.99/mo or $19/yr (mobile-money friendly, family-priced — one subscription covers the whole space) | Unlimited envelopes/goals/lists/history, mukando tracker, Kids & Teen modes, reports & meeting mode, OCR receipts, multi-space, voice notes, priority support |
| **Family network** | Free | Diaspora relatives get a free "supporter" view of goals they contribute to (drives viral growth) |

Principles: **no ads ever, especially in Kids Mode**; price anchored to be reachable
(≈ one bottle of coke/month); annual plan discounted for school-fee season. Potential B2B:
white-label for MFIs/SACCOs and churches (v3).

---

## 13. Success Metrics (KPIs)

| Category | Metric | Target (6 mo post-launch) |
|---|---|---|
| Activation | % of new spaces logging ≥10 transactions in week 1 | ≥ 60% |
| Habit | Weekly active spaces / total spaces | ≥ 55% |
| Couples | % of spaces with 2+ active adults logging in same week | ≥ 40% |
| Budgeting | % of active spaces with ≥3 envelopes & on-track pace | ≥ 50% |
| Savings | % of spaces with ≥1 active goal; median contribution/week | ≥ 45% / $10 |
| Kids | % of Plus spaces using Kids Mode weekly | ≥ 30% |
| Reliability | Sync success within 24h; crash-free sessions | ≥ 99% / ≥ 99.5% |
| Business | Free→Plus conversion | ≥ 4% |
| Retention | Month-2 space retention | ≥ 45% |

North-star: **"Envelope health"** — % of planned spending that actually happened inside
its envelope (calm budgeting, not perfection).

---

## 14. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **ZiG rate volatility/confusion** | Trust loss in numbers | Store original currency; snapshot rates; label all conversions with rate+date; let users set their own market rate |
| **Low-end devices / data cost** | Churn | 2GB RAM floor, <25MB APK, offline-first, tiny payloads, image compression for receipts |
| **Couples conflict over transparency** | App blamed for fights | Private pockets by design; kind overspend language; sharing is opt-in per member; "family meeting" framing |
| **Mukando misuse (holding money)** | Legal/trust risk | Tracker only, explicit "we never hold money" messaging, no payment rails in v1 |
| **SMS OTP cost/deliverability (ZW)** | Onboarding drop | WhatsApp OTP fallback, email option, offline demo mode until verified |
| **Kid safety on shared devices** | Privacy incidents | PIN-gated exits, no real balances in Kids Mode, local DB encryption |
| **Competitor (bank apps, spreadsheets)** | Slow growth | Family-first + dual-currency + offline fit is the moat; nail couples & kids before breadth |

---

## 15. Future Enhancements (v3+)

- **AI money mentor:** "You spend 18% more on transport in the first week of term — want a term envelope?" (on-device where possible)
- **EcoCash/bank SMS auto-parse:** on-device notification parsing → draft transactions (privacy: stays local)
- **Merchant price book:** crowd staple prices (mealie meal, oil, flour) across OK/Choppies/musika to plan lists cheapest-first
- **Bill marketplace:** pay school fees/DSTV/prepaid electricity in-app via payment partner (licensed rails)
- **Diaspora spaces:** multi-country currencies (USD/GBP/ZAR) with remittance-linked goals ("Gogo's solar project — 64% funded by the UK uncles")
- **Voice-first entry (Shona/Ndebele):** "Rudo, hear me: groceries two hundred" → draft expense
- **Financial education journey:** structured curriculum for teens with certificates parents see

---

## 16. Appendix: Mockups

High-fidelity concept screens (in `mockups/`):

| File | Screen |
|---|---|
| `home_dashboard.png` | Adult Home — Family Pool in USD & ZiG, safe-to-spend, envelope chips, activity |
| `budgets.png` | Envelope budgets — allocated bar, per-envelope pace, overspend state |
| `shopping_list.png` | Shared list — co-editing, dual-currency estimate, finish→expense loop |
| `savings_goals.png` | Goals with progress rings, auto-save, mukando card, kid jar |
| `kid_mode.png` | Kids Mode — jar, stars, chores, wish list, ask-parent flow |

---

*Prepared for the Mhuri Money project — Flutter / Supabase / offline-first / USD+ZiG.*
*Next step: Phase 0 — clickable prototype & Flutter scaffold.*
