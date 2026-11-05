# Mhuri 9.3 Experience Plan

**Purpose:** Move Mhuri from a feature-rich family finance app to an exceptionally easy, polished, and trustworthy daily product.

**Product target:** **9.3/10 from an end-user perspective**

**Status:** Proposed experience-improvement plan

**Related document:** `app/Planto9:10.md` covers the broader production-hardening work. Financial correctness, permissions, account recovery, and offline reliability remain prerequisites for this experience plan.

---

## 1. Executive decision

Do **not** add another major feature module during this cycle.

The path to 9.3 is to improve the moments users experience most often:

1. Recording an expense
2. Understanding Home
3. Getting started
4. Using the app in their preferred language and on their device
5. Receiving one useful, encouraging weekly summary
6. Trusting the app with real family data under real-world conditions

The desired user reaction is:

> “Mhuri helps my household stay organised without making me manage the app.”

---

## 2. Experience principles

Every proposed change should be checked against these principles:

- **Daily before occasional:** Optimise frequent actions before advanced planning tools.
- **One clear next step:** Do not make users interpret several competing alerts and cards.
- **Progressive disclosure:** Keep advanced options available without showing them all by default.
- **Real data only:** Onboarding and guidance must never create fake financial records.
- **Family-aware:** Respect roles, permissions, private finances, and each member’s responsibilities.
- **Local by design:** Currency, language, date formats, connectivity, and family workflows must feel intentional for Zimbabwean households and all other supported users.
- **Calm and encouraging:** Never shame a household for spending, debt, or incomplete data.
- **Trust over delight:** A beautiful insight is unacceptable if its financial meaning is uncertain.

---

## 3. Measurable outcomes

Capture a baseline before implementation, then use the same definitions after each release increment.

| Outcome | Release target |
|---|---:|
| Median time to record a repeat expense | 5 seconds or less |
| 90th percentile repeat-expense time | 10 seconds or less |
| Time from starting family creation to a useful Home screen | Under 3 minutes |
| New users completing the first guided money journey without assistance | At least 90% |
| Users accepting a family invitation without assistance | At least 90% |
| Critical user journeys containing unintended English in a non-English locale | Zero |
| Layout overflows in the supported device/text-scale matrix | Zero |
| Duplicate or lost transactions in reliability testing | Zero |
| Observed user satisfaction after the moderated beta | At least 4.6/5 |

A repeat-expense measurement starts when the user taps the central **+** and ends when the saved transaction is visible locally. It must use a previously used budget, currency, and payment method.

---

## 4. Delivery sequence

### Phase 0 — Establish the experience baseline

**Goal:** Make current behaviour measurable and protect existing workflows before simplifying them.

#### Work

- Document the current first-run, create-family, join-family, expense, income, shopping, and task journeys.
- Record current completion times for onboarding and repeat-expense entry.
- Add privacy-safe product events for:
  - quick add opened and completed
  - transaction saved or cancelled
  - onboarding step started, completed, or abandoned
  - invitation opened, accepted, or failed
  - weekly summary viewed and shared
- Record duration, success, role, language, and broad error category only.
- Never send transaction amounts, notes, receipt data, family names, or message content to analytics.
- Confirm the existing automated tests pass before changing navigation or onboarding.

#### Acceptance criteria

- The team can compare old and new completion times using the same test script.
- Analytics contains no sensitive financial content.
- Existing income, shopping-item, and task entry points remain covered by tests.

---

### Phase 1 — Make expense entry nearly effortless

**Primary UI area:** `app/lib/features/quickadd/quick_add_sheet.dart` and `app/lib/features/shell/adult_shell.dart`

**User problem:** The central **+** opens another menu before the user can perform the most frequent action.

#### Required changes

- Tapping **+** opens **Expense** directly.
- Focus the amount field and present the numeric keyboard automatically.
- Default to:
  - the signed-in member
  - the last-used currency
  - the last-used payment method
  - a clearly visible, recently used budget where appropriate
- Show three to five recent budgets as large selection chips.
- Keep **No budget** easy to find and select.
- Put receipt, split, transaction date, extended notes, and other advanced fields under **More options**.
- Provide a clearly labelled **Add something else** action for Income, Shopping Item, and Task. Do not hide these actions behind a long-press-only gesture.
- Keep private-account entry and role restrictions intact.
- After saving, show an **Undo** action for a short period. Undo must perform a real reversible deletion/tombstone and survive sync—not merely hide a row.
- Preserve the over-budget warning, split validation, unsaved-change protection, and offline save behaviour.

#### Safety rules

- A remembered budget or payment method must always be visible before saving.
- Do not silently reuse an old private account or a different family member.
- Switching family spaces must clear space-specific recent-entry defaults.
- Prevent double taps from creating duplicate transactions.

#### Acceptance criteria

- A repeat user can save an ordinary expense using amount, budget, and save without opening an intermediate action menu.
- A first-time user still sees enough guidance to choose a budget correctly.
- Income, Shopping Item, Task, receipt, split, and private entry remain discoverable.
- Keyboard dismissal, back navigation, and unsaved changes behave consistently.
- Offline save and subsequent sync create exactly one transaction.
- Undo works online and offline without leaving a duplicate server record.

#### Tests

- Widget tests for direct expense launch, remembered defaults, recent budgets, secondary actions, and More options.
- Tests for family-space switching and role-restricted entry.
- Rapid double-tap, app termination, offline retry, and undo tests.
- Golden tests with the keyboard open, long currency values, small screens, and large text.

---

### Phase 2 — Turn Home into a calm daily dashboard

**Primary UI area:** `app/lib/features/home/home_screen.dart`

**User problem:** Balances, alerts, commitments, tasks, budgets, approvals, and activity compete for attention.

#### Target hierarchy

1. Greeting and family switcher
2. Available-to-spend card
3. Income / Spent / Remaining
4. One personalised **Next best action**
5. Up to three important household budgets
6. Up to three recent transactions
7. Clear **See all** destinations

#### Next-best-action behaviour

Create one prioritised queue rather than displaying every alert independently. Suggested priority:

1. An approval or recovery issue requiring the current user
2. An overdue or immediately due commitment
3. An exceeded budget
4. A likely budget overspend
5. An upcoming commitment with insufficient preparation
6. An urgent family task
7. Incomplete setup or a useful getting-started action

Rules:

- Display one primary action, with a count or **Review all** route when others remain.
- Never hide required approvals or rejected sync changes in a dismissal queue.
- Use each user’s role and permissions; never expose private amounts or unauthorised actions.
- Do not show an empty or low-value insight merely to fill the card.
- Dismissal must be deliberate and must not erase the underlying financial record.

#### Budget and activity previews

- Order budget previews by urgency, then by proximity to the limit.
- Preserve household/private separation.
- Keep full search, filters, commitments, tasks, reports, and activity one tap away.
- Hide sections with no useful content rather than producing a long page of empty states.

#### Acceptance criteria

- In moderated testing, users can answer “How much can we spend?” and “What needs my attention?” within five seconds each.
- Home presents one primary next action rather than several competing alerts.
- All existing alerts and workflows remain reachable.
- Large text and long translations do not push essential actions off-screen or cause overflow.
- Private finances and hidden-balance preferences remain respected everywhere.

---

### Phase 3 — Shorten and focus onboarding

**Primary UI areas:**

- `app/lib/features/onboarding/family_setup_screen.dart`
- `app/lib/features/home/home_screen.dart`
- authentication and invitation flows

**User problem:** A new household must understand too many configuration choices before receiving value.

#### Required changes

- Keep the create-family path to three initial decisions:
  - your name
  - family name
  - primary currency
- Show sensible defaults for budget cycle and starter budgets, with a concise edit option.
- Defer secondary currency, profile photo, detailed limits, advanced preferences, and optional configuration until after the first useful journey.
- Preserve and improve the separate join-family path so invited users are not forced through family creation.
- Preserve resumable setup across restarts and connectivity failures.
- After creation, guide the household through:
  1. Add money coming in
  2. Set or confirm one budget
  3. Record one expense
- Use real user-entered data; never create demo transactions.
- Allow family invitations after the owner has reached a useful Home screen.
- Ensure deferred settings are easy to find later.

#### Acceptance criteria

- A user following the default path reaches a useful Home screen in under three minutes.
- The first guided journey ends with a correct balance, budget, and transaction visible on Home.
- Skipping optional steps never leaves onboarding permanently blocked.
- Closing and reopening the app resumes the correct stage without duplicating a family or budget.
- Joining by code, email invitation, or deep link still works after the shorter create flow is introduced.
- Users can complete setup offline only where the backend contract permits it; otherwise the connection requirement is explained clearly and retry is safe.

---

### Phase 4 — Finish product-wide consistency

**Goal:** Remove the small signals that make an otherwise polished product feel unfinished.

#### Localisation and terminology

- Replace user-facing hardcoded strings with generated localisations.
- Audit complete journeys, not only ARB key parity.
- Choose **Budgets** as the normal user-facing term. Keep “envelopes” in internal code and, if useful, a short explanatory hint.
- Verify dates, plural forms, currency labels, validation, dialogs, notifications, settings, errors, and empty states.
- Manually review English, Shona, Ndebele, Spanish, French, and Portuguese.
- Pay special attention to longer French and Portuguese labels.

#### Visual system and brand

- Produce a simpler launcher icon that belongs to the same visual family as the slate/champagne interface.
- Preserve clear family and finance meaning at small launcher sizes.
- Standardise page headers, sheets, buttons, form fields, status banners, empty states, money displays, and confirmation dialogs.
- Use consistent spacing, radius, icon weight, animation, pressed states, and success feedback.
- Ensure every tappable card has a visible affordance and appropriate semantic label.

#### Accessibility and resilience

- Test text scaling at 100%, 150%, and 200%.
- Verify minimum accessible touch targets, contrast, screen-reader labels, and focus order.
- Do not rely on colour alone to communicate pace, danger, income, expense, or sync state.
- Test narrow phones, short screens, tablets, keyboard-open forms, dark mode, and poor connectivity.
- Standardise loading, empty, offline, recoverable-error, and unrecoverable-error presentations.

#### Acceptance criteria

- No unintended English appears in the six critical non-English journeys: onboarding, Home, expense entry, Budgets, Savings, and Lists.
- No critical action overflows or becomes unreachable in the supported layout matrix.
- The new icon is legible at small size and native launcher/splash assets are regenerated together.
- All shared-state messages tell the user what happened and what to do next.

---

### Phase 5 — Create the signature weekly Mhuri moment

**Primary product areas:** existing reports, reminders, commitments, budgets, goals, and sharing infrastructure

**Goal:** Give families a useful, encouraging reason to return even when they do not need to record a transaction.

#### In-app weekly summary

Present a short weekly family review such as:

> **A good week for the family**  
> You spent less on groceries, stayed within four of five budgets, and moved closer to the school-fees goal. Next week, electricity is due on Tuesday.

Include only insights supported by complete-enough data:

- spending compared with the previous equivalent period
- budgets within, near, or above their limits
- progress towards an active goal
- one important upcoming commitment
- one suggested next action

#### Behaviour rules

- Reuse the authoritative transaction, report, commitment, and goal calculations. Do not create a second financial calculation path.
- Respect the family budget cycle, locale, currency display, hidden amounts, roles, and private finances.
- Keep the core weekly summary free; advanced scenarios can remain part of Mhuri Plus.
- Use supportive wording. Avoid “failed,” “bad,” or judgmental scoring.
- When data is insufficient, ask for the smallest useful update instead of inventing a celebration.
- Sharing requires an explicit action and a clear privacy confirmation.
- Lock-screen notifications must not expose amounts when the user has chosen to hide them.
- Reuse existing quiet hours and notification preferences.

#### Acceptance criteria

- Every number in the summary reconciles with the corresponding report or detail screen.
- Users understand why they received each insight.
- A household with sparse data receives a helpful prompt rather than a misleading summary.
- Private transactions never leak into a shared family summary.
- Users can open the summary in-app without enabling notifications.

---

### Phase 6 — Validate with real families

**Goal:** Prove that the experience works for people who did not build it.

#### Participant mix

Recruit 8–12 households covering:

- first-time budgeters and experienced budgeters
- different family sizes and roles
- English, Shona, and Ndebele users, plus checks in the remaining supported languages
- lower-cost Android devices and at least two screen sizes
- reliable and unreliable connectivity
- adults, teens, and children where appropriate and consented

#### Moderated tasks

Ask participants, without coaching, to:

1. Create an account and family.
2. Confirm starter budgets.
3. Add income and record an expense.
4. Explain the Home balance and next action.
5. Invite another family member.
6. Add and check out a shopping item.
7. Record a goal contribution.
8. Find a deferred setting.
9. Use the app in their preferred language and with larger text.
10. Recover after going offline and reconnecting.
11. Understand and optionally share the weekly summary.

#### Reliability scenarios

- Two devices recording transactions while offline
- Reconnection and repeated retries
- Rapid double tapping
- App termination during save
- Session expiry and account recovery
- Concurrent edits to a budget or shopping list
- Rejected or parked sync mutations
- Switching between family spaces
- Permission-restricted and private-finance workflows

#### Release gate

Do not declare the 9.3 experience complete until:

- all financial and sync regression tests pass
- Android release and supported iOS builds succeed
- no critical usability task requires moderator assistance
- no duplicate or lost transaction is observed
- no high-severity accessibility, privacy, permission, or localisation issue remains open
- participants’ observed satisfaction reaches at least 4.6/5, or remaining gaps are explicitly addressed

---

## 5. Analytics and learning loop

Use a small event schema to answer product questions, not to maximise tracking.

### Suggested events

- `quick_add_opened`
- `quick_add_completed`
- `transaction_undo_selected`
- `onboarding_step_completed`
- `guided_first_journey_completed`
- `home_next_action_opened`
- `family_invite_accepted`
- `weekly_summary_viewed`
- `weekly_summary_shared`
- `sync_recovery_opened`

### Review questions

- Where do users abandon expense entry?
- Are remembered defaults saving time without increasing miscategorisation?
- Which Home next action is most useful or most ignored?
- Where does onboarding take longer than expected?
- Do users understand that deferred settings remain available?
- Does the weekly summary lead to a useful financial action rather than only a view?

Review results with qualitative feedback. Analytics must never be the sole basis for judging trust or comprehension.

---

## 6. Explicit non-goals for this cycle

Do not start these as part of the 9.3 experience release:

- another major planning module
- additional dashboard cards
- broader AI functionality
- new subscription tiers
- extra social features
- bank or mobile-money integrations unless separately approved and resourced
- a visual redesign that does not improve a measured user journey

These may be valuable later, but they do not remove the current friction in the core experience.

---

## 7. Suggested implementation order

| Order | Increment | Primary outcome |
|---:|---|---|
| 1 | Baseline and measurement | Safe comparison and regression protection |
| 2 | Expense entry | Faster everyday use |
| 3 | Home hierarchy | Immediate comprehension |
| 4 | Onboarding | Faster time to first value |
| 5 | Localisation, accessibility, and brand consistency | Finished, inclusive product feel |
| 6 | Weekly summary | A memorable return habit |
| 7 | Family beta and reliability validation | Evidence that the experience deserves 9.3 |

Phases 4 and 5 may proceed in parallel only if shared onboarding and localisation changes are coordinated.

---

## 8. Definition of done for every increment

An increment is complete only when:

- the user-facing acceptance criteria pass on real devices
- existing critical workflows remain reachable
- role and private-finance permissions are unchanged or explicitly improved
- online, offline, retry, and restart behaviour is tested where relevant
- English and at least one longer translated locale are checked
- dark mode, small-screen, and large-text layouts are checked
- analytics contains no sensitive financial or family content
- relevant widget, integration, golden, and financial-regression tests are added
- release notes explain the user benefit rather than only the implementation change

---

## 9. Final product bar

The work is successful when a new family can start without instruction, a returning user can record spending almost without thinking, Home makes the next decision obvious, every supported language feels complete, and the weekly summary gives the household a calm reason to talk about money.

That combination—not additional feature count—is what should move Mhuri into **9.3/10 territory**.
