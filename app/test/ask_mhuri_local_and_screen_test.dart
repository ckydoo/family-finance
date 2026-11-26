import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/ai/ask_mhuri_local_engine.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/ai/ask_mhuri_screen.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  AppState buildSeededState() {
    final fixedNow = DateTime(2026, 11, 15, 10, 0);
    final state = AppState(clock: () => fixedNow);
    state.accounts.clear();
    state.envelopes.clear();
    state.txs.clear();
    state.txAllocations.clear();
    state.goals.clear();
    state.goalTxs.clear();
    state.recurring.clear();
    state.items.clear();
    state.members
      ..clear()
      ..addAll([
        state.user,
        const Member(
          id: 'partner-1',
          name: 'Rudo',
          emoji: 'person',
          role: Role.adult,
        ),
        const Member(
          id: 'kid-1',
          name: 'Tino',
          emoji: 'child',
          role: Role.kid,
        ),
      ]);

    state.accounts.addAll(const [
      Account(
        id: 'shared-bank',
        name: 'Family Bank',
        emoji: 'bank',
        balance: Money(100000, Currency.usd), // $1,000.00
      ),
      Account(
        id: 'private-cash',
        name: 'Private Cash',
        emoji: 'cash',
        balance: Money(50000, Currency.usd),
        isPrivate: true,
        ownerMemberId: 'partner-1',
      ),
    ]);

    state.envelopes.addAll([
      Envelope(
        id: 'env-groc',
        name: 'Groceries',
        emoji: 'cart',
        limit: const Money(40000, Currency.usd), // $400.00
      ),
      Envelope(
        id: 'env-fuel',
        name: 'Fuel',
        emoji: 'car',
        limit: const Money(20000, Currency.usd), // $200.00
      ),
    ]);

    // Single-envelope expense by current user ($120 -> Groceries)
    state.txs.add(Tx(
      id: 'tx-single',
      accountId: 'shared-bank',
      envelopeId: 'env-groc',
      memberId: state.user.id,
      type: TxType.expense,
      amount: const Money(12000, Currency.usd),
      method: Method.bankCard,
      note: 'Supermarket',
      when: DateTime(2026, 11, 5, 12),
    ));

    // Split expense by Rudo ($100 -> $60 Groceries + $40 Fuel)
    state.txs.add(Tx(
      id: 'tx-split',
      accountId: 'shared-bank',
      envelopeId: 'env-groc',
      memberId: 'partner-1',
      type: TxType.expense,
      amount: const Money(10000, Currency.usd),
      method: Method.bankCard,
      note: 'Hypermarket & Petrol',
      when: DateTime(2026, 11, 8, 15),
    ));
    state.txAllocations.addAll(const [
      TxAllocation(
        id: 'split-1',
        txId: 'tx-split',
        envelopeId: 'env-groc',
        amount: Money(6000, Currency.usd),
      ),
      TxAllocation(
        id: 'split-2',
        txId: 'tx-split',
        envelopeId: 'env-fuel',
        amount: Money(4000, Currency.usd),
      ),
    ]);

    // Private expense ($99) that must never leak into shared facts
    state.txs.add(Tx(
      id: 'tx-private',
      accountId: 'private-cash',
      memberId: 'partner-1',
      type: TxType.expense,
      amount: const Money(9900, Currency.usd),
      method: Method.cash,
      note: 'Secret gift',
      when: DateTime(2026, 11, 9, 9),
    ));

    // Shared goal ($150 saved of $500) + another child's private jar ($40)
    state.goals.addAll([
      Goal(
        id: 'goal-fees',
        name: 'School Fees',
        emoji: 'school',
        target: const Money(50000, Currency.usd),
        deadline: DateTime(2026, 12, 13),
      ),
      const Goal(
        id: 'goal-kid-jar',
        name: 'Tino Jar',
        emoji: 'jar',
        target: Money(10000, Currency.usd),
        isKidJar: true,
        ownerMemberId: 'kid-1',
      ),
    ]);
    state.goalTxs.addAll([
      GoalTx(
        id: 'gtx-1',
        goalId: 'goal-fees',
        byMemberId: state.user.id,
        amount: const Money(15000, Currency.usd),
        at: DateTime(2026, 11, 6),
      ),
      GoalTx(
        id: 'gtx-kid',
        goalId: 'goal-kid-jar',
        byMemberId: 'kid-1',
        amount: const Money(4000, Currency.usd),
        at: DateTime(2026, 11, 7),
      ),
    ]);

    // Recurring bill due before next cycle ($45 Home Wi-Fi)
    state.recurring.add(RecurringRule(
      id: 'rec-wifi',
      name: 'Home Wi-Fi',
      emoji: 'wifi',
      amount: const Money(4500, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: DateTime(2026, 11, 22),
    ));

    // Shopping list: 2 open items ($15.00 est) + 1 done item
    state.items.addAll([
      ListItem(
        id: 'item-1',
        name: 'Bread',
        qty: 2,
        est: const Money(250, Currency.usd),
        state: ItemState.tobuy,
        checkedOut: false,
        addedById: state.user.id,
      ),
      ListItem(
        id: 'item-2',
        name: 'Cooking Oil',
        qty: 1,
        est: const Money(1000, Currency.usd),
        state: ItemState.incart,
        checkedOut: false,
        addedById: state.user.id,
      ),
      ListItem(
        id: 'item-3',
        name: 'Milk',
        qty: 1,
        est: const Money(300, Currency.usd),
        state: ItemState.done,
        checkedOut: true,
        addedById: state.user.id,
      ),
    ]);

    return state;
  }

  test('local engine reconciles splits, excludes private accounts & jars, and answers key queries', () {
    final state = buildSeededState();

    // 1. Named budget lookup includes both single-envelope ($120) and split ($60) = $180 spent, $220 left
    final groc = AskMhuriLocalEngine.tryAnswer(state, 'How much is left in Groceries?');
    expect(groc, isNotNull);
    expect(groc!.answer, contains('US\$ 220.00 left'));
    expect(groc.answer, contains('US\$ 180.00 spent'));

    // 2. Member comparison excludes private $99 expense ($120 vs $100 = $220 shared)
    final members = AskMhuriLocalEngine.tryAnswer(state, 'Who spent the most this month?');
    expect(members, isNotNull);
    expect(members!.answer, contains('US\$ 120.00'));
    expect(members.answer, contains('Rudo'));
    final memberRows = (members.facts['member_spending'] as List).cast<Map>();
    expect(memberRows, hasLength(2));
    expect(memberRows.first['spent_minor'], 12000);
    expect(memberRows.last['spent_minor'], 10000);

    // 3. Purchase affordability checks $1,000 - $220 spend - $150 shared savings - $45 Wi-Fi = $585 cushion
    final afford = AskMhuriLocalEngine.tryAnswer(state, 'Can we afford a US\$ 100 purchase?');
    expect(afford, isNotNull);
    final scenario = afford!.facts['purchase_scenario'] as Map;
    expect(scenario['spendable_before_bills_minor'], 63000); // $630.00
    expect(scenario['upcoming_bills_before_next_cycle_minor'], 4500); // $45.00
    expect(scenario['estimated_after_purchase_minor'], 48500); // $485.00
    expect(scenario['fits_recorded_cash_estimate'], isTrue);

    // 4. Shopping list summary counts only open items
    final shop = AskMhuriLocalEngine.tryAnswer(state, 'What is on our shopping list?');
    expect(shop, isNotNull);
    expect(shop!.answer, contains('2 items'));
    expect(shop.answer, contains('Bread'));

    // 5. Open-ended strategic advice defers to cloud AI when online, while fallback still works offline
    expect(
      AskMhuriLocalEngine.tryAnswer(
        state,
        'Give us advice and tips to reduce our grocery bills next month',
      ),
      isNull,
    );
    final offlineFallback = AskMhuriLocalEngine.fallbackAnswer(
      state,
      'Give us advice and tips to reduce our grocery bills next month',
    );
    expect(offlineFallback.isFallback, isTrue);
    expect(offlineFallback.answer, isNotEmpty);
  });

  testWidgets('AskMhuriScreen answers instantly offline without raw markdown asterisks and links to Budgets',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = buildSeededState();
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AskMhuriScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final starter = find.text('Where are we spending the most?');
    await tester.scrollUntilVisible(
      starter,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(starter);
    await tester.pumpAndSettle();

    expect(find.text('Instant · 0 limit used'), findsOneWidget);
    expect(find.text('NUMBERS USED'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);

    // Scroll to and tap deep-link shortcut to BudgetsScreen
    final budgetsButton = find.text('Budgets');
    await tester.scrollUntilVisible(
      budgetsButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(budgetsButton);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetsScreen), findsOneWidget);
  });
}
