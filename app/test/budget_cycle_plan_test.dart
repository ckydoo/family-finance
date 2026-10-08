import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  test('current plan records income mode, allocations, and closes', () {
    final state = AppState();
    state.envelopes.add(Envelope(
      id: 'food',
      name: 'Food',
      emoji: 'basket',
      limit: const Money(30000, Currency.usd),
    ));

    expect(
      state.saveCurrentBudgetPlan(
        incomeMode: IncomePlanMode.knownMonthly,
        expectedIncome: const Money(100000, Currency.usd),
      ),
      isTrue,
    );
    expect(state.currentBudgetPlan?.allocations['food'], 30000);
    expect(state.currentBudgetPlan?.expectedIncome?.minor, 100000);
    expect(state.closeCurrentBudgetPlan(), isTrue);
    expect(state.currentBudgetPlan?.isClosed, isTrue);
    expect(
      state.saveCurrentBudgetPlan(incomeMode: IncomePlanMode.asEarned),
      isFalse,
    );
  });

  test('use last month restores allocations and income choice', () {
    final state = AppState();
    state.envelopes.add(Envelope(
      id: 'food',
      name: 'Food',
      emoji: 'basket',
      limit: const Money(1000, Currency.usd),
    ));
    final current = state.cycleStart;
    final previous = DateTime(
      current.year,
      current.month - 1,
      state.monthStartDay,
    );
    state.budgetPlans.add(BudgetCyclePlan(
      id: 'previous',
      cycleStart: previous,
      incomeMode: IncomePlanMode.asEarned,
      allocations: const {'food': 45000},
      isClosed: true,
    ));

    expect(state.useLastMonthPlan(), isTrue);
    expect(state.envelopes.single.limit.minor, 45000);
    expect(state.currentBudgetPlan?.incomeMode, IncomePlanMode.asEarned);
    expect(state.currentBudgetPlan?.copiedFrom, previous);
  });

  testWidgets('closing the plan sheet does not use a disposed controller',
      (tester) async {
    final state = AppState();
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: const MaterialApp(
        localizationsDelegates: mhuriLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: BudgetsScreen()),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set up plan'));
    await tester.pumpAndSettle();
    expect(find.text('Plan this month'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test('family activity replaces a local transaction with its server audit',
      () {
    final state = AppState();
    final tx = Tx(
      id: 'tx-1',
      memberId: state.user.id,
      type: TxType.income,
      amount: const Money(2500, Currency.usd),
      method: Method.cash,
      note: 'Vegetable sales',
      when: DateTime(2026, 10, 7, 10),
    );
    state.txs.add(tx);
    expect(state.activityFeed.where((a) => a.entityId == tx.id), hasLength(1));

    final audit = kSyncAdapters['family_activity']!.decode({
      'id': 'audit-1',
      'actor_id': state.user.id,
      'action': 'tx.create',
      'entity': 'transaction',
      'entity_id': tx.id,
      'detail': {'amount_minor': 2500, 'currency': 'USD'},
      'at': '2026-10-07T08:00:00.000Z',
    }) as FamilyActivity;
    state.familyActivities.add(audit);

    expect(state.activityFeed.where((a) => a.entityId == tx.id), hasLength(1));
    expect(state.activityFeed.single.id, 'audit-1');
  });

  test('offline transaction edits and deletions remain visible in audit feed',
      () {
    final state = AppState();
    state.addTx(
      id: 'tx-audit-local',
      type: TxType.expense,
      amount: const Money(1200, Currency.usd),
      memberId: state.user.id,
      method: Method.cash,
      note: 'Market',
    );
    final tx = state.txs.first;
    expect(
      state.updateTx(tx,
          amount: const Money(1500, Currency.usd),
          method: Method.cash,
          note: 'Market corrected',
          when: tx.when),
      isTrue,
    );
    expect(
      state.activityFeed.any((activity) => activity.action == 'tx.update'),
      isTrue,
    );

    expect(state.deleteTx(state.txs.first), isTrue);
    expect(
      state.activityFeed.any((activity) => activity.action == 'tx.delete'),
      isTrue,
    );
  });

  test('family chat sync adapter round-trips a family-scoped message', () {
    final adapter = kSyncAdapters['family_chat_message']!;
    final original = FamilyChatMessage(
      id: 'chat-1',
      familyId: 'space-42',
      senderId: 'member-7',
      text: 'Groceries are due this Friday.',
      createdAt: DateTime(2026, 10, 7, 18, 30),
      status: ChatMessageStatus.delivered,
      referenceType: ChatReferenceType.expense,
      referenceId: 'tx-9',
      referenceTitle: 'Food budget',
      referenceMeta: 'USD 120.00',
      mediaUrl: 'https://cdn.example.test/family/photo.jpg',
      mediaType: 'image',
      sticker: '🎉',
    );

    final json = adapter.encode(
        original,
        const SyncCtx(
          spaceId: 'space-42',
          newId: _noopId,
        ));
    expect(json['space_id'], 'space-42');
    expect(json['status'], 'delivered');
    expect(json['reference_type'], 'expense');
    expect(json['media_type'], 'image');
    expect(json['sticker'], '🎉');

    final roundTripped = adapter.decode(json) as FamilyChatMessage;
    expect(roundTripped.familyId, 'space-42');
    expect(roundTripped.text, 'Groceries are due this Friday.');
    expect(roundTripped.referenceType, ChatReferenceType.expense);
    expect(roundTripped.mediaUrl, 'https://cdn.example.test/family/photo.jpg');
    expect(roundTripped.sticker, '🎉');
  });
}

String _noopId() => 'generated-id';
