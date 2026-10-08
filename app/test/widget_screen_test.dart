import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/activity/activity_screen.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/features/family_chat/family_chat_screen.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/features/lists/lists_screen.dart';
import 'package:mhuri_money/features/onboarding/family_setup_screen.dart';
import 'package:mhuri_money/features/reports/reports_screen.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/features/settings/settings_screen.dart';
import 'package:mhuri_money/features/teen/teen_zone.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

import 'fake_auth.dart';

/// M7 - every main screen pumps against REAL app-created data (no fixtures:
/// the app ships with an empty database) without throwing, and the key
/// content is actually on screen.
void main() {
  Future<AppState> seeded() async {
    final s = AppState(); // no db → in-memory, ready immediately
    s.addEnvelope(name: 'Groceries', limit: Money.fromMajor(150, Currency.usd));
    s.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(12.50, Currency.usd),
      memberId: s.user.id,
      method: Method.cash,
      note: 'FreshMart groceries',
      envelopeId: s.envelopes.first.id,
    );
    s.goals.insert(
      0,
      const Goal(
        id: 'g-school',
        name: 'School Fees',
        emoji: 'school',
        target: Money(30000, Currency.usd),
      ),
    );
    s.addItem('Rice 2kg', 1, Money.fromMajor(10, Currency.usd));
    return s;
  }

  Widget harness(AppState s, Widget child) => AppScope(
        notifier: s,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  void sizeWindow(WidgetTester tester) {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('Home renders the pool card and the bell opens reminders',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Available to spend'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none));
    await tester.pumpAndSettle();
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.textContaining('Scheduled on this device'), findsOneWidget);
  });

  testWidgets('Home exposes the family switcher and Settings separately',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home_signed_in_avatar')), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.byTooltip('Settings'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Family Chat task action opens Tasks even when none exist',
      (tester) async {
    sizeWindow(tester);
    final s = AppState();
    await tester.pumpWidget(harness(s, const FamilyChatScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add photo or task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family tasks'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks & responsibilities'), findsOneWidget);
    expect(find.text('No open family tasks to attach yet.'), findsNothing);
  });

  testWidgets('tapping an attached chat task opens that task detail',
      (tester) async {
    sizeWindow(tester);
    final s = AppState();
    final task = FamilyTask(
      id: 'school-uniforms',
      title: 'Buy school uniforms',
      createdAt: DateTime(2026, 10, 8),
      dueDate: DateTime(2026, 10, 8),
      points: 1,
    );
    s.familyTasks.add(task);
    s.familyChatMessages.add(FamilyChatMessage(
      id: 'task-message',
      familyId: 'family',
      senderId: s.user.id,
      text: 'Please handle this.',
      createdAt: DateTime(2026, 10, 8, 14, 56),
      referenceType: ChatReferenceType.task,
      referenceId: task.id,
      referenceTitle: task.title,
      referenceMeta: 'Due Oct 8 • 1 pts',
    ));

    await tester.pumpWidget(harness(s, const FamilyChatScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buy school uniforms'));
    await tester.pumpAndSettle();

    expect(find.text('Tasks & responsibilities'), findsOneWidget);
    expect(find.text('Start task'), findsOneWidget);
  });

  testWidgets('approving a proposal closes its dialog without dead context',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    final envelope = s.envelopes.first;
    s.proposals.add(Proposal(
      id: 'proposal-approve-test',
      teenId: s.user.id,
      amount: Money.fromMajor(2, Currency.usd),
      envelopeId: envelope.id,
      reason: 'Ice cream',
    ));
    await tester.pumpWidget(harness(s, const HomeScreen()));
    await tester.pumpAndSettle();

    final reviewButton = find.text('Review');
    expect(reviewButton, findsOneWidget);
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Approve'), findsNothing);
    expect(
      s.txs.any((tx) => tx.note == 'Approved: Ice cream'),
      isTrue,
    );
  });

  testWidgets('Budgets renders envelopes and the recurring section',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const BudgetsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Groceries'), findsAtLeastNWidgets(1));
    expect(find.text('Regular payments'), findsOneWidget);
  });

  testWidgets('budget transfer dropdown survives refreshed envelope objects',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    s.addEnvelope(
      name: 'Transport',
      limit: Money.fromMajor(80, Currency.usd),
    );
    await tester.pumpWidget(harness(s, const BudgetsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    final refreshed = [
      for (final envelope in s.envelopes)
        Envelope(
          id: envelope.id,
          name: envelope.name,
          emoji: envelope.emoji,
          limit: envelope.limit,
          rollover: envelope.rollover,
          isPersonal: envelope.isPersonal,
          isArchived: envelope.isArchived,
        ),
    ];
    s.envelopes
      ..clear()
      ..addAll(refreshed);
    s.notifyListeners();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Move money'), findsWidgets);
  });

  testWidgets('Activity renders the seeded transactions', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const ActivityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No activity yet'), findsNothing);
    expect(find.textContaining('FreshMart'), findsAtLeastNWidgets(1));
  });

  testWidgets('transaction opens read-only before edit controls',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const ActivityScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('FreshMart groceries'));
    await tester.pumpAndSettle();

    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Remove transaction'), findsNothing);

    await tester.tap(find.text('Edit transaction'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Remove transaction'), findsOneWidget);
  });

  testWidgets('Activity can filter income and expenses', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    s.addTx(
      type: TxType.income,
      amount: Money.fromMajor(250, Currency.usd),
      memberId: s.user.id,
      method: Method.bankTransfer,
      note: 'September salary',
    );
    await tester.pumpWidget(harness(s, const ActivityScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Filter activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(find.text('September salary'), findsOneWidget);
    expect(find.text('FreshMart groceries'), findsNothing);

    await tester.tap(find.byTooltip('Filter activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Expenses'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(find.text('September salary'), findsNothing);
    expect(find.text('FreshMart groceries'), findsOneWidget);
  });

  testWidgets('Savings renders the family goals', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const SavingsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('School Fees'), findsAtLeastNWidgets(1));
  });

  testWidgets('Teen Zone renders one earning as a readable summary row',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    const teen = Member(
      id: 'teen-earning-test',
      name: 'Myla',
      emoji: 'student',
      role: Role.teen,
    );
    s.members.add(teen);
    s.switchUser(teen);
    s.setRealUser(teen);
    s.addEarning(
      Money.fromMajor(5, Currency.usd),
      'Did a job for Uncle',
    );

    await tester.pumpWidget(harness(s, const TeenZone()));
    await tester.pumpAndSettle();

    expect(find.text('Did a job for Uncle'), findsOneWidget);
    expect(find.text('+US\$ 5.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Teen preview identifies the member and can exit immediately',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    final owner = s.user;
    const myla = Member(
      id: 'member-myla-preview',
      name: 'Myla',
      emoji: 'student',
      role: Role.teen,
    );
    if (!s.members.any((member) => member.id == owner.id)) {
      s.members.insert(0, owner);
    }
    s.members.add(myla);
    s.setRealUser(owner);
    s.switchUser(myla);

    await tester.pumpWidget(harness(s, const TeenZone()));
    await tester.pumpAndSettle();

    expect(find.text('Previewing as Myla'), findsOneWidget);
    expect(find.text('Hi, Myla'), findsOneWidget);
    expect(find.text('Teen Zone · 13–17'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(s.isPreviewing, isFalse);
    expect(s.user.id, owner.id);
    expect(find.text('Previewing as Myla'), findsNothing);
  });

  testWidgets('Reports offers the family meeting and CSV export',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const ReportsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Compared with last cycle'), findsOneWidget);
    expect(find.text('Plan vs actual'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Family progress'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Family progress'), findsOneWidget);
    expect(find.text('Bills and debts'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Start the family meeting'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Start the family meeting'), findsOneWidget);
    expect(find.text('Export transactions (CSV)'), findsOneWidget);
  });

  testWidgets('Settings renders notifications, quiet hours and month start',
      (tester) async {
    sizeWindow(tester);
    final auth = AuthController(env: testEnv(), service: FakeAuthService());
    await auth.signIn('tariro@example.com', 'correct-password');
    final s = AppState(env: testEnv(), auth: auth);
    await tester.pumpWidget(harness(s, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Reminders on this device'), findsOneWidget);
    expect(find.text('Starts on'), findsOneWidget);
    expect(find.textContaining('Quiet hours'), findsOneWidget);
    expect(find.text('Signed in as'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Edit profile'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Nyasha');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(s.user.name, 'Nyasha');
  });

  testWidgets('Lists renders the seeded shopping list', (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, const ListsScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rice'), findsAtLeastNWidgets(1));
  });

  testWidgets('Onboarding shows the first slide with the brand mark',
      (tester) async {
    sizeWindow(tester);
    final s = await seeded();
    await tester.pumpWidget(harness(s, FamilySetupScreen(state: s)));
    await tester.pumpAndSettle();

    expect(find.text('Mhuri'), findsOneWidget);
  });
}
