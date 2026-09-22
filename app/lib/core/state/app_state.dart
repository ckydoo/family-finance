import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_controller.dart';
import '../auth/pin_store.dart';
import '../config/app_env.dart';
import '../data/seed_data.dart';
import '../db/app_database.dart';
import '../db/persistence.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_mappers.dart';
import '../models/models.dart';
import '../notifications/reminders.dart';
import '../money/money.dart';
import '../utils/ids.dart';

/// Exposes [AppState] to the widget tree. Lightweight stand-in for Riverpod
/// (spec §9.1) — swap later without touching feature code.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required super.child})
      : super(notifier: notifier);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

enum Pace { onTrack, watch, over }

/// Single source of truth. M1: every mutation writes through to the local
/// SQLite database (fire-and-forget, errors never crash the app); on startup
/// the stored state replaces the in-memory seed. Pass `db: null` (or use no
/// database) and the app runs exactly as the pure in-memory demo — this is
/// what widget tests and offline-demo mode rely on.
class AppState extends ChangeNotifier {
  AppState({this.db, AppEnv? env, this.auth})
      : env = env ?? const AppEnv.fallback() {
    final b = seedData();
    space = b.space;
    members = b.members;
    accounts = b.accounts;
    envelopes = b.envelopes;
    txs = b.txs;
    goals = b.goals;
    goalTxs = b.goalTxs;
    items = b.items;
    chores = b.chores;
    requests = b.requests;
    proposals = b.proposals;
    earnings = b.earnings;
    circle = b.circle;
    recurring = b.recurring;
    txs.sort((a, b2) => b2.when.compareTo(a.when));
    _user = members.first;
    hydrating = db != null;
    if (db != null) {
      _store = Persistence(db!);
      _hydrationFuture = _hydrate();
    }
  }

  /// Null → pure in-memory demo/test mode. Non-null → persist + hydrate.
  final AppDatabase? db;

  /// Environment + session (M2). Demo mode: env.isLive == false, auth unused.
  final AppEnv env;
  final AuthController? auth;

  /// Hashed PINs (Kids Mode exit, kid profiles).
  late final PinStore pinStore = PinStore(kvGet: db?.kvGet, kvSet: db?.kvSet);

  /// Sync engine (M3) — attached by app.dart in live mode; null in demo/tests.
  SyncEngine? sync;
  Persistence? _store;
  Future<void>? _hydrationFuture;
  final List<Future<void>> _writes = <Future<void>>[];

  late final FamilySpace space;
  late final List<Member> members;
  late final List<Account> accounts;
  late final List<Envelope> envelopes;
  late List<Tx> txs;
  late final List<Goal> goals;
  late final List<GoalTx> goalTxs;
  late final List<ListItem> items;
  late final List<Chore> chores;
  late final List<KidRequest> requests;
  late final List<Proposal> proposals;
  late final List<Earning> earnings;
  late SavingsCircle circle;
  late final List<RecurringRule> recurring;

  Member _user =
      const Member(id: 'x', name: 'x', emoji: 'person', role: Role.adult);
  Currency displayCurrency = Currency.usd;

  /// Demo FX rate (USD → ZiG). In production: a daily central-bank snapshot,
  /// a server cron, with the user's parallel-rate profile (spec §5.1).
  double rate = 15.27;
  String get rateLabel => 'rate ${rate.toStringAsFixed(2)} · daily reference';

  int pendingOps = 0; // offline "changes waiting to sync" demo counter
  int stars = 24; // the kids' stars

  /// Demo localization (EN / SN / ND). Phase 2 migrates to flutter gen-l10n;
  /// see lib/core/l10n/app_strings.dart.
  String localeCode = 'en';

  /// Elder-friendly large text (spec J6) — scales the whole app.
  bool largeText = false;

  /// App theme: 0 = system, 1 = light, 2 = dark (G1).
  int themeMode = 0;

  /// G5: privacy mask — every hero balance shows dots instead of numbers.
  bool hideAmounts = false;

  /// Payday-aligned cycle start (spec A1/B5). 1 = calendar month.
  int monthStartDay = 1;

  /// M5 notifications (J2/J3) — device-local; config persisted in kv.
  bool notifyEnabled = true;
  Set<ReminderCategory> notifyAllowed = {
    for (final k in allCategoryKeys.split(',')) categoryFromKey(k)!,
  };
  int quietStart = 21;
  int quietEnd = 7;

  /// Set by the app shell to receive each new reminder plan (the bridge to
  /// the OS scheduler). Null in tests → plans are computed but never sent.
  void Function(List<Reminder> plan)? reminderHook;
  final List<Reminder> _reminderExtras = [];
  List<Reminder> _lastPlan = const [];
  Set<String> _seenRequestResults = {};

  /// True while the startup hydration runs (only with a database attached).
  bool autoHideAmounts =
      true; // privacy: hide balances on background (kv 'auto_hide')
  bool hydrating = false;
  bool refreshing = false; // soft refresh in flight (tree stays mounted)
  bool _loadedOnce = false;

  /// Interface pass 3: set when hydration fails; the app shows a retry pane
  /// instead of pretending everything is fine.
  String? lastError;

  /// First-run onboarding finished (persisted in kv).
  bool onboardingComplete = false;

  Member get user => _user;

  Member? member(String id) {
    for (final m in members) {
      if (m.id == id) return m;
    }
    return null;
  }

  Envelope? envelope(String? id) {
    if (id == null) return null;
    for (final e in envelopes) {
      if (e.id == id) return e;
    }
    return null;
  }

  Goal? goal(String id) {
    for (final g in goals) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// First kid jar (works for demo seeds *and* live-mode synced families).
  Goal? get kidJarGoal {
    for (final g in goals) {
      if (g.isKidJar) return g;
    }
    return null;
  }

  /// The signed-in teen's own savings goal (or null).
  Goal? get teenJarGoal {
    for (final g in goals) {
      if (!g.isKidJar && g.ownerMemberId == _user.id) return g;
    }
    return null;
  }

  // ── Sync getters for UI ────────────────────────────────────────────────
  bool get isLive => env.isLive;
  bool get hasSpace => sync?.spaceId != null;
  String? get spaceName => sync?.spaceName;
  String? get inviteCode => sync?.inviteCode;
  DateTime? get lastSyncAt => sync?.lastSyncAt;
  SyncStatus? get syncStatus => sync?.status;
  String? get syncLastError => sync?.lastError;

  // ── Persistence plumbing (M1) ─────────────────────────────────────────────

  /// Completes when the startup hydrate (load stored state, or seed a fresh
  /// database) has finished. Resolves immediately in demo mode.
  Future<void> ready() => _hydrationFuture ?? Future<void>.value();

  /// Pull-to-refresh / retry. After the first successful load this is SOFT:
  /// the tree stays mounted (no splash flicker mid-pull); only first load
  /// and error retry use the full-screen splash.
  Future<void> refresh() {
    if (_loadedOnce) {
      refreshing = true;
      notifyListeners();
      return _hydrate().whenComplete(() {
        refreshing = false;
        notifyListeners();
      });
    }
    hydrating = true;
    notifyListeners();
    _hydrationFuture = _hydrate();
    return _hydrationFuture!;
  }

  /// Completes when every write issued so far has reached the database.
  /// Used by tests to make fire-and-forget writes deterministic.
  Future<void> flushWrites() => Future.wait(List.of(_writes));

  void _fire(Future<void> op) {
    final f = op.then(
      (_) {},
      onError: (Object e, StackTrace st) {
        // Persistence must never crash the app — surfacing only.
        debugPrint('Mhuri persist warning: $e');
      },
    );
    _writes.add(f);
    f.whenComplete(() => _writes.remove(f));
  }

  void _persistTx(Tx t) {
    if (_store != null) _fire(_store!.saveTx(t));
  }

  void _persistEnvelope(Envelope e) {
    if (_store != null) _fire(_store!.saveEnvelope(e));
  }

  void _persistGoalTx(GoalTx t) {
    if (_store != null) _fire(_store!.saveGoalTx(t));
  }

  void _persistItem(ListItem i) {
    if (_store != null) _fire(_store!.saveListItem(i));
  }

  void _persistChore(Chore c) {
    if (_store != null) _fire(_store!.saveChore(c));
  }

  void _persistRequest(KidRequest r) {
    if (_store != null) _fire(_store!.saveRequest(r));
  }

  void _persistProposal(Proposal p) {
    if (_store != null) _fire(_store!.saveProposal(p));
  }

  void _persistEarning(Earning e) {
    if (_store != null) _fire(_store!.saveEarning(e));
  }

  void _persistSavingsCircle() {
    if (_store != null) _fire(_store!.saveSavingsCircle(circle));
  }

  void _persistKv(String k, String v) {
    if (_store != null) _fire(_store!.saveKv(k, v));
  }

  Future<void> _hydrate() async {
    final store = _store!;
    try {
      if (await store.hasData()) {
        final data = await store.loadAll();
        lastError = null;
        accounts
          ..clear()
          ..addAll(data.accounts);
        envelopes
          ..clear()
          ..addAll(data.envelopes);
        txs
          ..clear()
          ..addAll(data.txs);
        goals
          ..clear()
          ..addAll(data.goals);
        goalTxs
          ..clear()
          ..addAll(data.goalTxs);
        items
          ..clear()
          ..addAll(data.items);
        chores
          ..clear()
          ..addAll(data.chores);
        requests
          ..clear()
          ..addAll(data.requests);
        proposals
          ..clear()
          ..addAll(data.proposals);
        earnings
          ..clear()
          ..addAll(data.earnings);
        circle = data.circle;
        if (data.recurring.isNotEmpty) {
          recurring
            ..clear()
            ..addAll(data.recurring);
        }
        if (data.monthStartDay != null) monthStartDay = data.monthStartDay!;
        onboardingComplete = data.onboardingDone;
        notifyEnabled = data.notifyEnabled ?? true;
        if (data.notifyPrefs != null) {
          notifyAllowed = {
            for (final k in data.notifyPrefs!.split(','))
              if (categoryFromKey(k.trim()) != null) categoryFromKey(k.trim())!,
          };
        }
        if (data.notifyQuiet != null) {
          final parts = data.notifyQuiet!.split('-');
          if (parts.length == 2) {
            quietStart = int.tryParse(parts[0]) ?? 21;
            quietEnd = int.tryParse(parts[1]) ?? 7;
          }
        }
        _seenRequestResults = (data.requestResultsSeen ?? '')
            .split(',')
            .where((e) => e.isNotEmpty)
            .toSet();
        stars = data.stars;
        if (data.locale != null) localeCode = data.locale!;
        largeText = data.largeText ?? false;
        themeMode = data.themeMode ?? 0;
        hideAmounts = data.hideAmounts ?? false;
        if (data.autoHide != null) autoHideAmounts = data.autoHide!;
        _applyProfileEdits(data.profileEdits);
        if (data.customRate != null) {
          final r = double.tryParse(data.customRate!);
          if (r != null && r > 0) rate = r;
        }
        final dc = data.displayCurrency;
        if (dc != null) {
          for (final c in Currency.values) {
            if (c.name == dc) displayCurrency = c;
          }
        }
        notifyListeners();
      } else {
        await store.seedAll(this);
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('Mhuri hydrate warning: $e');
    } finally {
      hydrating = false;
      _loadedOnce = true;
      _resyncReminders();
      notifyListeners();
    }
  }

  // ── Recurring expenses (C7 — reviewed, never silent) ──────────────────

  /// Active rules due within 3 days (or overdue), soonest first. Home's
  /// smart card surfaces these for a parent to post or skip.
  List<RecurringRule> get dueRecurring {
    final soon = DateTime.now().add(const Duration(days: 3));
    final due = recurring
        .where((r) => r.active && !r.nextDue.isAfter(soon))
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    return due;
  }

  void _persistRecurring(RecurringRule r) {
    if (_store != null) _fire(_store!.saveRecurring(r));
  }

  void addRecurring({
    required String name,
    required String emoji,
    required Money amount,
    required String memberId,
    required Method method,
    required Frequency frequency,
    required DateTime nextDue,
    String? envelopeId,
  }) {
    final r = RecurringRule(
      id: _seq('rc'),
      name: name,
      emoji: emoji,
      amount: amount,
      envelopeId: envelopeId,
      memberId: memberId,
      method: method,
      frequency: frequency,
      nextDue: nextDue,
    );
    recurring.add(r);
    _persistRecurring(r);
    _queue('recurring', r);
    pendingOps++;
    _resyncReminders();
    notifyListeners();
  }

  /// The review step: posts the expense now and advances the schedule
  /// (catching up if the rule is several periods behind).
  void postRecurring(RecurringRule r) {
    addTx(
      type: TxType.expense,
      amount: r.amount,
      memberId: r.memberId,
      method: r.method,
      note: '${r.name} (recurring)',
      envelopeId: r.envelopeId,
    );
    r.nextDue = r.frequency.advanceFrom(r.nextDue);
    final now = DateTime.now();
    while (r.nextDue.isBefore(now)) {
      r.nextDue = r.frequency.advanceFrom(r.nextDue);
    }
    _persistRecurring(r);
    _queue('recurring', r);
    _resyncReminders();
    notifyListeners();
  }

  /// Skip this period without spending.
  void skipRecurring(RecurringRule r) {
    r.nextDue = r.frequency.advanceFrom(r.nextDue);
    while (r.nextDue.isBefore(DateTime.now())) {
      r.nextDue = r.frequency.advanceFrom(r.nextDue);
    }
    _persistRecurring(r);
    _queue('recurring', r);
    _resyncReminders();
    notifyListeners();
  }

  void toggleRecurring(RecurringRule r) {
    r.active = !r.active;
    _persistRecurring(r);
    _queue('recurring', r);
    _resyncReminders();
    notifyListeners();
  }

  // ── Onboarding, settings & export (M4) ────────────────────────────────

  void completeOnboarding() {
    onboardingComplete = true;
    _persistKv('onboarding_done', '1');
    _resyncReminders();
    notifyListeners();
  }

  /// Small local note storage (Family Meeting notes, etc.) — kv-backed,
  /// demo-safe, device-local.
  void saveLocalNote(String key, String value) {
    _persistKv(key, value);
    notifyListeners();
  }

  /// Payday-aligned cycles (B5) — e.g. 25 for salary-cycle budgeting.
  void setMonthStartDay(int day) {
    if (day < 1 || day > 28) return;
    monthStartDay = day;
    _persistKv('month_start_day', '$day');
    _resyncReminders();
    notifyListeners();
  }

  /// I6 — CSV export of every transaction. Returns the file path, or null
  /// on failure (no path_provider in tests, storage errors).
  Future<String?> exportCsv() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/mhuri_money_$stamp.csv');
      final b = StringBuffer(
          'date,type,amount,currency,method,member,envelope,note\n');
      String cell(String v) => '"${v.replaceAll('"', '""')}"';
      for (final t in txs) {
        final env = envelope(t.envelopeId)?.name ?? '';
        final mem = member(t.memberId)?.name ?? '';
        b.writeln([
          t.when.toIso8601String().substring(0, 10),
          t.type.name,
          (t.amount.minor / 100).toStringAsFixed(2),
          t.amount.currency.name,
          t.method.name,
          cell(mem),
          cell(env),
          cell(t.note),
        ].join(','));
      }
      await file.writeAsString(b.toString());
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ── Sync plumbing (M3) ─────────────────────────────────────────────────

  void attachSync(SyncEngine e) => sync = e;

  /// Engine reports a status change → repaint whatever shows sync state.
  /// ─── Notifications (M5 — spec J2/J3) ─────────────────────────────────

  NotifyConfig get _notifyConfig => NotifyConfig(
        enabled: notifyEnabled,
        allowed: notifyAllowed,
        quietStart: quietStart,
        quietEnd: quietEnd,
      );

  /// Current reminder plan (Home bell sheet + tests). Pure computation.
  List<Reminder> planReminders({DateTime? now}) {
    final n = now ?? DateTime.now();
    return ReminderPlanner.plan(
      now: n,
      config: _notifyConfig,
      recurring: recurring,
      envelopes: [
        for (final e in envelopes)
          EnvelopeHealth(
            envelope: e,
            limit: effectiveLimit(e),
            spent: spentOn(e),
            cycleStart: cycleStartFor(n),
          ),
      ],
      chores: chores,
      requests: requests,
      circle: circle,
      memberNames: {for (final m in members) m.id: m.name},
      monthStartDay: monthStartDay,
      extra: List.of(_reminderExtras),
    );
  }

  /// Push a new plan to the OS bridge — only when it actually changed
  /// (sync ticks call this often; dedupe keeps it free).
  void _resyncReminders() {
    _reminderExtras.removeWhere((r) => !r.when.isAfter(DateTime.now()));
    final plan = planReminders();
    if (listEquals(plan, _lastPlan)) return;
    _lastPlan = plan;
    reminderHook?.call(plan);
  }

  /// Goal milestone event (J2) — crossing 25/50/75/100% fires a nudge.
  void _maybeMilestone(Goal g, {required int before, required int after}) {
    if (g.target.minor <= 0) return;
    const bands = [0.25, 0.5, 0.75, 1.0];
    int level(int saved) {
      var lv = -1;
      for (var i = 0; i < bands.length; i++) {
        if (saved >= (bands[i] * g.target.minor).round()) lv = i;
      }
      return lv;
    }

    final bl = level(before);
    final al = level(after);
    if (al <= bl) return;
    _reminderExtras.add(Reminder(
      key: 'milestone_${g.id}_${(bands[al] * 100).round()}',
      category: ReminderCategory.goals,
      title: al == 3
          ? '${g.name} — goal reached! 🎉'
          : '${g.name} is ${(bands[al] * 100).round()}% full',
      body: 'Show the family — progress like this keeps everyone going.',
      when: DateTime.now().add(const Duration(minutes: 2)),
    ));
    _resyncReminders();
  }

  /// Kid-side: a synced request got its answer (J2's "kid gets a friendly
  /// result" — arrives locally when the parent's decision syncs over).
  void _checkRequestResults() {
    var newOnes = false;
    for (final r in requests) {
      if (r.state == RequestState.pending) continue;
      if (r.kidId != _user.id) continue;
      if (_seenRequestResults.contains(r.id)) continue;
      _seenRequestResults.add(r.id);
      newOnes = true;
      final approved = r.state == RequestState.approved;
      _reminderExtras.add(Reminder(
        key: 'kidresult_${r.id}',
        category: ReminderCategory.kids,
        title: approved
            ? '🎉 Your request was approved!'
            : 'Your request got an answer',
        body: approved
            ? '${r.amount.text} for ${r.reason} — check your jar.'
            : '${r.reason}: ask a parent about it — there is always a reason.',
        when: DateTime.now().add(const Duration(minutes: 1)),
      ));
    }
    if (newOnes) {
      _persistKv(
        'request_results_seen',
        _seenRequestResults.take(60).join(','),
      );
      _resyncReminders();
    }
  }

  void setRemindersEnabled(bool on) {
    notifyEnabled = on;
    _persistKv('notify_enabled', on ? '1' : '0');
    _resyncReminders();
    notifyListeners();
  }

  void setReminderPref(ReminderCategory c, bool on) {
    final next = Set.of(notifyAllowed);
    if (on) {
      next.add(c);
    } else {
      next.remove(c);
    }
    notifyAllowed = next;
    _persistKv('notify_prefs', next.map(categoryKey).join(','));
    _resyncReminders();
    notifyListeners();
  }

  void setQuietHours(int start, int end) {
    if (start < 0 || start > 23 || end < 0 || end > 23) return;
    quietStart = start;
    quietEnd = end;
    _persistKv('notify_quiet', '$start-$end');
    _resyncReminders();
    notifyListeners();
  }

  void syncStatusChanged() {
    _resyncReminders();
    notifyListeners();
  }

  Future<void> refreshPending() async {
    final e = sync;
    if (e == null) return;
    final n = await e.pendingCount();
    if (pendingOps != n) {
      pendingOps = n;
      notifyListeners();
    }
  }

  /// Live-mode mutations land in the outbox via the engine (fire-and-forget;
  /// enqueue never throws into the caller's flow).
  void _queue(String entity, Object domain) {
    final e = sync;
    if (e == null || !env.isLive) return;
    e.enqueue(entity, domain).then((_) => refreshPending());
  }

  /// Engine wiped local synced tables after adopting a family space — the
  /// in-memory image follows so the UI is honest until the first pull lands.
  void onSpaceAdopted() {
    txs.clear();
    envelopes.clear();
    goals.clear();
    goalTxs.clear();
    items.clear();
    requests.clear();
    proposals.clear();
    earnings.clear();
    chores.clear();
    recurring.clear();
    // Neutral placeholder until the family's mukando row arrives in the
    // first pull (collecting before that would push this neutral header).
    circle = SavingsCircle(
      name: 'Savings circle',
      contribution: Money(100, Currency.usd),
      totalRounds: 1,
      currentRound: 1,
      order: const ['You'],
    );
    pendingOps = 0;
    notifyListeners();
  }

  Future<void> clearLocalAccountData() async {
    final database = db;
    if (database != null) {
      await Persistence(database).wipeSynced();
      await database.raw.delete('account');
      await database.raw.delete('outbox');
      await database.raw.delete('kv');
    }
    accounts.clear();
    onSpaceAdopted();
  }

  /// Server-pulled rows (raw JSON) → in-memory merge. Persistence already
  /// stored them; this updates what the screens render.
  void applyPulled(String entity, List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return;
    final adapter = kSyncAdapters[entity];
    if (adapter == null) return;
    var changed = false;
    switch (entity) {
      case 'tx':
        for (final row in rows) {
          final t = adapter.decode(row) as Tx;
          txs.removeWhere((x) => x.id == t.id);
          txs.insert(0, t);
          changed = true;
        }
        txs.sort((a, b) => b.when.compareTo(a.when));
      case 'envelope':
        for (final row in rows) {
          final e2 = adapter.decode(row) as Envelope;
          envelopes.removeWhere((x) => x.id == e2.id);
          envelopes.add(e2);
          changed = true;
        }
      case 'goal':
        for (final row in rows) {
          final g = adapter.decode(row) as Goal;
          goals.removeWhere((x) => x.id == g.id);
          goals.add(g);
          changed = true;
        }
      case 'goal_tx':
        for (final row in rows) {
          final g = adapter.decode(row) as GoalTx;
          final exists = goalTxs.any(
            (x) =>
                x.goalId == g.goalId &&
                x.byMemberId == g.byMemberId &&
                x.amount.minor == g.amount.minor &&
                x.at.isAtSameMomentAs(g.at),
          );
          if (!exists) {
            goalTxs.add(g);
            changed = true;
          }
        }
      case 'list_item':
        for (final row in rows) {
          final i = adapter.decode(row) as ListItem;
          items.removeWhere((x) => x.id == i.id);
          items.insert(0, i);
          changed = true;
        }
      case 'kid_request':
        for (final row in rows) {
          final d = adapter.decode(row);
          if (d is KidRequest) {
            requests.removeWhere((x) => x.id == d.id);
            requests.add(d);
            changed = true;
          } else if (d is Proposal) {
            proposals.removeWhere((x) => x.id == d.id);
            proposals.add(d);
            changed = true;
          }
        }
      case 'earning':
        for (final row in rows) {
          final e2 = adapter.decode(row) as Earning;
          earnings.removeWhere((x) => x.id == e2.id);
          earnings.insert(0, e2);
          changed = true;
        }
      case 'recurring':
        for (final row in rows) {
          final r = adapter.decode(row) as RecurringRule;
          recurring.removeWhere((x) => x.id == r.id);
          recurring.add(r);
          changed = true;
        }
      case 'chore':
        for (final row in rows) {
          final c = adapter.decode(row) as Chore;
          chores.removeWhere((x) => x.id == c.id);
          chores.add(c);
          changed = true;
        }
      case 'mukando':
        circle = adapter.decode(rows.last) as SavingsCircle;
        changed = true;
    }
    if (entity == 'kid_request') _checkRequestResults();
    if (changed) {
      _resyncReminders();
      notifyListeners();
    }
  }

  // ── Display / session ─────────────────────────────────────────────────────

  /// Edit-profile overrides (name / avatar), kv-persisted as JSON and
  /// re-applied on every hydration.
  void _applyProfileEdits(String? json) {
    if (json == null || json.isEmpty) return;
    try {
      final map = (jsonDecode(json) as Map).cast<String, dynamic>();
      for (var i = 0; i < members.length; i++) {
        final e = map[members[i].id];
        if (e is Map) {
          members[i] = Member(
            id: members[i].id,
            role: members[i].role,
            name: (e['name'] as String?) ?? members[i].name,
            emoji: (e['emoji'] as String?) ?? members[i].emoji,
          );
        }
      }
    } catch (_) {
      // corrupt overrides are ignored — seed data stays intact
    }
  }

  /// Rename / re-avatar a member (Edit profile). Roles come from the family
  /// space and are not editable here.
  void updateMember(String id, {String? name, String? emoji}) {
    final i = members.indexWhere((m) => m.id == id);
    if (i < 0) return;
    final m = members[i];
    members[i] = Member(
      id: m.id,
      role: m.role,
      name: name == null || name.trim().isEmpty ? m.name : name.trim(),
      emoji: emoji ?? m.emoji,
    );
    _persistKv(
      'profile_edits',
      jsonEncode({
        for (final m2 in members) m2.id: {'name': m2.name, 'emoji': m2.emoji},
      }),
    );
    notifyListeners();
  }

  void switchUser(Member m) {
    _user = m;
    notifyListeners();
  }

  void toggleDisplayCurrency() {
    displayCurrency = displayCurrency.other;
    _persistKv('displayCurrency', displayCurrency.name);
    notifyListeners();
  }

  void setDisplayCurrency(Currency c) {
    displayCurrency = c;
    _persistKv('displayCurrency', c.name);
    notifyListeners();
  }

  /// Custom ZiG-per-USD rate from Settings → Currency & rates.
  void setCustomRate(double r) {
    rate = r.clamp(0.01, 1000000);
    _persistKv('custom_rate', rate.toStringAsFixed(4));
    notifyListeners();
  }

  void setAutoHideAmounts(bool on) {
    autoHideAmounts = on;
    _persistKv('auto_hide', on ? '1' : '0');
    notifyListeners();
  }

  Money disp(Money m) => m.inCurrency(displayCurrency, rate);

  void syncNow() {
    final e = sync;
    if (e != null && env.isLive) {
      e.syncNow();
      return;
    }
    pendingOps = 0;
    notifyListeners();
  }

  void setLargeText(bool on) {
    largeText = on;
    _persistKv('large_text', on ? '1' : '0');
    notifyListeners();
  }

  /// G1: follow the system, or force light/dark.
  void setThemeMode(int mode) {
    themeMode = mode.clamp(0, 2);
    _persistKv('theme_mode', themeMode.toString());
    notifyListeners();
  }

  /// G5: toggle the balance mask (eye on the pool card).
  void setHideAmounts(bool on) {
    hideAmounts = on;
    _persistKv('hide_amounts', on ? '1' : '0');
    notifyListeners();
  }

  void setLocale(String code) {
    localeCode = code;
    _persistKv('locale', code);
    notifyListeners();
  }

  // ── Pool & cycle math ─────────────────────────────────────────────────────

  /// Family Pool = sum of tagged account balances shown in [c] (spec §7.2).
  Money poolCombined(Currency c) {
    var sum = 0;
    for (final a in accounts) {
      sum += a.balance.inCurrency(c, rate).minor;
    }
    return Money(sum, c);
  }

  // ── Cycle math (M4: payday-aligned months + rollover carry) ──────────────

  /// Start of the cycle containing [now] (e.g. day 25 for salary cycles).
  DateTime cycleStartFor(DateTime now) => now.day >= monthStartDay
      ? DateTime(now.year, now.month, monthStartDay)
      : DateTime(now.year, now.month - 1, monthStartDay);

  DateTime nextCycleStartFor(DateTime now) {
    final cs = cycleStartFor(now);
    return DateTime(cs.year, cs.month + 1, monthStartDay);
  }

  DateTime get cycleStart => cycleStartFor(DateTime.now());
  DateTime get nextCycleStart => nextCycleStartFor(DateTime.now());

  int get daysLeftInCycle =>
      nextCycleStart.difference(DateTime.now()).inDays + 1;

  Money _spentInCycle(Envelope e, DateTime from, DateTime to) {
    var sum = 0;
    for (final t in txs) {
      if (t.type == TxType.expense &&
          t.envelopeId == e.id &&
          !t.when.isBefore(from) &&
          t.when.isBefore(to)) {
        sum += t.amount.inCurrency(e.limit.currency, rate).minor;
      }
    }
    return Money(sum, e.limit.currency);
  }

  Money get allocated {
    var sum = 0;
    for (final e in envelopes) {
      sum += e.limit.inCurrency(Currency.usd, rate).minor;
    }
    return Money(sum, Currency.usd);
  }

  Money get spentTotal {
    var sum = 0;
    for (final e in envelopes) {
      final s = spentOn(e).inCurrency(Currency.usd, rate).minor;
      if (s > 0) sum += s;
    }
    return Money(sum, Currency.usd);
  }

  Money get _remainingUsd {
    var sum = 0;
    for (final e in envelopes) {
      final left = e.limit.inCurrency(Currency.usd, rate).minor -
          spentOn(e).inCurrency(Currency.usd, rate).minor;
      if (left > 0) sum += left;
    }
    return Money(sum, Currency.usd);
  }

  /// "Safe to spend today" = flexible money left ÷ days left in cycle.
  Money get safeToSpend {
    final pool = poolCombined(Currency.usd).minor - _remainingUsd.minor;
    final v = (pool / daysLeftInCycle).floor();
    return Money(v < 0 ? 0 : v, Currency.usd);
  }

  // ── Envelopes ─────────────────────────────────────────────────────────────

  /// Spending on an envelope within the CURRENT cycle, in the envelope's
  /// own currency.
  Money spentOn(Envelope e) => _spentInCycle(e, cycleStart, nextCycleStart);

  Money remainingOn(Envelope e) =>
      Money(e.limit.minor - spentOn(e).minor, e.limit.currency);

  void addEnvelope({
    required String name,
    required Money limit,
    Rollover rollover = Rollover.reset,
    String emoji = 'money',
  }) {
    final envelope = Envelope(
      id: _seq('e'),
      name: name.trim(),
      emoji: emoji,
      limit: limit,
      rollover: rollover,
    );
    envelopes.add(envelope);
    _persistEnvelope(envelope);
    _queue('envelope', envelope);
    pendingOps++;
    notifyListeners();
  }

  /// Effective limit including rollover carry (spec D4).
  ///
  ///  * roll: one-cycle lookback — carry = unspent from the previous cycle.
  ///  * accumulate ("term savings"): unspent persists across the envelope's
  ///    whole history, approximated as base x cycles-since-first-use
  ///    (capped at 24 cycles). Documented simplification; revisit with a
  ///    proper allocation ledger in hardening.
  Money effectiveLimit(Envelope e) {
    if (e.rollover == Rollover.reset) return e.limit;
    final prevStart =
        DateTime(cycleStart.year, cycleStart.month - 1, cycleStart.day);
    final prevSpent = _spentInCycle(e, prevStart, cycleStart)
        .inCurrency(e.limit.currency, rate)
        .minor;
    final base = e.limit.minor;
    if (e.rollover == Rollover.roll) {
      final carry = base - prevSpent;
      return carry <= 0 ? e.limit : Money(base + carry, e.limit.currency);
    }
    DateTime? first;
    for (final t in txs) {
      if (t.envelopeId == e.id && (first == null || t.when.isBefore(first))) {
        first = t.when;
      }
    }
    var cycles = 1;
    if (first != null) {
      var cursor = cycleStartFor(first);
      while (cursor.isBefore(cycleStart) && cycles < 24) {
        cursor = DateTime(cursor.year, cursor.month + 1, monthStartDay);
        cycles++;
      }
    }
    final allSpent = _spentInCycle(e, DateTime(2000), nextCycleStart)
        .inCurrency(e.limit.currency, rate)
        .minor;
    final carry = base * cycles - allSpent;
    return carry <= 0 ? e.limit : Money(base + carry, e.limit.currency);
  }

  Pace paceOf(Envelope e) {
    final now = DateTime.now();
    final totalDays = nextCycleStart.difference(cycleStart).inDays;
    final elapsed = now.difference(cycleStart).inDays;
    final timeRatio = totalDays <= 0 ? 1.0 : elapsed / totalDays;
    final lim = effectiveLimit(e).minor;
    if (lim <= 0) return Pace.onTrack;
    final sp = spentOn(e).minor;
    if (sp > lim) return Pace.over;
    if (sp > timeRatio * 1.15 * lim) return Pace.watch;
    return Pace.onTrack;
  }

  /// D7 — move allocation between envelopes with a reason.
  void moveMoney(Envelope from, Envelope to, Money amount, String reason) {
    final amtTo = amount.inCurrency(to.limit.currency, rate);
    from.limit = Money(from.limit.minor - amount.minor, from.limit.currency);
    to.limit = Money(to.limit.minor + amtTo.minor, to.limit.currency);
    _persistEnvelope(from);
    _persistEnvelope(to);
    _queue('envelope', from);
    _queue('envelope', to);
    pendingOps++;
    notifyListeners();
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// Client row ids must be well-formed uuids — server id columns are
  /// uuid and a sequential 'tx0' would fail the cast on real Postgres.
  String _seq(String p) => newUuid();

  void addTx({
    required TxType type,
    required Money amount,
    required String memberId,
    required Method method,
    required String note,
    DateTime? when,
    String? envelopeId,
  }) {
    final t = Tx(
      id: _seq('t'),
      envelopeId: envelopeId,
      memberId: memberId,
      type: type,
      amount: amount,
      method: method,
      note: note,
      when: when ?? DateTime.now(),
    );
    txs.insert(0, t);
    _persistTx(t);
    _queue('tx', t);
    pendingOps++;
    _resyncReminders();
    notifyListeners();
  }

  // ── Shopping lists (Module F) ─────────────────────────────────────────────

  Money estFor(Currency c) {
    var sum = 0;
    for (final i in items) {
      if (i.state != ItemState.done) {
        sum += i.est.inCurrency(c, rate).minor * i.qty;
      }
    }
    return Money(sum, c);
  }

  void addItem(String name, int qty, Money est) {
    final i = ListItem(
      id: _seq('i'),
      name: name,
      qty: qty,
      est: est,
      addedById: _user.id,
    );
    items.insert(0, i);
    _persistItem(i);
    _queue('list_item', i);
    pendingOps++;
    notifyListeners();
  }

  void advanceItem(ListItem item) {
    item.state = item.state.next;
    _persistItem(item);
    _queue('list_item', item);
    pendingOps++;
    notifyListeners();
  }

  /// F5 — "Finish shopping" closes the loop: checked items become one expense
  /// pre-filled with the estimate, posted to the linked envelope.
  Money finishShopping() {
    var sum = 0;
    for (final i in items) {
      if (i.state == ItemState.done || i.state == ItemState.incart) {
        sum += i.est.inCurrency(Currency.usd, rate).minor * i.qty;
        i.state = ItemState.done;
        _persistItem(i);
        _queue('list_item', i);
      }
    }
    final total = Money(sum, Currency.usd);
    if (total.isZero) return total;

    // Prefer a Groceries envelope; fall back to the first shared one.
    Envelope? target;
    for (final e in envelopes) {
      if (!e.isPersonal && e.name.toLowerCase().contains('grocer')) {
        target = e;
        break;
      }
    }
    if (target == null) {
      for (final e in envelopes) {
        if (!e.isPersonal) {
          target = e;
          break;
        }
      }
    }

    addTx(
      type: TxType.expense,
      amount: total,
      memberId: _user.id,
      method: Method.bankCard,
      note: 'Groceries run — FreshMart',
      envelopeId: target?.id,
    );
    return total;
  }

  // ── Goals & savings circles (Module E) ────────────────────────────────────────────

  Money savedOn(Goal g) {
    var sum = 0;
    for (final t in goalTxs) {
      if (t.goalId == g.id) {
        sum += t.amount.inCurrency(g.target.currency, rate).minor;
      }
    }
    return Money(sum, g.target.currency);
  }

  void contribute(Goal g, Money amount) {
    final before = savedOn(g).minor;
    final t = GoalTx(
      goalId: g.id,
      byMemberId: _user.id,
      amount: amount,
      at: DateTime.now(),
    );
    goalTxs.add(t);
    _persistGoalTx(t);
    _queue('goal_tx', t);
    pendingOps++;
    _maybeMilestone(g, before: before, after: savedOn(g).minor);
    notifyListeners();
  }

  void circleCollect() {
    if (circle.currentRound < circle.totalRounds) {
      circle.currentRound++;
      _persistSavingsCircle();
      _queue('mukando', circle);
      _resyncReminders();
      pendingOps++;
      notifyListeners();
    }
  }

  /// Undo for [circleCollect] — rounds are overwrite-safe (records only).
  void undoCircleCollect() {
    if (circle.currentRound > 1) {
      circle.currentRound--;
      _persistSavingsCircle();
      _queue('mukando', circle);
      _resyncReminders();
      notifyListeners();
    }
  }

  // ── Kids Mode (Module G) ──────────────────────────────────────────────────

  void claimChore(Chore c) {
    c.state = ChoreState.waiting;
    _persistChore(c);
    _queue('chore', c);
    _resyncReminders();
    pendingOps++;
    notifyListeners();
  }

  void confirmChore(Chore c) {
    c.state = ChoreState.confirmed;
    stars += c.stars;
    _persistChore(c);
    _queue('chore', c);
    _persistKv('stars', '$stars');
    pendingOps++;
    _resyncReminders();
    notifyListeners();
  }

  /// Undo for [confirmChore] — safe because chores are overwrite-safe.
  void unconfirmChore(Chore c) {
    if (c.state == ChoreState.confirmed) {
      c.state = ChoreState.waiting;
      stars = (stars - c.stars).clamp(0, 1000000000);
      _persistChore(c);
      _queue('chore', c);
      _persistKv('stars', '$stars');
      _resyncReminders();
      notifyListeners();
    }
  }

  void requestMoney(Money amount, String reason) {
    final r = KidRequest(
      id: _seq('r'),
      kidId: _user.id,
      amount: amount,
      reason: reason,
    );
    requests.insert(0, r);
    _persistRequest(r);
    _queue('kid_request', r);
    pendingOps++;
    notifyListeners();
  }

  /// Approved money lands in the kid's jar (G5 → G2).
  void approveRequest(KidRequest r) {
    r.state = RequestState.approved;
    _persistRequest(r);
    _queue('kid_request', r);
    _resyncReminders();
    final jar = kidJarGoal;
    if (jar != null) {
      final t = GoalTx(
        goalId: jar.id,
        byMemberId: r.kidId,
        amount: r.amount,
        at: DateTime.now(),
      );
      goalTxs.add(t);
      _persistGoalTx(t);
      _queue('goal_tx', t);
    }
    pendingOps++;
    notifyListeners();
  }

  void declineRequest(KidRequest r) {
    r.state = RequestState.declined;
    _persistRequest(r);
    _queue('kid_request', r);
    _resyncReminders();
    pendingOps++;
    notifyListeners();
  }

  // ── Teen Zone (Module H) ──────────────────────────────────────────────────

  /// H4 — parents match 50% of what the teen saves into their jar.
  double get teenMatchRate => 0.5;

  Money get teenMatchTotal {
    final jar = teenJarGoal;
    if (jar == null) return const Money(0, Currency.usd);
    return Money(
      (savedOn(jar).minor * teenMatchRate).round(),
      jar.target.currency,
    );
  }

  List<Earning> get teenEarnings =>
      earnings.where((e) => e.memberId == _user.id).toList();

  Money get teenEarningsThisMonth {
    final now = DateTime.now();
    var sum = 0;
    for (final e in earnings) {
      if (e.memberId == _user.id &&
          e.when.year == now.year &&
          e.when.month == now.month) {
        sum += e.amount.inCurrency(Currency.usd, rate).minor;
      }
    }
    return Money(sum, Currency.usd);
  }

  void addEarning(Money amount, String note) {
    final e = Earning(
      id: _seq('e'),
      memberId: _user.id,
      note: note,
      amount: amount,
      when: DateTime.now(),
    );
    earnings.insert(0, e);
    _persistEarning(e);
    _queue('earning', e);
    pendingOps++;
    notifyListeners();
  }

  void proposeExpense(Money amount, String envelopeId, String reason) {
    final p = Proposal(
      id: _seq('p'),
      teenId: _user.id,
      amount: amount,
      envelopeId: envelopeId,
      reason: reason,
    );
    proposals.insert(0, p);
    _persistProposal(p);
    _queue('kid_request', p);
    pendingOps++;
    notifyListeners();
  }

  /// Approved teen proposal becomes a real expense on the family budget.
  void approveProposal(Proposal p) {
    p.state = RequestState.approved;
    _persistProposal(p);
    _queue('kid_request', p);
    addTx(
      type: TxType.expense,
      amount: p.amount,
      memberId: p.teenId,
      method: Method.cash,
      note: 'Approved: ${p.reason}',
      envelopeId: p.envelopeId,
    );
  }

  void declineProposal(Proposal p) {
    p.state = RequestState.declined;
    _persistProposal(p);
    _queue('kid_request', p);
    pendingOps++;
    notifyListeners();
  }

  // ── Reports (Module I1/I2 basics) ─────────────────────────────────────────

  List<Tx> _txsIn(DateTime now) => txs
      .where((t) => t.when.year == now.year && t.when.month == now.month)
      .toList();

  Money get monthIncome {
    final now = DateTime.now();
    var sum = 0;
    for (final t in _txsIn(now)) {
      if (t.type == TxType.income) {
        sum += t.amount.inCurrency(Currency.usd, rate).minor;
      }
    }
    return Money(sum, Currency.usd);
  }

  Money get monthSpend {
    final now = DateTime.now();
    var sum = 0;
    for (final t in _txsIn(now)) {
      if (t.type == TxType.expense) {
        sum += t.amount.inCurrency(Currency.usd, rate).minor;
      }
    }
    return Money(sum, Currency.usd);
  }

  Money get monthSaved {
    final now = DateTime.now();
    var sum = 0;
    for (final t in goalTxs) {
      if (t.at.year == now.year && t.at.month == now.month) {
        sum += t.amount.inCurrency(Currency.usd, rate).minor;
      }
    }
    return Money(sum, Currency.usd);
  }

  /// I1 — "envelope health": % of envelopes still on track (north-star).
  double get envelopeHealth {
    if (envelopes.isEmpty) return 1;
    final ok = envelopes.where((e) => paceOf(e) != Pace.over).length;
    return ok / envelopes.length;
  }

  /// "Cash leak" — share of expenses paid in untraceable cash (spec C5).
  double get cashLeakShare {
    var cash = 0;
    var all = 0;
    for (final t in _txsIn(DateTime.now())) {
      if (t.type == TxType.expense) {
        all += t.amount.inCurrency(Currency.usd, rate).minor;
        if (t.method == Method.cash) {
          cash += t.amount.inCurrency(Currency.usd, rate).minor;
        }
      }
    }
    return all == 0 ? 0 : cash / all;
  }

  /// Top envelopes by spending this month (for the report card).
  List<MapEntry<Envelope, Money>> get topEnvelopes {
    final rows = <MapEntry<Envelope, Money>>[
      for (final e in envelopes)
        if (!e.isPersonal) MapEntry(e, spentOn(e)),
    ]..sort((a, b) => b.value.minor.compareTo(a.value.minor));
    return rows.take(3).toList();
  }
}
