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
  final List<BudgetCyclePlan> budgetPlans;
  final List<FamilyActivity> familyActivities;
  final List<FamilyTask> familyTasks;
  final List<ContributionCampaign> contributionCampaigns;
  final List<ContributionPledge> contributionPledges;
  final List<ContributionPayment> contributionPayments;
  final List<FamilyDebt> familyDebts;
  final List<DebtRepayment> debtRepayments;
  final List<TxAllocation> txAllocations;
  final List<FamilyChatMessage> familyChatMessages;
  final List<Earning> earnings;
  final SavingsCircle circle;
  final int stars;
  final String? locale;
  final String? displayCurrency;
  final String? primaryCurrency;
  final String? secondaryCurrency;
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
    required this.budgetPlans,
    required this.familyActivities,
    required this.familyTasks,
    required this.contributionCampaigns,
    required this.contributionPledges,
    required this.contributionPayments,
    required this.familyDebts,
    required this.debtRepayments,
    required this.txAllocations,
    required this.familyChatMessages,
    required this.earnings,
    required this.circle,
    required this.stars,
    this.locale,
    this.displayCurrency,
    this.primaryCurrency,
    this.secondaryCurrency,
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
  /// into a fresh database. One transaction - all or nothing.
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
    for (final a in s.txAllocations) {
      batch.insert('tx_allocation', _allocationRow(a),
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
    for (final plan in s.budgetPlans) {
      batch.insert('budget_cycle_plan', _budgetPlanRow(plan),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final activity in s.familyActivities) {
      batch.insert('family_activity', _activityRow(activity),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final campaign in s.contributionCampaigns) {
      batch.insert('contribution_campaign', _campaignRow(campaign),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final pledge in s.contributionPledges) {
      batch.insert('contribution_pledge', _pledgeRow(pledge),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final payment in s.contributionPayments) {
      batch.insert('contribution_payment', _paymentRow(payment),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final debt in s.familyDebts) {
      batch.insert('family_debt', _debtRow(debt),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final repayment in s.debtRepayments) {
      batch.insert('debt_repayment', _repaymentRow(repayment),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final message in s.familyChatMessages) {
      batch.insert('family_chat_message', _chatMessageRow(message),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    for (final task in s.familyTasks) {
      batch.insert('family_task', _familyTaskRow(task),
          conflictAlgorithm: ConflictAlgorithm.replace);
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
    batch.insert(
      'kv',
      {'k': 'primary_currency', 'v': s.primaryCurrency.name},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    batch.insert(
      'kv',
      {'k': 'secondary_currency', 'v': s.secondaryCurrency?.name ?? 'none'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await batch.commit(noResult: true);
  }

  // ── Load ───────────────────────────────────────────────────────────────

  Future<DbSnapshot> loadAll() async {
    final accounts = (await _d.query('account')).map(_accountFrom).toList();
    final envelopes = (await _d.query('envelope', where: 'is_archived = 0'))
        .map(_envelopeFrom)
        .toList();
    final txs = (await _d.query('tx',
            where: 'deleted_at IS NULL', orderBy: 'when_ms DESC'))
        .map(_txFrom)
        .toList();
    final txAllocations =
        (await _d.query('tx_allocation')).map(_allocationFrom).toList();
    final goals = (await _d.query('goal', where: "status <> 'archived'"))
        .map(_goalFrom)
        .toList();
    final goalTxs = (await _d.query('goal_tx', orderBy: 'at_ms ASC'))
        .map(_goalTxFrom)
        .toList();
    final items = (await _d.query('list_item',
            where: 'deleted_at IS NULL', orderBy: 'rowid DESC'))
        .map(_itemFrom)
        .toList();
    final chores = (await _d.query('chore', where: 'is_archived = 0'))
        .map(_choreFrom)
        .toList();
    final requests = (await _d.query('kid_request')).map(_requestFrom).toList();
    final proposals = (await _d.query('proposal')).map(_proposalFrom).toList();
    final earnings = (await _d.query('earning', orderBy: 'when_ms DESC'))
        .map(_earningFrom)
        .toList();
    final recurring = (await _d.query('recurring',
            where: 'is_archived = 0', orderBy: 'next_due_ms ASC'))
        .map(_recurringFrom)
        .toList();
    final budgetPlans =
        (await _d.query('budget_cycle_plan', orderBy: 'cycle_start DESC'))
            .map(_budgetPlanFrom)
            .toList();
    final familyActivities =
        (await _d.query('family_activity', orderBy: 'at_ms DESC', limit: 500))
            .map(_activityFrom)
            .toList();
    final contributionCampaigns =
        (await _d.query('contribution_campaign')).map(_campaignFrom).toList();
    final contributionPledges =
        (await _d.query('contribution_pledge')).map(_pledgeFrom).toList();
    final contributionPayments =
        (await _d.query('contribution_payment', orderBy: 'paid_at_ms DESC'))
            .map(_paymentFrom)
            .toList();
    final familyDebts = (await _d.query('family_debt')).map(_debtFrom).toList();
    final debtRepayments =
        (await _d.query('debt_repayment', orderBy: 'paid_at_ms DESC'))
            .map(_repaymentFrom)
            .toList();
    final familyChatMessages = (await _d.query('family_chat_message',
            orderBy: 'created_at_ms DESC', limit: 500))
        .map(_chatMessageFrom)
        .toList();
    final familyTasks = (await _d.query('family_task',
            orderBy: 'due_at_ms ASC, created_at_ms DESC'))
        .map(_familyTaskFrom)
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
      txAllocations: txAllocations,
      goals: goals,
      goalTxs: goalTxs,
      items: items,
      chores: chores,
      requests: requests,
      proposals: proposals,
      recurring: recurring,
      budgetPlans: budgetPlans,
      familyActivities: familyActivities,
      familyTasks: familyTasks,
      contributionCampaigns: contributionCampaigns,
      contributionPledges: contributionPledges,
      contributionPayments: contributionPayments,
      familyDebts: familyDebts,
      debtRepayments: debtRepayments,
      familyChatMessages: familyChatMessages,
      earnings: earnings,
      circle: circle,
      stars: int.tryParse(kv['stars'] ?? '') ?? 0,
      locale: kv['locale'],
      displayCurrency: kv['displayCurrency'],
      primaryCurrency: kv['primary_currency'],
      secondaryCurrency: kv['secondary_currency'],
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

  Future<void> saveTxAllocation(TxAllocation a) async =>
      _d.insert('tx_allocation', _allocationRow(a),
          conflictAlgorithm: ConflictAlgorithm.replace);

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

  Future<void> saveBudgetPlan(BudgetCyclePlan plan) async =>
      _d.insert('budget_cycle_plan', _budgetPlanRow(plan),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveContributionCampaign(ContributionCampaign value) async =>
      _d.insert('contribution_campaign', _campaignRow(value),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveContributionPledge(ContributionPledge value) async =>
      _d.insert('contribution_pledge', _pledgeRow(value),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveContributionPayment(ContributionPayment value) async =>
      _d.insert('contribution_payment', _paymentRow(value),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveFamilyDebt(FamilyDebt value) async =>
      _d.insert('family_debt', _debtRow(value),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveDebtRepayment(DebtRepayment value) async =>
      _d.insert('debt_repayment', _repaymentRow(value),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveSavingsCircle(SavingsCircle m) async =>
      _d.insert('circle', _circleRow(m),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveGoal(Goal g) async => _d.insert('goal', _goalRow(g),
      conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveChatMessage(FamilyChatMessage message) async =>
      _d.insert('family_chat_message', _chatMessageRow(message),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> saveFamilyTask(FamilyTask task) async =>
      _d.insert('family_task', _familyTaskRow(task),
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
    final knownTxEnvelopes = <String, String?>{};
    if (entity == 'tx') {
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || row['deleted_at'] != null) continue;
        final existing = await _d.query(
          'tx',
          columns: ['envelope_id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        knownTxEnvelopes[id] =
            existing.isEmpty ? null : existing.first['envelope_id'] as String?;
      }
    }
    final batch = _d.batch();
    for (final row in rows) {
      switch (entity) {
        case 'tx':
          if (row['deleted_at'] != null) {
            batch.delete('tx', where: 'id = ?', whereArgs: [row['id']]);
          } else {
            final pulled = adapter.decode(row) as Tx;
            final envelopeId = pulled.envelopeId ?? knownTxEnvelopes[pulled.id];
            final merged = envelopeId == pulled.envelopeId
                ? pulled
                : Tx(
                    id: pulled.id,
                    envelopeId: envelopeId,
                    memberId: pulled.memberId,
                    type: pulled.type,
                    amount: pulled.amount,
                    method: pulled.method,
                    note: pulled.note,
                    when: pulled.when,
                    deletedAt: pulled.deletedAt,
                    receiptUri: pulled.receiptUri,
                    recurringRuleId: pulled.recurringRuleId,
                  );
            batch.insert('tx', _txRow(merged),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        case 'tx_allocation':
          batch.insert('tx_allocation',
              _allocationRow(adapter.decode(row) as TxAllocation),
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
            // Tombstone from another device - remove our local copy.
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
        case 'budget_cycle_plan':
          batch.insert('budget_cycle_plan',
              _budgetPlanRow(adapter.decode(row) as BudgetCyclePlan),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'family_activity':
          batch.insert('family_activity',
              _activityRow(adapter.decode(row) as FamilyActivity),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'contribution_campaign':
          batch.insert('contribution_campaign',
              _campaignRow(adapter.decode(row) as ContributionCampaign),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'contribution_pledge':
          batch.insert('contribution_pledge',
              _pledgeRow(adapter.decode(row) as ContributionPledge),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'contribution_payment':
          batch.insert('contribution_payment',
              _paymentRow(adapter.decode(row) as ContributionPayment),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'family_debt':
          batch.insert(
              'family_debt', _debtRow(adapter.decode(row) as FamilyDebt),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'debt_repayment':
          batch.insert('debt_repayment',
              _repaymentRow(adapter.decode(row) as DebtRepayment),
              conflictAlgorithm: ConflictAlgorithm.replace);
        case 'family_chat_message':
          batch.insert('family_chat_message',
              _chatMessageRow(adapter.decode(row) as FamilyChatMessage),
              conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }
    await batch.commit(noResult: true);
  }

  /// Clears the synced entity set (used when adopting a family space, so the
  /// local-only rows never leak into the family's server data). Local-only data -
  /// accounts, chores, savings circles, kv - is kept.
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
      'budget_cycle_plan',
      'family_activity',
      'contribution_campaign',
      'contribution_pledge',
      'contribution_payment',
      'family_debt',
      'debt_repayment',
      'tx_allocation',
      'family_chat_message',
      'family_task',
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
        'is_archived': e.isArchived ? 1 : 0,
      };

  Map<String, Object?> _budgetPlanRow(BudgetCyclePlan p) => {
        'id': p.id,
        'cycle_start': _dateOnly(p.cycleStart),
        'income_mode': p.incomeMode.name,
        'expected_income_minor': p.expectedIncome?.minor,
        'currency': (p.expectedIncome?.currency ?? Currency.usd).name,
        'allocations_json': jsonEncode(p.allocations),
        'is_closed': p.isClosed ? 1 : 0,
        'closed_at': p.closedAt?.toUtc().toIso8601String(),
        'copied_from': p.copiedFrom == null ? null : _dateOnly(p.copiedFrom!),
      };

  Map<String, Object?> _activityRow(FamilyActivity a) => {
        'id': a.id,
        'actor_id': a.actorId,
        'action': a.action,
        'entity': a.entity,
        'entity_id': a.entityId,
        'detail_json': jsonEncode(a.detail),
        'at_ms': a.at.millisecondsSinceEpoch,
      };

  Map<String, Object?> _campaignRow(ContributionCampaign c) => {
        'id': c.id,
        'name': c.name,
        'target_minor': c.target.minor,
        'currency': c.target.currency.name,
        'deadline_ms': c.deadline.millisecondsSinceEpoch,
        'created_by_id': c.createdById,
        'status': c.status,
      };

  Map<String, Object?> _pledgeRow(ContributionPledge p) => {
        'id': p.id,
        'campaign_id': p.campaignId,
        'member_id': p.memberId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.name,
        'created_at_ms': p.createdAt.millisecondsSinceEpoch,
      };

  Map<String, Object?> _paymentRow(ContributionPayment p) => {
        'id': p.id,
        'campaign_id': p.campaignId,
        'member_id': p.memberId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.name,
        'paid_at_ms': p.paidAt.millisecondsSinceEpoch,
      };

  Map<String, Object?> _debtRow(FamilyDebt d) => {
        'id': d.id,
        'name': d.name,
        'direction': d.direction.name,
        'principal_minor': d.principal.minor,
        'currency': d.principal.currency.name,
        'counterparty_member_id': d.counterpartyMemberId,
        'due_date_ms': d.dueDate?.millisecondsSinceEpoch,
        'status': d.status,
        'created_by_id': d.createdById,
      };

  Map<String, Object?> _repaymentRow(DebtRepayment p) => {
        'id': p.id,
        'debt_id': p.debtId,
        'member_id': p.memberId,
        'amount_minor': p.amount.minor,
        'currency': p.amount.currency.name,
        'paid_at_ms': p.paidAt.millisecondsSinceEpoch,
      };

  Map<String, Object?> _chatMessageRow(FamilyChatMessage m) => {
        'id': m.id,
        'family_id': m.familyId,
        'sender_id': m.senderId,
        'text': m.text,
        'created_at_ms': m.createdAt.millisecondsSinceEpoch,
        'is_system': m.isSystem ? 1 : 0,
        'sender_name': m.senderName,
        'sender_avatar': m.senderAvatar,
        'status': m.status.name,
        'reference_type': m.referenceType?.name,
        'reference_id': m.referenceId,
        'reference_title': m.referenceTitle,
        'reference_meta': m.referenceMeta,
        'media_url': m.mediaUrl,
        'media_type': m.mediaType,
        'sticker': m.sticker,
        'deleted': m.deleted ? 1 : 0,
      };

  Map<String, Object?> _familyTaskRow(FamilyTask t) => {
        'id': t.id,
        'title': t.title,
        'note': t.note,
        'assignee_member_id': t.assigneeMemberId,
        'created_by_member_id': t.createdByMemberId,
        'created_at_ms': t.createdAt.millisecondsSinceEpoch,
        'due_at_ms': t.dueDate?.millisecondsSinceEpoch,
        'status': t.status.name,
        'points': t.points,
        'requires_approval': t.requiresApproval ? 1 : 0,
        'approved_by_member_id': t.approvedByMemberId,
        'approved_at_ms': t.approvedAt?.millisecondsSinceEpoch,
        'completed_at_ms': t.completedAt?.millisecondsSinceEpoch,
        'is_archived': t.isArchived ? 1 : 0,
      };

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
        'deleted_at': t.deletedAt?.toIso8601String(),
        'receipt_uri': t.receiptUri,
        'recurring_rule_id': t.recurringRuleId,
      };

  Map<String, Object?> _allocationRow(TxAllocation a) => {
        'id': a.id,
        'tx_id': a.txId,
        'envelope_id': a.envelopeId,
        'amount_minor': a.amount.minor,
        'currency': a.amount.currency.name,
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
        'status': g.status,
      };

  Map<String, Object?> _goalTxRow(GoalTx t, {String? serverId}) => {
        if ((serverId ?? t.id) != null) 'server_id': serverId ?? t.id,
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
        'assigned_to_id': i.assignedToId,
        'actual_minor': i.actual?.minor,
        'actual_currency': i.actual?.currency.name,
        'purchased_by_id': i.purchasedById,
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
        'assignee_member_id': c.assigneeMemberId,
        'is_archived': c.isArchived ? 1 : 0,
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
        'is_archived': r.isArchived ? 1 : 0,
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
        isArchived: (m['is_archived'] as int? ?? 0) == 1,
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
        isArchived: (m['is_archived'] as int? ?? 0) == 1,
      );

  BudgetCyclePlan _budgetPlanFrom(Map<String, Object?> m) {
    final raw = jsonDecode(m['allocations_json'] as String) as Map;
    return BudgetCyclePlan(
      id: m['id'] as String,
      cycleStart: DateTime.parse(m['cycle_start'] as String),
      incomeMode: IncomePlanMode.values.byName(m['income_mode'] as String),
      expectedIncome: m['expected_income_minor'] == null
          ? null
          : Money(m['expected_income_minor'] as int,
              Currency.values.byName(m['currency'] as String)),
      allocations: raw.map((k, v) => MapEntry(k.toString(), v as int)),
      isClosed: (m['is_closed'] as int? ?? 0) == 1,
      closedAt: m['closed_at'] == null
          ? null
          : DateTime.parse(m['closed_at'] as String).toLocal(),
      copiedFrom: m['copied_from'] == null
          ? null
          : DateTime.parse(m['copied_from'] as String),
    );
  }

  FamilyActivity _activityFrom(Map<String, Object?> m) => FamilyActivity(
        id: m['id'] as String,
        actorId: m['actor_id'] as String,
        action: m['action'] as String,
        entity: m['entity'] as String,
        entityId: m['entity_id'] as String?,
        detail: (jsonDecode(m['detail_json'] as String) as Map)
            .map((k, v) => MapEntry(k.toString(), v)),
        at: DateTime.fromMillisecondsSinceEpoch(m['at_ms'] as int),
      );

  ContributionCampaign _campaignFrom(Map<String, Object?> m) =>
      ContributionCampaign(
        id: m['id'] as String,
        name: m['name'] as String,
        target: Money(m['target_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
        deadline: DateTime.fromMillisecondsSinceEpoch(m['deadline_ms'] as int),
        createdById: m['created_by_id'] as String,
        status: m['status'] as String,
      );

  ContributionPledge _pledgeFrom(Map<String, Object?> m) => ContributionPledge(
        id: m['id'] as String,
        campaignId: m['campaign_id'] as String,
        memberId: m['member_id'] as String,
        amount: Money(m['amount_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at_ms'] as int),
      );

  ContributionPayment _paymentFrom(Map<String, Object?> m) =>
      ContributionPayment(
        id: m['id'] as String,
        campaignId: m['campaign_id'] as String,
        memberId: m['member_id'] as String,
        amount: Money(m['amount_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
        paidAt: DateTime.fromMillisecondsSinceEpoch(m['paid_at_ms'] as int),
      );

  FamilyDebt _debtFrom(Map<String, Object?> m) => FamilyDebt(
        id: m['id'] as String,
        name: m['name'] as String,
        direction: DebtDirection.values.byName(m['direction'] as String),
        principal: Money(m['principal_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
        counterpartyMemberId: m['counterparty_member_id'] as String?,
        dueDate: m['due_date_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_date_ms'] as int),
        status: m['status'] as String,
        createdById: m['created_by_id'] as String,
      );

  DebtRepayment _repaymentFrom(Map<String, Object?> m) => DebtRepayment(
        id: m['id'] as String,
        debtId: m['debt_id'] as String,
        memberId: m['member_id'] as String,
        amount: Money(m['amount_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
        paidAt: DateTime.fromMillisecondsSinceEpoch(m['paid_at_ms'] as int),
      );

  FamilyChatMessage _chatMessageFrom(Map<String, Object?> m) =>
      FamilyChatMessage(
        id: m['id'] as String,
        familyId: m['family_id'] as String,
        senderId: m['sender_id'] as String,
        text: m['text'] as String,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at_ms'] as int),
        isSystem: (m['is_system'] as int? ?? 0) == 1,
        senderName: m['sender_name'] as String?,
        senderAvatar: m['sender_avatar'] as String?,
        status:
            ChatMessageStatus.values.byName(m['status'] as String? ?? 'sent'),
        referenceType: m['reference_type'] == null
            ? null
            : ChatReferenceType.values.byName(m['reference_type'] as String),
        referenceId: m['reference_id'] as String?,
        referenceTitle: m['reference_title'] as String?,
        referenceMeta: m['reference_meta'] as String?,
        mediaUrl: m['media_url'] as String?,
        mediaType: m['media_type'] as String?,
        sticker: m['sticker'] as String?,
        deleted: (m['deleted'] as int? ?? 0) == 1,
      );

  FamilyTask _familyTaskFrom(Map<String, Object?> m) => FamilyTask(
        id: m['id'] as String,
        title: m['title'] as String,
        note: m['note'] as String?,
        assigneeMemberId: m['assignee_member_id'] as String?,
        createdByMemberId: m['created_by_member_id'] as String?,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(m['created_at_ms'] as int),
        dueDate: m['due_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['due_at_ms'] as int),
        status:
            FamilyTaskStatus.values.byName(m['status'] as String? ?? 'open'),
        points: m['points'] as int? ?? 1,
        requiresApproval: (m['requires_approval'] as int? ?? 1) == 1,
        approvedByMemberId: m['approved_by_member_id'] as String?,
        approvedAt: m['approved_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['approved_at_ms'] as int),
        completedAt: m['completed_at_ms'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['completed_at_ms'] as int),
        isArchived: (m['is_archived'] as int? ?? 0) == 1,
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
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
        receiptUri: m['receipt_uri'] as String?,
        recurringRuleId: m['recurring_rule_id'] as String?,
      );

  TxAllocation _allocationFrom(Map<String, Object?> m) => TxAllocation(
        id: m['id'] as String,
        txId: m['tx_id'] as String,
        envelopeId: m['envelope_id'] as String,
        amount: Money(m['amount_minor'] as int,
            Currency.values.byName(m['currency'] as String)),
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
        status: m['status'] as String? ?? 'active',
      );

  GoalTx _goalTxFrom(Map<String, Object?> m) => GoalTx(
        id: m['server_id'] as String?,
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
        assignedToId: m['assigned_to_id'] as String?,
        actual: m['actual_minor'] == null
            ? null
            : Money(m['actual_minor'] as int,
                Currency.values.byName(m['actual_currency'] as String)),
        purchasedById: m['purchased_by_id'] as String?,
        deletedAt: m['deleted_at'] == null
            ? null
            : DateTime.parse(m['deleted_at'] as String),
      );

  Chore _choreFrom(Map<String, Object?> m) => Chore(
        id: m['id'] as String,
        name: m['name'] as String,
        stars: m['stars'] as int,
        state: ChoreState.values.byName(m['state'] as String),
        assigneeMemberId: m['assignee_member_id'] as String?,
        isArchived: (m['is_archived'] as int? ?? 0) == 1,
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
