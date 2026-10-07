/// The synced entity set (M3 + premium pass). The family ledger - money,
/// budgets, lists, approvals, earnings - syncs, and as of the premium pass so
/// do chores (stars), the savings-circle header (mukando, one per family) and
/// recurring rules. Wallet balances stay device-local (see ROADMAP notes).
library;

import '../models/models.dart';
import '../money/money.dart';
import '../utils/ids.dart';

/// Context a mapper needs beyond the domain object itself.
class SyncCtx {
  final String spaceId;
  final String? defaultListId;
  final String Function() newId;

  const SyncCtx({
    required this.spaceId,
    this.defaultListId,
    required this.newId,
  });
}

/// One synced table: server name + JSON round-trip for its domain type.
/// [decode] may return one of two types for `kid_request` (KidRequest for
/// kind=money, Proposal for kind=expense_proposal) - the engine routes both.
class SyncAdapter {
  final String entity;
  final String table;
  final bool spaceScoped; // does the server table carry space_id directly?
  final Map<String, Object?> Function(Object domain, SyncCtx ctx) encode;
  final Object Function(Map<String, Object?> json) decode;

  const SyncAdapter({
    required this.entity,
    required this.table,
    required this.spaceScoped,
    required this.encode,
    required this.decode,
  });
}

// ── enum bridges (domain names differ from server CHECK values) ────────────

const Map<Method, String> _methodOut = {
  Method.cash: 'cash',
  Method.mobileMoney: 'mobile_money',
  Method.bankCard: 'bank_card',
  Method.bankTransfer: 'bank_transfer',
  Method.agent: 'agent',
  Method.other: 'other',
};

Method _methodIn(String v) => switch (v) {
      'bank_card' => Method.bankCard,
      'bank_transfer' => Method.bankTransfer,
      'mobile_money' => Method.mobileMoney,
      'agent' => Method.agent,
      _ => Method.values.byName(v),
    };

String _rolloverOut(Rollover r) => switch (r) {
      Rollover.roll => 'rollover',
      _ => r.name,
    };

Rollover _rolloverIn(String v) =>
    v == 'rollover' ? Rollover.roll : Rollover.values.byName(v);

Currency _currencyIn(Object? value) {
  final s = (value ?? '').toString().toLowerCase();
  if (s == 'zig' || s == 'zwg') return Currency.zwg;
  if (s == 'usd') return Currency.usd;
  return Currency.values.firstWhere(
    (c) => c.name.toLowerCase() == s,
    orElse: () => Currency.usd,
  );
}

Money _moneyOf(Map<String, Object?> j, String minorKey, String currencyKey) =>
    Money(j[minorKey] as int, _currencyIn(j[currencyKey]));

DateTime? _iso(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

// ── adapters ───────────────────────────────────────────────────────────────

final kSyncAdapters = <String, SyncAdapter>{
  'tx_allocation': SyncAdapter(
    entity: 'tx_allocation',
    table: 'transaction_split',
    spaceScoped: true,
    encode: (d, ctx) {
      final a = d as TxAllocation;
      return {
        'id': a.id,
        'space_id': ctx.spaceId,
        'transaction_id': a.txId,
        'envelope_id': a.envelopeId,
        'amount_minor': a.amount.minor,
        'currency': a.amount.currency.code
      };
    },
    decode: (j) => TxAllocation(
        id: j['id'] as String,
        txId: j['transaction_id'] as String,
        envelopeId: j['envelope_id'] as String,
        amount: _moneyOf(j, 'amount_minor', 'currency')),
  ),
  'family_debt': SyncAdapter(
    entity: 'family_debt',
    table: 'family_debt',
    spaceScoped: true,
    encode: (d, ctx) {
      final v = d as FamilyDebt;
      return {
        'id': v.id,
        'space_id': ctx.spaceId,
        'name': v.name,
        'direction': v.direction.name,
        'principal_minor': v.principal.minor,
        'currency': v.principal.currency.code,
        'counterparty_member_id': v.counterpartyMemberId,
        'due_date': v.dueDate?.toUtc().toIso8601String(),
        'status': v.status,
        'created_by': v.createdById
      };
    },
    decode: (j) => FamilyDebt(
        id: j['id'] as String,
        name: j['name'] as String,
        direction: DebtDirection.values.byName(j['direction'] as String),
        principal: _moneyOf(j, 'principal_minor', 'currency'),
        counterpartyMemberId: j['counterparty_member_id'] as String?,
        dueDate: _iso(j['due_date']),
        status: j['status'] as String? ?? 'active',
        createdById: j['created_by'] as String),
  ),
  'debt_repayment': SyncAdapter(
    entity: 'debt_repayment',
    table: 'debt_repayment',
    spaceScoped: false,
    encode: (d, ctx) {
      final v = d as DebtRepayment;
      return {
        'id': v.id,
        'debt_id': v.debtId,
        'member_id': v.memberId,
        'amount_minor': v.amount.minor,
        'currency': v.amount.currency.code,
        'paid_at': v.paidAt.toUtc().toIso8601String()
      };
    },
    decode: (j) => DebtRepayment(
        id: j['id'] as String,
        debtId: j['debt_id'] as String,
        memberId: j['member_id'] as String,
        amount: _moneyOf(j, 'amount_minor', 'currency'),
        paidAt: _iso(j['paid_at']) ?? DateTime.now()),
  ),
  'contribution_campaign': SyncAdapter(
    entity: 'contribution_campaign',
    table: 'contribution_campaign',
    spaceScoped: true,
    encode: (d, ctx) {
      final c = d as ContributionCampaign;
      return {
        'id': c.id,
        'space_id': ctx.spaceId,
        'name': c.name,
        'target_minor': c.target.minor,
        'currency': c.target.currency.code,
        'deadline': c.deadline.toUtc().toIso8601String(),
        'created_by': c.createdById,
        'status': c.status
      };
    },
    decode: (j) => ContributionCampaign(
        id: j['id'] as String,
        name: j['name'] as String,
        target: _moneyOf(j, 'target_minor', 'currency'),
        deadline: _iso(j['deadline']) ?? DateTime.now(),
        createdById: j['created_by'] as String,
        status: j['status'] as String? ?? 'active'),
  ),
  'contribution_pledge': SyncAdapter(
    entity: 'contribution_pledge',
    table: 'contribution_pledge',
    spaceScoped: false,
    encode: (d, ctx) {
      final p = d as ContributionPledge;
      return {
        'id': p.id,
        'campaign_id': p.campaignId,
        'member_id': p.memberId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.code,
        'created_at': p.createdAt.toUtc().toIso8601String()
      };
    },
    decode: (j) => ContributionPledge(
        id: j['id'] as String,
        campaignId: j['campaign_id'] as String,
        memberId: j['member_id'] as String,
        amount: _moneyOf(j, 'amount_minor', 'currency'),
        createdAt: _iso(j['created_at']) ?? DateTime.now()),
  ),
  'contribution_payment': SyncAdapter(
    entity: 'contribution_payment',
    table: 'contribution_payment',
    spaceScoped: false,
    encode: (d, ctx) {
      final p = d as ContributionPayment;
      return {
        'id': p.id,
        'campaign_id': p.campaignId,
        'member_id': p.memberId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.code,
        'paid_at': p.paidAt.toUtc().toIso8601String()
      };
    },
    decode: (j) => ContributionPayment(
        id: j['id'] as String,
        campaignId: j['campaign_id'] as String,
        memberId: j['member_id'] as String,
        amount: _moneyOf(j, 'amount_minor', 'currency'),
        paidAt: _iso(j['paid_at']) ?? DateTime.now()),
  ),
  'family_chat_message': SyncAdapter(
    entity: 'family_chat_message',
    table: 'family_chat_message',
    spaceScoped: true,
    encode: (d, ctx) {
      final m = d as FamilyChatMessage;
      return {
        'id': m.id,
        'space_id': ctx.spaceId,
        'sender_id': m.senderId,
        'text': m.text,
        'created_at': m.createdAt.toUtc().toIso8601String(),
        'is_system': m.isSystem,
        'sender_name': m.senderName,
        'sender_avatar': m.senderAvatar,
        'status': m.status.name,
        'reference_type': m.referenceType?.name,
        'reference_id': m.referenceId,
        'reference_title': m.referenceTitle,
        'reference_meta': m.referenceMeta,
        'deleted': m.deleted,
      };
    },
    decode: (j) => FamilyChatMessage(
      id: j['id'] as String,
      familyId: j['space_id'] as String,
      senderId: j['sender_id'] as String,
      text: j['text'] as String? ?? '',
      createdAt: _iso(j['created_at']) ?? DateTime.now(),
      isSystem: (j['is_system'] as bool?) ?? false,
      senderName: j['sender_name'] as String?,
      senderAvatar: j['sender_avatar'] as String?,
      status: ChatMessageStatus.values.byName(j['status'] as String? ?? 'sent'),
      referenceType: j['reference_type'] == null
          ? null
          : ChatReferenceType.values
              .byName(j['reference_type'] as String? ?? 'expense'),
      referenceId: j['reference_id'] as String?,
      referenceTitle: j['reference_title'] as String?,
      referenceMeta: j['reference_meta'] as String?,
      deleted: (j['deleted'] as bool?) ?? false,
    ),
  ),
  'family_activity': SyncAdapter(
    entity: 'family_activity',
    table: 'activity_log',
    spaceScoped: true,
    // Activity rows are server-authored by audit triggers and never queued.
    encode: (d, ctx) => throw UnsupportedError('activity is read-only'),
    decode: (j) => FamilyActivity(
      id: j['id'] as String,
      actorId: j['actor_id'] as String,
      action: j['action'] as String,
      entity: j['entity'] as String,
      entityId: j['entity_id'] as String?,
      detail: ((j['detail'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), v)),
      at: _iso(j['at']) ?? DateTime.now(),
    ),
  ),
  'budget_cycle_plan': SyncAdapter(
    entity: 'budget_cycle_plan',
    table: 'budget_cycle_plan',
    spaceScoped: true,
    encode: (d, ctx) {
      final p = d as BudgetCyclePlan;
      String date(DateTime value) =>
          '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
      return {
        'id': p.id,
        'space_id': ctx.spaceId,
        'cycle_start': date(p.cycleStart),
        'income_mode': p.incomeMode == IncomePlanMode.knownMonthly
            ? 'known_monthly'
            : 'as_earned',
        'expected_income_minor': p.expectedIncome?.minor,
        'currency': (p.expectedIncome?.currency ?? Currency.usd).code,
        'allocations': p.allocations,
        'status': p.isClosed ? 'closed' : 'active',
        'closed_at': p.closedAt?.toUtc().toIso8601String(),
        'copied_from': p.copiedFrom == null ? null : date(p.copiedFrom!),
      };
    },
    decode: (j) => BudgetCyclePlan(
      id: j['id'] as String,
      cycleStart: DateTime.parse(j['cycle_start'] as String),
      incomeMode: j['income_mode'] == 'as_earned'
          ? IncomePlanMode.asEarned
          : IncomePlanMode.knownMonthly,
      expectedIncome: j['expected_income_minor'] == null
          ? null
          : _moneyOf(j, 'expected_income_minor', 'currency'),
      allocations: ((j['allocations'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      isClosed: j['status'] == 'closed',
      closedAt: _iso(j['closed_at']),
      copiedFrom: j['copied_from'] == null
          ? null
          : DateTime.parse(j['copied_from'] as String),
    ),
  ),
  'tx': SyncAdapter(
    entity: 'tx',
    table: 'transaction',
    spaceScoped: true,
    encode: (d, ctx) {
      final t = d as Tx;
      return {
        'id': t.id,
        'space_id': ctx.spaceId,
        'type': t.type.name,
        'amount_minor': t.amount.minor,
        'currency': t.amount.currency.code,
        'member_id': t.memberId,
        'method': _methodOut[t.method],
        'note': t.note,
        'occurred_at': t.when.toUtc().toIso8601String(),
        'created_by': t.memberId,
        'deleted_at': t.deletedAt?.toUtc().toIso8601String(),
        'receipt_uri': t.receiptUri,
        'recurring_rule_id': t.recurringRuleId,
      };
    },
    decode: (j) => Tx(
      id: j['id'] as String,
      envelopeId: j['envelope_id'] as String?,
      memberId: j['member_id'] as String,
      type: TxType.values.byName(j['type'] as String),
      amount: _moneyOf(j, 'amount_minor', 'currency'),
      method: _methodIn(j['method'] as String? ?? 'other'),
      note: j['note'] as String? ?? '',
      when: (_iso(j['occurred_at']) ?? DateTime.now()),
      deletedAt: _iso(j['deleted_at']),
      receiptUri: j['receipt_uri'] as String?,
      recurringRuleId: j['recurring_rule_id'] as String?,
    ),
  ),
  'envelope': SyncAdapter(
    entity: 'envelope',
    table: 'envelope',
    spaceScoped: true,
    encode: (d, ctx) {
      final e = d as Envelope;
      return {
        'id': e.id,
        'space_id': ctx.spaceId,
        'name': e.name,
        'icon': e.emoji,
        'limit_minor': e.limit.minor,
        'limit_currency': e.limit.currency.code,
        'period': 'monthly',
        'rollover': _rolloverOut(e.rollover),
        'sharing': e.isPersonal ? 'personal' : 'shared',
        'is_archived': e.isArchived,
      };
    },
    decode: (j) => Envelope(
      id: j['id'] as String,
      name: j['name'] as String,
      emoji: j['icon'] as String? ?? 'receipt',
      limit: Money(
        j['limit_minor'] as int,
        _currencyIn(j['limit_currency']),
      ),
      rollover: _rolloverIn(j['rollover'] as String? ?? 'reset'),
      isPersonal: (j['sharing'] as String? ?? 'shared') == 'personal',
      isArchived: j['is_archived'] as bool? ?? false,
    ),
  ),
  'goal': SyncAdapter(
    entity: 'goal',
    table: 'goal',
    spaceScoped: true,
    encode: (d, ctx) {
      final g = d as Goal;
      return {
        'id': g.id,
        'space_id': ctx.spaceId,
        'name': g.name,
        'icon': g.emoji,
        'target_minor': g.target.minor,
        'target_currency': g.target.currency.code,
        'owner_member_id': g.ownerMemberId,
        'is_kid_jar': g.isKidJar,
        'status': g.status,
      };
    },
    decode: (j) => Goal(
      id: j['id'] as String,
      name: j['name'] as String,
      emoji: j['icon'] as String? ?? 'goal',
      target: Money(
        j['target_minor'] as int,
        _currencyIn(j['target_currency']),
      ),
      ownerMemberId: j['owner_member_id'] as String?,
      isKidJar: (j['is_kid_jar'] as bool?) ?? false,
      status: j['status'] as String? ?? 'active',
      // auto-save rules are device-local for M3
    ),
  ),
  'goal_tx': SyncAdapter(
    entity: 'goal_tx',
    table: 'goal_tx',
    spaceScoped: false, // RLS scopes via goal join
    encode: (d, ctx) {
      final t = d as GoalTx;
      return {
        'id': ctx.newId(),
        'goal_id': t.goalId,
        'member_id': t.byMemberId,
        'amount_minor': t.amount.minor,
        'currency': t.amount.currency.code,
        'note': '',
        'at': t.at.toUtc().toIso8601String(),
      };
    },
    decode: (j) => GoalTx(
      id: j['id'] as String?,
      goalId: j['goal_id'] as String,
      byMemberId: j['member_id'] as String,
      amount: _moneyOf(j, 'amount_minor', 'currency'),
      at: _iso(j['at']) ?? DateTime.now(),
    ),
  ),
  'list_item': SyncAdapter(
    entity: 'list_item',
    table: 'list_item',
    spaceScoped: false, // RLS scopes via shopping_list join
    encode: (d, ctx) {
      final i = d as ListItem;
      return {
        'id': i.id,
        'list_id': ctx.defaultListId,
        'name': i.name,
        'qty': i.qty,
        'est_price_minor': i.est.minor,
        'currency': i.est.currency.code,
        'added_by': i.addedById,
        'state': i.state.name,
        'checked_out': i.checkedOut,
        'assigned_to': i.assignedToId,
        'actual_price_minor': i.actual?.minor,
        'actual_currency': i.actual?.currency.code,
        'purchased_by': i.purchasedById,
        'deleted_at': i.deletedAt?.toUtc().toIso8601String(),
      };
    },
    decode: (j) => ListItem(
      id: j['id'] as String,
      name: j['name'] as String,
      qty: j['qty'] as int? ?? 1,
      est: _moneyOf(j, 'est_price_minor', 'currency'),
      addedById: j['added_by'] as String? ?? 'unknown',
      state: ItemState.values.byName(j['state'] as String? ?? 'tobuy'),
      checkedOut: j['checked_out'] as bool? ?? false,
      assignedToId: j['assigned_to'] as String?,
      actual: j['actual_price_minor'] == null
          ? null
          : _moneyOf(j, 'actual_price_minor', 'actual_currency'),
      purchasedById: j['purchased_by'] as String?,
      deletedAt: _iso(j['deleted_at']),
    ),
  ),
  // Shopping-list HEADER - must sync so every device knows the list exists
  // (its id stamps item pushes; created by create_space server-side).
  'shopping_list': SyncAdapter(
    entity: 'shopping_list',
    table: 'shopping_list',
    spaceScoped: true,
    encode: (d, ctx) {
      final l = d as ShoppingListHeader;
      return {
        'id': l.id,
        'space_id': ctx.spaceId,
        'name': l.name,
        'status': l.status,
        'deleted_at': l.deletedAt?.toUtc().toIso8601String(),
      };
    },
    decode: (j) => ShoppingListHeader(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Shopping list',
      status: j['status'] as String? ?? 'active',
      deletedAt: _iso(j['deleted_at']),
    ),
  ),
  // kid_request covers BOTH kid money requests and teen proposals - the
  // server table is shared, `kind` picks the local shape.
  'kid_request': SyncAdapter(
    entity: 'kid_request',
    table: 'kid_request',
    spaceScoped: true,
    encode: (d, ctx) {
      if (d is KidRequest) {
        return {
          'id': d.id,
          'space_id': ctx.spaceId,
          'requester_id': d.kidId,
          'amount_minor': d.amount.minor,
          'currency': d.amount.currency.code,
          'reason': d.reason,
          'kind': 'money',
          'state': d.state.name,
        };
      }
      final p = d as Proposal;
      return {
        'id': p.id,
        'space_id': ctx.spaceId,
        'requester_id': p.teenId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.code,
        'reason': p.reason,
        'kind': 'expense_proposal',
        'envelope_id': p.envelopeId,
        'state': p.state.name,
      };
    },
    decode: (j) {
      if ((j['kind'] as String? ?? 'money') == 'money') {
        return KidRequest(
          id: j['id'] as String,
          kidId: j['requester_id'] as String,
          amount: _moneyOf(j, 'amount_minor', 'currency'),
          reason: j['reason'] as String? ?? '',
          state: RequestState.values.byName(j['state'] as String? ?? 'pending'),
        );
      }
      return Proposal(
        id: j['id'] as String,
        teenId: j['requester_id'] as String,
        amount: _moneyOf(j, 'amount_minor', 'currency'),
        envelopeId: j['envelope_id'] as String? ?? '',
        reason: j['reason'] as String? ?? '',
        state: RequestState.values.byName(j['state'] as String? ?? 'pending'),
      );
    },
  ),
  'earning': SyncAdapter(
    entity: 'earning',
    table: 'earning',
    spaceScoped: true,
    encode: (d, ctx) {
      final e = d as Earning;
      return {
        'id': e.id,
        'space_id': ctx.spaceId,
        'member_id': e.memberId,
        'note': e.note,
        'amount_minor': e.amount.minor,
        'currency': e.amount.currency.code,
        'occurred_at': e.when.toUtc().toIso8601String(),
      };
    },
    decode: (j) => Earning(
      id: j['id'] as String,
      memberId: j['member_id'] as String,
      note: j['note'] as String? ?? '',
      amount: _moneyOf(j, 'amount_minor', 'currency'),
      when: _iso(j['occurred_at']) ?? DateTime.now(),
    ),
  ),
  'recurring': SyncAdapter(
    entity: 'recurring',
    table: 'recurring_rule',
    spaceScoped: true,
    encode: (d, ctx) {
      final r = d as RecurringRule;
      String dateIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
      return {
        'id': r.id,
        'space_id': ctx.spaceId,
        'name': r.name,
        'emoji': r.emoji,
        'amount_minor': r.amount.minor,
        'currency': r.amount.currency.code,
        'envelope_id': (r.envelopeId?.isEmpty ?? true) ? null : r.envelopeId,
        'member_id': r.memberId.isEmpty ? null : r.memberId,
        'method': _methodOut[r.method],
        'frequency': r.frequency.name,
        'next_due': dateIso(r.nextDue),
        'active': r.active,
        'archived_at':
            r.isArchived ? DateTime.now().toUtc().toIso8601String() : null,
      };
    },
    decode: (j) => RecurringRule(
      id: j['id'] as String,
      name: j['name'] as String? ?? 'Recurring',
      emoji: j['emoji'] as String? ?? '',
      amount: _moneyOf(j, 'amount_minor', 'currency'),
      envelopeId: j['envelope_id'] as String? ?? '',
      memberId: j['member_id'] as String? ?? '',
      method: _methodIn(j['method'] as String? ?? 'cash'),
      frequency:
          Frequency.values.byName(j['frequency'] as String? ?? 'monthly'),
      nextDue: DateTime.parse(j['next_due'] as String),
      active: j['active'] as bool? ?? true,
      isArchived: j['archived_at'] != null,
    ),
  ),
  'chore': SyncAdapter(
    entity: 'chore',
    table: 'chore',
    spaceScoped: true,
    encode: (d, ctx) {
      final c = d as Chore;
      return {
        'id': c.id,
        'space_id': ctx.spaceId,
        'name': c.name,
        'star_value': c.stars.clamp(1, 10),
        'state': c.state.name,
        'assignee_member_id': c.assigneeMemberId,
        'is_archived': c.isArchived,
      };
    },
    decode: (j) => Chore(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      stars: j['star_value'] as int? ?? 1,
      state: ChoreState.values.byName(j['state'] as String? ?? 'todo'),
      assigneeMemberId: j['assignee_member_id'] as String?,
      isArchived: j['is_archived'] as bool? ?? false,
    ),
  ),
  'mukando': SyncAdapter(
    entity: 'mukando',
    table: 'mukando',
    spaceScoped: true,
    // One circle per family (spec v1): deterministic id so every device
    // upserts the same server row. Member names ride in round_order (text[]);
    // linking them to user_profile rows is post-8 work.
    encode: (d, ctx) {
      final c = d as SavingsCircle;
      return {
        'id': uuidFromSeed('mukando/${ctx.spaceId}'),
        'space_id': ctx.spaceId,
        'name': c.name,
        'contribution_minor': c.contribution.minor,
        'currency': c.contribution.currency.code,
        'frequency': 'monthly',
        'total_rounds': c.totalRounds,
        'current_round': c.currentRound,
        'round_order': c.order,
      };
    },
    decode: (j) {
      final names = [
        if (j['round_order'] is List)
          for (final m in j['round_order'] as List) m as String,
      ];
      return SavingsCircle(
        name: j['name'] as String? ?? 'Savings circle',
        contribution: _moneyOf(j, 'contribution_minor', 'currency'),
        totalRounds: j['total_rounds'] as int? ?? 1,
        currentRound: j['current_round'] as int? ?? 1,
        order: names.isEmpty ? <String>['Member'] : names,
      );
    },
  ),
};

/// Pull order: envelopes/goals before their children; the shopping-list
/// header before its items (joiners learn the list id first).
const kPullOrder = [
  'envelope', 'budget_cycle_plan', 'goal', 'shopping_list', 'tx', 'goal_tx',
  'list_item',
  'kid_request', 'earning',
  'recurring', 'chore', 'mukando',
  'family_activity', // immutable server-authored audit trail
  'family_chat_message', // family-scoped conversation thread
  'contribution_campaign', 'contribution_pledge', 'contribution_payment',
  'family_debt', 'debt_repayment',
  'tx_allocation',
];

/// ── Family identity (live) ─────────────────────────────────────────────────
/// Maps server [membership] + [user_profile] rows into the app's local member
/// list. The signed-in user's id IS their server identity (auth.users id), so
/// every pushed row references a real user_profile - no FK rejections.
List<Member> membersFromServer({
  required List<Map<String, Object?>> membershipRows,
  required List<Map<String, Object?>> profileRows,
  required String meId,
}) {
  String nameOf(Map<String, Object?>? p) {
    if (p == null) return '';
    final n = (p['name'] ?? '').toString();
    if (n.isNotEmpty && n != 'Member') return n;
    final e = (p['email'] ?? '').toString();
    if (e.contains('@')) return e.split('@').first;
    return n == 'Member' ? '' : n;
  }

  final profiles = {for (final p in profileRows) p['id'].toString(): p};
  Role roleOf(String raw) => switch (raw) {
        'owner' => Role.owner,
        'teen' => Role.teen,
        'kid' => Role.kid,
        'viewer' => Role.viewer,
        // `co_parent` is the existing database representation for an
        // additional Family Admin; no risky role migration is required.
        'co_parent' => Role.owner,
        _ => Role.adult,
      };

  final out = <Member>[];
  Member? me;
  for (final m in membershipRows) {
    final uid = m['user_id'].toString();
    final p = profiles[uid];
    final member = Member(
      id: uid,
      name: nameOf(p).isEmpty ? 'Member' : nameOf(p),
      emoji: 'person',
      role: roleOf((m['role'] ?? 'adult').toString()),
      serverRole: (m['role'] ?? 'adult').toString(),
      avatarUrl: (p?['avatar_url'] ?? '').toString().isEmpty
          ? null
          : (p?['avatar_url']).toString(),
    );
    if (uid == meId) {
      me = member;
    } else {
      out.add(member);
    }
  }
  // Me first, then the rest alphabetically - stable list for the UI.
  final meMember =
      me ?? Member(id: meId, name: 'Me', emoji: 'person', role: Role.owner);
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [meMember, ...out];
}
