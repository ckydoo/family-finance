# Localization status

Mhuri ships in six languages: English (en), Shona (sn), Ndebele (nd),
Spanish (es), French (fr) and Portuguese (pt). Every key lives in
`app/lib/l10n/app_<locale>.arb` and the generated Dart is produced from them
by `flutter gen-l10n` during `flutter pub get`.

## How this is enforced

`app/test/localization_coverage_test.dart` scans `lib/features` for UI strings
that are still written inline in English and compares them against
`app/test/hardcoded_ui_strings.txt`. If a new inline string appears, the test
fails with the exact file and text, so the backlog can only shrink.

To localize a string:

1. Add the key to all six ARB files (the ARB parity test requires all six).
2. Read it through `AppLocalizations.of(context)`.
3. Delete the matching line from `app/test/hardcoded_ui_strings.txt`.

Keys are added mechanically, in batches, in file order.

## Remaining backlog

544 inline strings remain (488 of them unique). Strings built by
interpolation are excluded here; they need the same treatment when touched.

| File | Strings |
|---|---:|
| `lib/features/savings/savings_screen.dart` | 77 |
| `lib/features/members/members_screen.dart` | 63 |
| `lib/features/family_chat/family_chat_screen.dart` | 52 |
| `lib/features/planner/payday_planner_screen.dart` | 35 |
| `lib/features/budgets/budgets_screen.dart` | 29 |
| `lib/features/home/home_screen.dart` | 28 |
| `lib/features/commitments/commitments_screen.dart` | 26 |
| `lib/features/family_tasks/family_tasks_screen.dart` | 26 |
| `lib/features/reports/reports_screen.dart` | 21 |
| `lib/features/lists/lists_screen.dart` | 18 |
| `lib/features/family_chat/family_polls_sheet.dart` | 15 |
| `lib/features/onboarding/family_setup_screen.dart` | 15 |
| `lib/features/savings/advanced_planning_screen.dart` | 14 |
| `lib/features/ai/ask_mhuri_screen.dart` | 13 |
| `lib/features/reports/weekly_summary_sheet.dart` | 13 |
| `lib/features/settings/private_accounts_screen.dart` | 12 |
| `lib/features/legal/legal_screen.dart` | 11 |
| `lib/features/budgets/recurring_ui.dart` | 9 |
| `lib/features/settings/plus_screen.dart` | 9 |
| `lib/features/budgets/period_preparation_screen.dart` | 8 |
| `lib/features/instructions/instructions_screen.dart` | 8 |
| `lib/features/settings/sync_screen.dart` | 8 |
| `lib/features/planner/planning_hub_screen.dart` | 7 |
| `lib/features/settings/settings_screen.dart` | 7 |
| `lib/features/meeting/family_meeting_screen.dart` | 6 |
| `lib/features/members/invite_screen.dart` | 4 |
| `lib/features/teen/teen_zone.dart` | 4 |
| `lib/features/reports/financial_health_screen.dart` | 3 |
| `lib/features/activity/activity_screen.dart` | 1 |
| `lib/features/auth/login_screen.dart` | 1 |
| `lib/features/family_chat/family_chat_voice_note.dart` | 1 |

## Quality note

The Shona and Ndebele strings in this repository were written by the
engineering team. They are consistent but have **not** been reviewed by a
native speaker. Before release, have one Shona and one Ndebele reviewer read
the whole UI once; small wording fixes are cheap now and impossible after
launch.
