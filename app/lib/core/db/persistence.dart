import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import '../sync/sync_mappers.dart';
import '../money/money.dart';
import '../state/app_state.dart';
import 'app_database.dart';

/// In-memory image of everything stored locally, produced by [Persistence.loadAll].
class DbSnapshot {
  final List<Account> accounts;
  final List<Envelope> envelopes;
  final List<Tx> txs;
  final List<Goal> goals;
  final List<GoalTx> goalTxs;
  final List<ListItem> items;
  final List<Chore> chores;
  final List<KidRequest> requests;
  final List<Proposal> proposals;
  final List<RecurringRule> recurring;
  final List<Earning> earnings;
  final SavingsCircle circle;
  final int stars;
  final String? locale;
  final String? displayCurrency;
  final int? monthStartDay;
  final bool onboardingDone;
  final bool? notifyEnabled;
  final String? notifyPrefs;
  final String? notifyQuiet;
  final String? requestResultsSeen;
  final bool? largeText;
  final int? themeMode;
  final bool? hideAmounts;
  final bool? autoHide;
  final String? customRate;
  final String? profileEdits;

  DbSnapshot({
    required this.accounts,
    required this.envelopes,
    required this.txs,
    required this.goals,
    required this.goalTxs,
    required this.items,
    required this.chores,
    required this.requests,
    required this.proposals,
    required this.recurring,
    required this.earnings,
    required this.circle,
    required this.stars,
    this.locale,
    this.displayCurrency,
    this.monthStartDay,
    required this.onboardingDone,
    this.notifyEnabled,
    this.notifyPrefs,
    this.notifyQuiet,
    this.requestResultsSeen,
    this.largeText,
    this.themeMode,
    this.hideAmounts,
    this.autoHide,
    this.customRate,
    this.profileEdits,
  });
}

/// Hand-written repository: maps domain objects to SQLite rows and back.
/// M3 replaces the scattered upserts with an ordered outbox queue; the table
/// shapes are designed to survive that change.
class Persistence {
  Persistence(this.db);

  final AppDatabase db;

  Database get _d => db.raw;

  // ── Presence & seeding ─────────────────────────────────────────────────

  Future<bool> hasData() async {
    final e = Sqflite.firstIntValue(
          await _d.rawQuery('SELECT COUNT(*) AS c FROM envelope'),
        ) ??
        0;
    final t = Sqflite.firstIntValue(
          await _d.rawQuery('SELECT COUNT(*) AS c FROM tx'),
        ) ??
        0;
    return e > 0 || t > 0;
  }

  /// Writes the current in-memory state to the local database
  /// into a fresh database. One transaction — all or nothing.
  Future<void> seedAll(AppState s) async {
    final batch = _d.batch();
    for (final a in s.accounts) {
      batch.insert(
        'account',
        _accountRow(a),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final e in s.envelopes) {
      batch.insert(
        'envelope',
        _envelopeRow(e),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final t in s.txs) {
      batch.insert('tx', _txRow(t),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final g in s.goals) {
      batch.insert(
        'goal',
        _goalRow(g),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final t in s.goalTxs) {
      batch.insert('goal_tx', _goalTxRow(t));
    }
    for (final i in s.items) {
      batch.insert(
        'list_item',
        _itemRow(i),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final c in s.chores) {
      batch.insert(
        'chore',
        _choreRow(c),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final r in s.requests) {
      batch.insert(
        'kid_request',
        _requestRow(r),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final p in s.proposals) {
      batch.insert(
        'proposal',
        _proposalRow(p),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final e in s.earnings) {
      batch.insert(
        'earning',
        _earningRow(e),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final r in s.recurring) {
      batch.insert(
        'recurring',
        _recurringRow(r),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.insert(
      'circle',
      _circleRow(s.circle),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'kv',
      {'k': 'stars', 'v': '${s.stars}'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'kv',
      {'k': 'locale', 'v': s.localeCode},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'kv',
      {'k': 'displayCurrency', 'v': s.displayCurrency.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  // ── Load ───────────────────────────────────────────────────────────────

  Future<DbSnapshot> loadAll() async {
    final accounts = (await _d.query('account')).map(_accountFrom).toList();
    final envelopes = (await _d.query('envelope')).map(_envelopeFrom).toList();
    final txs =
        (await _d.query('tx', orderBy: 'when_ms DESC')).map(_txFrom).toList();
    final goals = (await _d.query('goal')).map(_goalFrom).toList();
    final goalTxs = (await _d.query('goal_tx', orderBy: 'at_ms ASC'))
        .map(_goalTxFrom)
        .toList();
    final items = (await _d.query('list_item',
            where: 'deleted_at IS NULL', orderBy: 'rowid DESC'))
        .map(_itemFrom)
        .toList();
    final chores = (await _d.query('chore')).map(_choreFrom).toList();
    final requests = (await _d.query('kid_request')).map(_requestFrom).toList();
    final proposals = (await _d.query('proposal')).map(_proposalFrom).toList();
    final earnings = (await _d.query('earning', orderBy: 'when_ms DESC'))
        .map(_earningFrom)
        .toList();
    final recurring = (await _d.query('recurring', orderBy: 'next_due_ms ASC'))
        .map(_recurringFrom)
        .toList();

    final mRows = await _d.query('circle', limit: 1);
    final circle =
        mRows.isEmpty ? _fallbackSavingsCircle() : _circleFrom(mRows.first);

    final kv = {
      for (final r in await _d.query('kv')) r['k'] as String: r['v'] as String,
    };

    return DbSnapshot(
      accounts: accounts,
      envelopes: envelopes,
      txs: txs,
      goals: goals,
      goalTxs: goalTxs,
      items: items,
      chores: chores,
      requests: requests,
      proposals: proposals,
      recurring: recurring,
      earnings: earnings,
      circle: circle,
      stars: int.tryParse(kv['stars'] ?? '') ?? 0,
      locale: kv['locale'],
      displayCurrency: kv['displayCurrency'],
      monthStartDay: int.tryParse(kv['month_start_day'] ?? ''),
      onboardingDone: kv['onboarding_done'] == '1',
      notifyEnabled: kv['notify_enabled'] != '0',
      notifyPrefs: kv['notify_prefs'],
      notifyQuiet: kv['notify_quiet'],
      requestResultsSeen: kv['request_results_seen'],
      largeText: kv['large_text'] == '1',
      themeMode: int.tryParse(kv['theme_mode'] ?? ''),
      hideAmounts: kv['hide_amounts'] == '1',
      autoHide: kv['auto_hide'] == null ? null : kv['auto_hide'] == '1',
      customRate: kv['custom_rate'],
      profileEdits: kv['profile_edits'],
    );
  }

  // ── Upserts (called from AppState after every mutation) ────────────────

  Future<void> saveTx(Tx t) async =>
      _d.insert('tx', _txRow(t), conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveEnvelope(Envelope e) async =>
      _d.insert('envelope', _envelopeRow(e),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveGoalTx(GoalTx t, {String? serverId}) async =>
      _d.insert('goal_tx', _goalTxRow(t, serverId: serverId));

  Future<void> saveListItem(ListItem i) async =>
      _d.insert('list_item', _itemRow(i),
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// Tombstone write: the row keeps its deleted_at locally (the sync push
  /// carries the flag to every other device) but never loads again.
  Future<void> deleteListItem(ListItem i) async {
    await _d.insert('list_item', _itemRow(i),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveChore(Chore c) async => _d.insert('chore', _choreRow(c),
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveRequest(KidRequest r) async =>
      _d.insert('kid_request', _requestRow(r),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveProposal(Proposal p) async =>
      _d.insert('proposal', _proposalRow(p),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveEarning(Earning e) async =>
      _d.insert('earning', _earningRow(e),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveRecurring(RecurringRule r) async =>
      _d.insert('recurring', _recurringRow(r),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveSavingsCircle(SavingsCircle m) async =>
      _d.insert('circle', _circleRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveGoal(Goal g) async => _d.insert('goal', _goalRow(g),
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveKv(String k, String v) async =>
      _d.insert('kv', {'k': k, 'v': v},
          conflictAlgorithm: ConflictAlgorithm.replace);

  /// Server rows (already decode-ready JSON) upserted into local tables.
  /// goal_tx dedupes on server_id; everything else replaces by TEXT pk.
  Future<void> applyServerRows(
      String entity, List<Map<String, Object?>> rows) async {
    final adapter = kSyncAdapters[entity];
    if (adapter == null) return;
    final batch = _d.batch();
    for (final row in rows) {
      switch (entity) {
        case 'tx':
          batch.insert('tx', _txRow(adapter.decode(row) as Tx),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'envelope':
          batch.insert(
              'envelope', _envelopeRow(adapter.decode(row) as Envelope),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'goal':
          batch.insert('goal', _goalRow(adapter.decode(row) as Goal),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'goal_tx':
          final g = adapter.decode(row) as GoalTx;
          batch.insert(
            'goal_tx',
            _goalTxRow(g, serverId: row['id'] as String?),
            conflictAlgorithm: ConflictAlgorithm.ignore, // unique server_id
          );
        case 'list_item':
          final li = adapter.decode(row) as ListItem;
          if (li.deletedAt != null) {
            // Tombstone from another device — remove our local copy.
            batch.delete('list_item', where: 'id = ?', whereArgs: [li.id]);
          } else {
            batch.insert('list_item', _itemRow(li),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        case 'shopping_list':
          batch.insert('shopping_list',
              _listRow(adapter.decode(row) as ShoppingListHeader),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'kid_request':
          final d = adapter.decode(row);
          if (d is KidRequest) {
            batch.insert('kid_request', _requestRow(d),
                conflictAlgorithm: ConflictAlgorithm.replace);
          } else if (d is Proposal) {
            batch.insert('proposal', _proposalRow(d),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        case 'earning':
          batch.insert('earning', _earningRow(adapter.decode(row) as Earning),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'recurring':
          batch.insert(
              'recurring', _recurringRow(adapter.decode(row) as RecurringRule),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'chore':
          batch.insert('chore', _choreRow(adapter.decode(row) as Chore),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'mukando':
          batch.insert(
              'circle', _circleRow(adapter.decode(row) as SavingsCircle),
              conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Clears the synced entity set (used when adopting a family space, so the
  /// local-only rows never leak into the family's server data). Local-only data —
  /// accounts, chores, savings circles, kv — is kept.
  Future<void> wipeSynced() async {
    final batch = _d.batch();
    for (final t in [
      'tx',
      'envelope',
      'goal',
      'goal_tx',
      'shopping_list',
      'list_item',
      'kid_request',
      'proposal',
      'earning',
      'chore',
      'recurring',
      'circle',
    ]) {
      batch.delete(t);
    }
    await batch.commit(noResult: true);
  }

  // ── Row builders ───────────────────────────────────────────────────────

  Map<String, Object?> _accountRow(Account a) => {
        'id': a.id,
        'name': a.name,
        'emoji': a.emoji,
        'currency': a.balance.currency.name,
        'minor': a.balance.minor,
      };

  Map<String, Object?> _envelopeRow(Envelope e) => {
        'id': e.id,
        'name': e.name,
        'emoji': e.emoji,
        'limit_minor': e.limit.minor,
        'limit_currency': e.limit.currency.name,
        'rollover': e.rollover.name,
        'is_personal': e.isPersonal ? 1 : 0,
      };

  Map<String, Object?> _txRow(Tx t) => {
        'id': t.id,
        'envelope_id': t.envelopeId,
        'member_id': t.memberId,
        'type': t.type.name,
        'amount_minor': t.amount.minor,
        'currency': t.amount.currency.name,
        'method': t.method.name,
        'note': t.note,
        'when_ms': t.when.millisecondsSinceEpoch,
      };

  Map<String, Object?> _goalRow(Goal g) => {
        'id': g.id,
        'name': g.name,
        'emoji': g.emoji,
        'target_minor': g.target.minor,
        'target_currency': g.target.currency.name,
        'auto_save': g.autoSave,
        'is_kid_jar': g.isKidJar ? 1 : 0,
        'owner_member_id': g.ownerMemberId,
      };

  Map<String, Object?> _goalTxRow(GoalTx t, {String? serverId}) => {
        if (serverId != null) 'server_id': serverId,
        'goal_id': t.goalId,
        'member_id': t.byMemberId,
        'amount_minor': t.amount.minor,
        'currency': t.amount.currency.name,
        'at_ms': t.at.millisecondsSinceEpoch,
      };

  Map<String, Object?> _itemRow(ListItem i) => {
        'id': i.id,
        'list_id': null,
        'name': i.name,
        'qty': i.qty,
        'est_minor': i.est.minor,
        'currency': i.est.currency.name,
        'state': i.state.name,
        'added_by': i.addedById,
        'checked_out': i.checkedOut ? 1 : 0,
        'deleted_at': i.deletedAt?.toIso8601String(),
      };

  Map<String, Object?> _listRow(ShoppingListHeader l) => {
        'id': l.id,
        'name': l.name,
        'status': l.status,
        'deleted_at': l.deletedAt?.toIso8601String(),
      };

  Map<String, Object?> _choreRow(Chore c) => {
        'id': c.id,
        'name': c.name,
        'stars': c.stars,
        'state': c.state.name,
      };

  Map<String, Object?> _requestRow(KidRequest r) => {
        'id': r.id,
        'kid_id': r.kidId,
        'amount_minor': r.amount.minor,
        'currency': r.amount.currency.name,
        'reason': r.reason,
        'state': r.state.name,
      };

  Map<String, Object?> _proposalRow(Proposal p) => {
        'id': p.id,
        'teen_id': p.teenId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.name,
        'envelope_id': p.envelopeId,
        'reason': p.reason,
        'state': p.state.name,
      };

  Map<String, Object?> _earningRow(Earning e) => {
        'id': e.id,
        'member_id': e.memberId,
        'note': e.note,
        'amount_minor': e.amount.minor,
        'currency': e.amount.currency.name,
        'when_ms': e.when.millisecondsSinceEpoch,
      };

  Map<String, Object?> _recurringRow(RecurringRule r) => {
        'id': r.id,
        'name': r.name,
        'emoji': r.emoji,
        'amount_minor': r.amount.minor,
        'currency': r.amount.currency.name,
        'envelope_id': r.envelopeId,
        'member_id': r.memberId,
        'method': r.method.name,
        'frequency': r.frequency.name,
        'next_due_ms': r.nextDue.millisecondsSinceEpoch,
        'active': r.active ? 1 : 0,
      };

  RecurringRule _recurringFrom(Map<String, Object?> m) => RecurringRule(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String? ?? 'autorenew',
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        envelopeId: m['envelope_id'] as String?,
        memberId: m['member_id'] as String,
        method: Method.values.byName(m['method'] as String),
        frequency: Frequency.values.byName(m['frequency'] as String),
        nextDue: DateTime.fromMillisecondsSinceEpoch(m['next_due_ms'] as int),
        active: (m['active'] as int? ?? 1) == 1,
      );

  Map<String, Object?> _circleRow(SavingsCircle m) => {
        'id': 1,
        'name': m.name,
        'contribution_minor': m.contribution.minor,
        'currency': m.contribution.currency.name,
        'total_rounds': m.totalRounds,
        'current_round': m.currentRound,
        'order_json': jsonEncode(m.order),
      };

  // ── Parsers ────────────────────────────────────────────────────────────

  Account _accountFrom(Map<String, Object?> m) => Account(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        balance: Money(
          m['minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
      );

  Envelope _envelopeFrom(Map<String, Object?> m) => Envelope(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        limit: Money(
          m['limit_minor'] as int,
          Currency.values.byName(m['limit_currency'] as String),
        ),
        rollover: Rollover.values.byName(m['rollover'] as String),
        isPersonal: (m['is_personal'] as int) == 1,
      );

  Tx _txFrom(Map<String, Object?> m) => Tx(
        id: m['id'] as String,
        envelopeId: m['envelope_id'] as String?,
        memberId: m['member_id'] as String,
        type: TxType.values.byName(m['type'] as String),
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        method: Method.values.byName(m['method'] as String),
        note: m['note'] as String,
        when: DateTime.fromMillisecondsSinceEpoch(m['when_ms'] as int),
      );

  Goal _goalFrom(Map<String, Object?> m) => Goal(
        id: m['id'] as String,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
        target: Money(
          m['target_minor'] as int,
          Currency.values.byName(m['target_currency'] as String),
        ),
        autoSave: m['auto_save'] as String?,
        isKidJar: (m['is_kid_jar'] as int) == 1,
        ownerMemberId: m['owner_member_id'] as String?,
      );

  GoalTx _goalTxFrom(Map<String, Object?> m) => GoalTx(
        goalId: m['goal_id'] as String,
        byMemberId: m['member_id'] as String,
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        at: DateTime.fromMillisecondsSinceEpoch(m['at_ms'] as int),
      );

  ListItem _itemFrom(Map<String, Object?> m) => ListItem(
        id: m['id'] as String,
        name: m['name'] as String,
        qty: m['qty'] as int,
        est: Money(
          m['est_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        addedById: m['added_by'] as String,
        state: ItemState.values.byName(m['state'] as String),
        checkedOut: (m['checked_out'] as int? ?? 0) == 1,
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
      );

  Chore _choreFrom(Map<String, Object?> m) => Chore(
        id: m['id'] as String,
        name: m['name'] as String,
        stars: m['stars'] as int,
        state: ChoreState.values.byName(m['state'] as String),
      );

  KidRequest _requestFrom(Map<String, Object?> m) => KidRequest(
        id: m['id'] as String,
        kidId: m['kid_id'] as String,
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        reason: m['reason'] as String,
        state: RequestState.values.byName(m['state'] as String),
      );

  Proposal _proposalFrom(Map<String, Object?> m) => Proposal(
        id: m['id'] as String,
        teenId: m['teen_id'] as String,
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        envelopeId: m['envelope_id'] as String,
        reason: m['reason'] as String,
        state: RequestState.values.byName(m['state'] as String),
      );

  Earning _earningFrom(Map<String, Object?> m) => Earning(
        id: m['id'] as String,
        memberId: m['member_id'] as String,
        note: m['note'] as String,
        amount: Money(
          m['amount_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        when: DateTime.fromMillisecondsSinceEpoch(m['when_ms'] as int),
      );

  SavingsCircle _circleFrom(Map<String, Object?> m) => SavingsCircle(
        name: m['name'] as String,
        contribution: Money(
          m['contribution_minor'] as int,
          Currency.values.byName(m['currency'] as String),
        ),
        totalRounds: m['total_rounds'] as int,
        currentRound: m['current_round'] as int,
        order: (jsonDecode(m['order_json'] as String) as List).cast<String>(),
      );

  static SavingsCircle _fallbackSavingsCircle() => SavingsCircle(
        name: 'Family Round',
        contribution: Money.fromMajor(50, Currency.usd),
        totalRounds: 8,
        currentRound: 1,
        order: const ['Member 1'],
      );
}
