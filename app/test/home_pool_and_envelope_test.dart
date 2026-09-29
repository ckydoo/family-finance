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

    final availableToday = find.textContaining('Available today');
    await tester.scrollUntilVisible(
      availableToday,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(availableToday);
    await tester.pumpAndSettle();
    expect(find.text('Reserved for budgets'), findsOneWidget);
    expect(find.text('Free after commitments'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    expect(find.text('Move money'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
