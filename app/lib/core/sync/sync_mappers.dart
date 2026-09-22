/// The synced entity set (M3 + premium pass). The family ledger — money,
/// budgets, lists, approvals, earnings — syncs, and as of the premium pass so
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
/// kind=money, Proposal for kind=expense_proposal) — the engine routes both.
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

Currency _currencyIn(Object? value) =>
    Currency.values.byName(value.toString().toLowerCase());

Money _moneyOf(Map<String, Object?> j, String minorKey, String currencyKey) =>
    Money(j[minorKey] as int, _currencyIn(j[currencyKey]));

DateTime? _iso(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();

// ── adapters ───────────────────────────────────────────────────────────────

final kSyncAdapters = <String, SyncAdapter>{
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
        'currency': t.amount.currency.short,
        'member_id': t.memberId,
        'method': _methodOut[t.method],
        'note': t.note,
        'occurred_at': t.when.toUtc().toIso8601String(),
        'created_by': t.memberId,
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
        'limit_currency': e.limit.currency.short,
        'period': 'monthly',
        'rollover': _rolloverOut(e.rollover),
        'sharing': e.isPersonal ? 'personal' : 'shared',
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
        'target_currency': g.target.currency.short,
        'owner_member_id': g.ownerMemberId,
        'is_kid_jar': g.isKidJar,
        'status': 'active',
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
        'currency': t.amount.currency.short,
        'note': '',
        'at': t.at.toUtc().toIso8601String(),
      };
    },
    decode: (j) => GoalTx(
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
        'currency': i.est.currency.short,
        'added_by': i.addedById,
        'state': i.state.name,
        'checked_out': i.checkedOut,
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
    ),
  ),
  // kid_request covers BOTH kid money requests and teen proposals — the
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
          'currency': d.amount.currency.short,
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
        'currency': p.amount.currency.short,
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
        'currency': e.amount.currency.short,
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
        'currency': r.amount.currency.short,
        'envelope_id': (r.envelopeId?.isEmpty ?? true) ? null : r.envelopeId,
        'member_id': r.memberId.isEmpty ? null : r.memberId,
        'method': _methodOut[r.method],
        'frequency': r.frequency.name,
        'next_due': dateIso(r.nextDue),
        'active': r.active,
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
      };
    },
    decode: (j) => Chore(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      stars: j['star_value'] as int? ?? 1,
      state: ChoreState.values.byName(j['state'] as String? ?? 'todo'),
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
        'currency': c.contribution.currency.short,
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

/// Pull order: envelopes/goals before their children.
const kPullOrder = [
  'envelope', 'goal', 'tx', 'goal_tx', 'list_item', 'kid_request', 'earning',
  'recurring', 'chore', 'mukando', // circle last — cheapest, header-only
];

/// ── Family identity (live) ─────────────────────────────────────────────────
/// Maps server [membership] + [user_profile] rows into the app's local member
/// list. The signed-in user's id IS their server identity (auth.users id), so
/// every pushed row references a real user_profile — no FK rejections.
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
        // 'adult' and 'co_parent' both map to the app's adult role.
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
  // Me first, then the rest alphabetically — stable list for the UI.
  final meMember =
      me ?? Member(id: meId, name: 'Me', emoji: 'person', role: Role.owner);
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [meMember, ...out];
}
