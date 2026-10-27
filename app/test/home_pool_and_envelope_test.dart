import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  test('family pool follows income and expense activity', () {
    final state = AppState();
    state.members.add(state.user);

    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(500, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      note: 'Income',
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(250, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Expense',
    );

    expect(state.poolCombined(Currency.usd).minor, 25000);
    expect(state.poolCombined(Currency.zwg).minor, 25000 * state.rate);
  });

  test('soft-deleted transactions do not affect family or private balances',
      () {
    final state = AppState();
    const shared = Account(
      id: 'shared-cash',
      name: 'Family cash',
      emoji: 'cash',
      balance: Money(500, Currency.usd),
    );
    const privateAccount = Account(
      id: 'private-cash',
      name: 'Private cash',
      emoji: 'cash',
      balance: Money(300, Currency.usd),
      isPrivate: true,
      ownerMemberId: 'me',
    );
    state.accounts.addAll([shared, privateAccount]);
    state.txs.addAll([
      Tx(
        id: 'deleted-family-expense',
        memberId: 'me',
        type: TxType.expense,
        amount: const Money(10000, Currency.usd),
        method: Method.cash,
        note: 'Removed family expense',
        when: DateTime(2026, 10, 1),
        deletedAt: DateTime(2026, 10, 2),
      ),
      Tx(
        id: 'deleted-private-income',
        accountId: privateAccount.id,
        memberId: 'me',
        type: TxType.income,
        amount: const Money(10000, Currency.usd),
        method: Method.cash,
        note: 'Removed private income',
        when: DateTime(2026, 10, 1),
        deletedAt: DateTime(2026, 10, 2),
      ),
    ]);

    expect(state.familyTransactions, isEmpty);
    expect(state.poolCombined(Currency.usd).minor, 500);
    expect(state.privateAccountBalance(privateAccount).minor, 300);
  });

  test('savings reduce available cash without reducing total family money', () {
    final state = AppState();
    state.members.add(state.user);
    const goal = Goal(
      id: 'emergency',
      name: 'Emergency fund',
      emoji: 'goal',
      target: Money(50000, Currency.usd),
    );
    state.goals.add(goal);

    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(500, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      note: 'Income',
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(250, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Expense',
    );
    state.contribute(goal, Money.fromMajor(100, Currency.usd));

    expect(state.poolCombined(Currency.usd).minor, 25000);
    expect(state.totalSaved(Currency.usd).minor, 10000);
    expect(state.availableToSpend(Currency.usd).minor, 15000);
    expect(
      state.availableToSpend(Currency.usd).minor +
          state.totalSaved(Currency.usd).minor,
      state.poolCombined(Currency.usd).minor,
    );
  });

  test('report totals and envelope spending use the same budget cycle', () {
    final state = AppState();
    state.members.add(state.user);
    state.monthStartDay = 25;
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(300, Currency.usd),
    );
    final groceries = state.envelopes.single;

    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(40, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Inside cycle',
      envelopeId: groceries.id,
      when: state.cycleStart.add(const Duration(hours: 1)),
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(90, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Before cycle',
      envelopeId: groceries.id,
      when: state.cycleStart.subtract(const Duration(hours: 1)),
    );

    expect(state.spentOn(groceries).minor, 4000);
    expect(state.monthSpend.minor, 4000);
  });

  testWidgets('home explains when close-to-limit alert clears', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 11);
    final state = AppState(clock: () => now);
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(300, Currency.usd),
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(200, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Groceries',
      envelopeId: state.envelopes.single.id,
      when: now,
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Groceries may exceed its budget this cycle'),
      findsOneWidget,
    );
  });

  testWidgets('home warns before cycle end and explains the reset day',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<void> pumpAt(DateTime date) async {
      final state = AppState(clock: () => date)..monthStartDay = 25;
      state.members.add(state.user);
      state.addEnvelope(
        name: 'Groceries',
        limit: Money.fromMajor(100, Currency.usd),
      );
      await tester.pumpWidget(
        AppScope(
          notifier: state,
          child: MaterialApp(
            theme: buildAppTheme(),
            localizationsDelegates: mhuriLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpAt(DateTime(2026, 10, 24, 23, 45));
    expect(find.text('Your budget month ends tomorrow'), findsOneWidget);
    expect(find.textContaining('starts Oct 25, 2026'), findsOneWidget);

    await pumpAt(DateTime(2026, 10, 25, 8));
    expect(find.text('A new budget month starts today'), findsOneWidget);
    expect(find.textContaining('may show 0'), findsOneWidget);
  });

  testWidgets('home does not flag a budget that is exactly at its limit',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 11);
    final state = AppState(clock: () => now);
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(100, Currency.usd),
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(100, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Groceries',
      envelopeId: state.envelopes.single.id,
      when: now,
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsNothing);
    expect(find.text('Groceries is close to its limit'), findsNothing);
  });

  testWidgets('home budget alert can be dismissed by swiping', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 11);
    final state = AppState(clock: () => now);
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(100, Currency.usd),
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(120, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Groceries',
      envelopeId: state.envelopes.single.id,
      when: now,
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Groceries is over budget'), findsOneWidget);
    await tester.drag(
        find.text('Groceries is over budget'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Needs attention'), findsNothing);
  });

  testWidgets('home shows one budget alert with a count for other issues',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 10, 11);
    final state = AppState(clock: () => now);
    state.members.add(state.user);
    for (final name in ['Groceries', 'Transport', 'School']) {
      state.addEnvelope(
        name: name,
        limit: Money.fromMajor(100, Currency.usd),
      );
      state.addTx(
        type: TxType.expense,
        amount: Money.fromMajor(120, Currency.usd),
        memberId: state.user.id,
        method: Method.bankCard,
        note: name,
        envelopeId: state.envelopes.last.id,
        when: now,
      );
    }

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3+ budgets need attention'), findsOneWidget);
    expect(find.text('Groceries is over budget'), findsNothing);
    expect(find.text('Transport is over budget'), findsNothing);
    expect(find.text('School is over budget'), findsNothing);

    await tester.drag(
        find.text('3+ budgets need attention'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('2+ budgets need attention'), findsOneWidget);
  });

  testWidgets('home shows only the nearest upcoming recurring item',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Household',
      limit: Money.fromMajor(100, Currency.usd),
    );
    final today = DateTime.now();
    for (var i = 0; i < 3; i++) {
      state.addRecurring(
        name: 'Bill ${i + 1}',
        emoji: 'bill',
        amount: Money.fromMajor(20, Currency.usd),
        memberId: state.user.id,
        method: Method.bankTransfer,
        frequency: Frequency.monthly,
        nextDue: today.add(Duration(days: i + 1)),
      );
    }

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bill 1'), findsOneWidget);
    expect(find.text('Bill 2'), findsNothing);
    expect(find.text('Bill 3'), findsNothing);
    expect(find.text('2 more coming up'), findsOneWidget);
  });

  testWidgets('upcoming recurring item can be dismissed by swiping',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Household',
      limit: Money.fromMajor(100, Currency.usd),
    );
    state.addRecurring(
      name: 'Internet',
      emoji: 'wifi',
      amount: Money.fromMajor(20, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: DateTime.now().add(const Duration(days: 5)),
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Internet'), findsOneWidget);
    await tester.drag(find.text('Internet'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Internet'), findsNothing);
  });

  testWidgets('home envelope card opens its details', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(300, Currency.usd),
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Free after commitments'), findsNothing);

    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    expect(find.text('Move money'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
