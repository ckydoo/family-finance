import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';

void main() {
  AppState adminState() {
    final state = AppState(clock: () => DateTime(2026, 9, 15));
    const admin = Member(
      id: 'admin-a',
      name: 'Admin A',
      emoji: 'person',
      role: Role.owner,
      serverRole: 'owner',
    );
    state.members
      ..clear()
      ..add(admin);
    state.setRealUser(admin);
    state.switchUser(admin);
    return state;
  }

  test('budget lifecycle edits in place and archives without history deletion',
      () {
    final state = adminState();
    final budget = Envelope(
      id: 'budget-1',
      name: 'Groceries',
      emoji: 'cart',
      limit: const Money(10000, Currency.usd),
    );
    state.envelopes.add(budget);
    state.txs.add(Tx(
      id: 'tx-1',
      memberId: state.realUser.id,
      type: TxType.expense,
      amount: const Money(1800, Currency.usd),
      method: Method.cash,
      note: 'Food',
      when: DateTime(2026, 9, 1),
      envelopeId: budget.id,
    ));

    expect(
      state.updateEnvelope(
        budget,
        name: 'Family groceries',
        limit: const Money(12000, Currency.usd),
        rollover: Rollover.reset,
      ),
      isTrue,
    );
    expect(state.remainingOn(budget).minor, 10200);
    expect(state.archiveEnvelope(budget), isTrue);
    expect(state.envelopes, isEmpty);
    expect(state.txs.single.envelopeId, budget.id);
  });

  test(
      'transaction correction updates totals and soft-removal preserves object',
      () {
    final state = adminState();
    final tx = Tx(
      id: 'tx-1',
      memberId: state.realUser.id,
      type: TxType.expense,
      amount: const Money(2000, Currency.usd),
      method: Method.cash,
      note: 'Groceries',
      when: DateTime.now(),
    );
    state.txs.add(tx);
    expect(
      state.updateTx(
        tx,
        amount: const Money(1800, Currency.usd),
        method: Method.bankCard,
        note: 'Groceries corrected',
        when: tx.when,
      ),
      isTrue,
    );
    expect(state.txs.single.amount.minor, 1800);
    final corrected = state.txs.single;
    expect(state.deleteTx(corrected), isTrue);
    expect(state.txs, isEmpty);
  });

  test('shopping, savings, recurring and chore lifecycles are complete', () {
    final state = adminState();
    final item = ListItem(
      id: 'item-1',
      name: 'Sugar',
      qty: 1,
      est: const Money(230, Currency.usd),
      addedById: state.realUser.id,
    );
    state.items.add(item);
    expect(
      state.updateItem(item,
          name: 'Sugar 2kg', qty: 2, estimate: const Money(250, Currency.usd)),
      isTrue,
    );
    expect(item.qty, 2);

    const goal = Goal(
      id: 'goal-1',
      name: 'Car',
      emoji: 'goal',
      target: Money(350000, Currency.usd),
    );
    state.goals.add(goal);
    expect(
        state.updateGoal(goal,
            name: 'Family car', target: const Money(400000, Currency.usd)),
        isTrue);
    final editedGoal = state.goals.single;
    expect(state.completeGoal(editedGoal), isTrue);
    expect(state.goals.single.status, 'done');
    expect(state.archiveGoal(state.goals.single), isTrue);
    expect(state.goals, isEmpty);

    final rule = RecurringRule(
      id: 'rule-1',
      name: 'Rent',
      emoji: 'home',
      amount: const Money(6000, Currency.usd),
      memberId: state.realUser.id,
      method: Method.bankTransfer,
      frequency: Frequency.monthly,
      nextDue: DateTime(2026, 10, 1),
    );
    state.recurring.add(rule);
    expect(
        state.updateRecurring(rule,
            name: 'House rent',
            amount: const Money(6500, Currency.usd),
            frequency: Frequency.monthly,
            nextDue: rule.nextDue,
            memberId: rule.memberId,
            method: rule.method),
        isTrue);
    expect(state.archiveRecurring(rule), isTrue);
    expect(state.recurring, isEmpty);

    final chore = state.addChore(name: 'Wash car', starsReward: 3)!;
    expect(
        state.updateChore(chore,
            name: 'Wash the car', starsReward: 5, assigneeId: 'kid-1'),
        isTrue);
    expect(chore.assigneeMemberId, 'kid-1');
    expect(state.archiveChore(chore), isTrue);
    expect(state.chores, isEmpty);
  });

  test('co_parent server role maps to Family Admin', () {
    final members = membersFromServer(
      membershipRows: const [
        {
          'space_id': 'family-a',
          'user_id': 'admin-b',
          'role': 'co_parent',
          'invite_status': 'active',
        },
      ],
      profileRows: const [
        {'id': 'admin-b', 'name': 'Admin B'},
      ],
      meId: 'admin-b',
    );
    expect(members.single.role, Role.admin);
    expect(members.single.serverRole, 'co_parent');
  });

  test('hardening migration contains server-side isolation and spoof guards',
      () {
    final sql = File('../backend/migrations/013_crud_ownership_permissions.sql')
        .readAsStringSync();
    expect(sql, contains('is_family_admin'));
    expect(sql, contains('LAST_ADMIN'));
    expect(sql, contains('new.created_by := auth.uid()'));
    expect(sql, contains('new.member_id := auth.uid()'));
    expect(sql, contains('remove_family_member'));
    expect(sql, isNot(contains('auth.uid() IS NOT NULL')));
  });

  test('onboarding reliability migration preserves explicit empty selections',
      () {
    final sql = File(
      '../backend/migrations/016_onboarding_setup_reliability.sql',
    ).readAsStringSync();
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains("'onboarding_templates'"));
    expect(sql, contains('template_key is not null'));
    expect(sql, contains('not(template_key=any(v_keys))'));
    expect(
      sql,
      isNot(contains('jsonb_array_length(p_templates) > 0')),
      reason: 'an empty selection must archive previous starter templates',
    );
  });
}
