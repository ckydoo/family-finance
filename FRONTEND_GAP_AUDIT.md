# Frontend Gap Audit — vs. premium fintech standards
_Compared against: Monzo, Revolut, N26, YNAB, Qapital, Apple Wallet. Audited 2026-09-21; **all 13 gaps implemented same day — see ROADMAP "Premium frontend pass".** Wave 2 (interface pass 3) also done: i18n fold-in, pull-to-refresh, skeletons, error+retry, undo, dark splash, status bar, tablet cap, semantics. Remaining: regenerate SCREENSHOTS.html (dark mode + new visuals) after the user-machine checkpoint; G8 ramp fully adopting opportunistically; G9 priming slide ships without the interactive demo variant; G12 pill is driven by the demo pendingOps counter until live sync._

## Where we're already at par (don't touch)
- **Design system**: tokenized colors/radii/shadows, one font family with real weights, platform-adaptive transitions (Zoom/Cupertino), InkSparkle — most hobby apps never get here.
- **Nav**: 4-tab + FAB with animated pill — same pattern Monzo/Revolut converged on.
- **Icon discipline**: semantic icon keys, zero emoji in UI — cleaner than several shipping fintechs.
- **Empty states**: dedicated widget with icon + copy on real screens.
- **Launcher icon + native splash**: configured, waiting for device week (M8).
- **Sealed Kids Mode / role-gated surfaces** — genuinely rare; most family apps fake this.

## Tier 1 — "Feels premium" gaps (highest perception impact)

| # | Gap | We have today | Premium standard | Effort |
|---|-----|---------------|------------------|--------|
| G1 | **Dark mode** | None (no dark ThemeData anywhere). Manual large-text toggle only | System-following dark + OLED true-black. Table stakes since ~2019 — its absence is the #1 tell of a non-premium app | M |
| G2 | **Motion layer** | Zero `AnimationController`/`Tween`/`Hero` in the whole lib. Hero amounts *snap*, rings paint instantly, goal-reached is a snackbar | Count-up/tween on money figures, rings animate to value on load & change, goal-reached gets a one-second confetti/celebration moment (Qapital/YNAB do this and users screenshot it) | M |
| G3 | **Haptics** | Zero `HapticFeedback` calls | Selection tick on tab switch, light impact on collect/approve/save, success pattern on OTP/confirm. Feels "expensive" for ~15 lines total | S |
| G4 | **Reports data-viz** | `LinearProgressIndicator` bars | Touch-scrub category donut + month trend (custom painter, no chart pkg needed). Reports is the screen investors/reviewers open first | M–L |
| G5 | **Balance privacy** | Always-visible balances | Eye-toggle mask (Monzo) + blur in the app-switcher snapshot (secure flag). For a *family money* app this is trust, not polish | S |

## Tier 2 — Accessibility & international correctness

| # | Gap | We have today | Premium standard | Effort |
|---|-----|---------------|------------------|--------|
| G6 | **A11y pass** | `tooltip:` on ~6 icon buttons; manual 1.2× large-text | Full `Semantics` audit (every icon-only control), 48dp touch targets, WCAG-AA contrast check (kInkFaint on kBg unverified), honor `disableAnimations` | M |
| G7 | **Locale-aware formatting** | Custom money formatter, no `intl` — same `1,234.56` for all 6 locales | `1.234,56` for es/fr/pt, localized dates; found: login error still shows a ZW-format example number (`0772 123 456`) | S–M |
| G8 | **Type scale** | Ad-hoc sizes (26px w800 hero, etc.) | Named ramp (display/title/body/caption) as tokens; consider neutral body face paired with Poppins display for small-size legibility | S |

## Tier 3 — Product-surface polish

| # | Gap | We have today | Premium standard | Effort |
|---|-----|---------------|------------------|--------|
| G9 | **Onboarding depth** | 3 static slides → login | Interactive value demo, animated progress dots, and a *notification priming* screen before the OS permission dialog (skip it and opt-in rates halve) | M |
| G10 | **Signature scroll moment** | Plain scrolling ListView, static header | Pool card collapses/morphs into the app bar on scroll (SliverAppBar) — the "this app is alive" moment | M |
| G11 | **Kids Mode delight** | Clean but austere (icons, no joy) | Star-burst on chore confirm, bigger illustration energy — kids are the harshest UX critics | S–M |
| G12 | **Sync/offline UI states** | Local-first, sync UI minimal | Offline/syncing status pill + retry affordances — M3 live mode will need this anyway | S |
| G13 | **PIN error feedback** | Text error only | Pin-pad shake + haptic on wrong code | S |

## Do NOT copy from premium apps (anti-recommendations)
- Stories/feed, cashback ad slots, crypto promos — engagement bait, wrong product values.
- Over-animation (spring on everything) — motion should confirm actions, not perform.
- Bottom-sheet overload — we already have the right sheet count.
- Feature-density on Home — our calm single-pool hero is a differentiator; protect it.

## Suggested ladder (if you greenlight)
1. **Polish pass 2a — "Premium feel"** (G1 dark mode → G3 haptics → G5 privacy → G2 motion): ~2 sessions. Takes the rating 8 → 8.5–9 territory on feel alone.
2. **Polish pass 2b — "Correct & inclusive"** (G7 formatting + ZW example fix → G6 a11y → G8 type scale): ~1 session.
3. **Polish pass 2c — "Wow"** (G4 interactive reports → G10 collapsing header → G9 onboarding → G11/G13): ~2 sessions, pairs naturally with M8 device week.

## Known non-app items
- `SCREENSHOTS.html` gallery still renders the old emoji style (disclosed earlier) — regenerate *after* this pass so it shows dark mode + motion stills.
- G2/G3 need real-device feel-check → fold verification into M8 checkpoint.


---

## i18n wave 3 (l10n completion) — DONE ✅ 2026-09-21
7 remaining EN-only surfaces migrated to AppLocalizations; 93 new keys ×6 ARBs with full parity; 8 enum-label call sites routed through l10n helpers; static gate: 17/17 surfaces, 0 leftover strings, 0 const regressions.


---

## Premium pass 2 (A1 sync completion + Track B) — DONE ✅ 2026-09-21
Sync 7→10 entities (chore, mukando, recurring_rule) + schema updated_at fixes · two-pane budgets/meeting ≥900dp · soft refresh · donut a11y · i18n to absolute zero EN literals (315 keys ×6) · 5 latent compile bugs fixed · gates: 59-file Dart-aware balance ✓, 315×6 parity ✓, 297 refs ✓, EN sweep 0 ✓.


---

## Hardening continuation — DONE ✅ 2026-09-21
Live-mode blockers fixed pre-emptively: client ids → uuid v4 (server columns are uuid; FakeServer had masked this), space-adoption wipe covers chore/recurring/circle, resume-sync on app foreground, +3 engine tests (101 total). Gates all green (60 files / 315×6 / 297 refs / EN 0).
