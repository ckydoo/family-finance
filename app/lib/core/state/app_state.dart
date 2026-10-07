import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import '../auth/auth_controller.dart';
import '../auth/pin_store.dart';
import '../config/app_env.dart';
import '../db/app_database.dart';
import '../db/persistence.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_mappers.dart';
import '../models/models.dart';
import '../notifications/reminders.dart';
import '../money/money.dart';
import '../utils/ids.dart';

/// Exposes [AppState] to the widget tree. Lightweight stand-in for Riverpod
/// (spec §9.1) - swap later without touching feature code.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState notifier, required super.child})
      : super(notifier: notifier);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

enum Pace { onTrack, watch, over }

/// Single source of truth. M1: every mutation writes through to the local
/// SQLite database (fire-and-forget, errors never crash the app); on startup
/// the stored state replaces the in-memory defaults.
class AppState extends ChangeNotifier {
  AppState({this.db, AppEnv? env, this.auth, DateTime Function()? clock})
      : env = env ?? const AppEnv(),
        _clock = clock ?? DateTime.now {
    // Real-data boot (the only boot). Empty until the family is adopted
    // (FamilySetup → create/join → server pull fills everything).
    space = const FamilySpace(name: 'My family');
    members = [];
    accounts = [];
    envelopes = [];
    txs = [];
    txAllocations = [];
    goals = [];
    goalTxs = [];
    items = [];
    chores = [];
    requests = [];
    proposals = [];
    earnings = [];
    circle = _neutralCircle;
    recurring = [];
    budgetPlans = [];
    familyActivities = [];
    familyChatMessages = [];
    familyTasks = [];
    contributionCampaigns = [];
    contributionPledges = [];
    contributionPayments = [];
    familyDebts = [];
    debtRepayments = [];
    stars = 0;
    _user = _placeholderUser;
    hydrating = db != null;
    if (db != null) {
      _store = Persistence(db!);
      _hydrationFuture = _hydrate();
    }
  }

  /// Neutral mukando header until the family's real row arrives in a pull.
  static SavingsCircle get _neutralCircle => SavingsCircle(
        name: 'Savings circle',
        contribution: const Money(100, Currency.usd),
        totalRounds: 1,
        currentRound: 1,
        order: const ['You'],
      );

  static const Member _placeholderUser =
      Member(id: 'me', name: 'Me', emoji: 'person', role: Role.owner);

  /// Null → in-memory only (production always opens the local db; only
  /// exotic test setups pass null). Non-null → persist + hydrate.
  final AppDatabase? db;

  /// Server connection config + auth entry point (M2).
  final AppEnv env;
  final AuthController? auth;
  final DateTime Function() _clock;

  /// Hashed PINs (Kids Mode exit, kid profiles).
  late final PinStore pinStore = PinStore(kvGet: db?.kvGet, kvSet: db?.kvSet);

  /// Sync engine (M3) - attached by app.dart; null until then.
  SyncEngine? sync;
  Persistence? _store;
  Future<void>? _hydrationFuture;
  final List<Future<void>> _writes = <Future<void>>[];

  /// Device-local family identity. Adopted/renamed by FamilySetup and
  /// hydrated from kv (members_v1 / space_name) - never fixtures.
  late FamilySpace space;
  late final List<Member> members;
  late final List<Account> accounts;
  late final List<Envelope> envelopes;
  late List<Tx> txs;
  late final List<TxAllocation> txAllocations;
  late final List<Goal> goals;
  late final List<GoalTx> goalTxs;
  late final List<ListItem> items;
  late final List<Chore> chores;
  late final List<KidRequest> requests;
  late final List<Proposal> proposals;
  late final List<Earning> earnings;
  late SavingsCircle circle;
  late final List<RecurringRule> recurring;
  late final List<BudgetCyclePlan> budgetPlans;
  late final List<FamilyActivity> familyActivities;
  late final List<FamilyChatMessage> familyChatMessages;
  late final List<FamilyTask> familyTasks;
  late final List<ContributionCampaign> contributionCampaigns;
  late final List<ContributionPledge> contributionPledges;
  late final List<ContributionPayment> contributionPayments;
  late final List<FamilyDebt> familyDebts;
  late final List<DebtRepayment> debtRepayments;

  Member _user =
      const Member(id: 'x', name: 'x', emoji: 'person', role: Role.adult);
  Currency primaryCurrency = Currency.usd;
  Currency? secondaryCurrency = Currency.zwg;
  Currency displayCurrency = Currency.usd;

  List<Currency> get activeCurrencies => [
        primaryCurrency,
        if (secondaryCurrency != null && secondaryCurrency != primaryCurrency)
          secondaryCurrency!,
      ];

  Currency otherCurrency(Currency c) {
    final list = activeCurrencies;
    if (list.length <= 1) return c;
    return c == list.first ? list.last : list.first;
  }

  /// Default FX rate (primary currency → secondary currency).
  double rate = 15.27;
  String get rateLabel => secondaryCurrency == null
      ? primaryCurrency.code
      : '1 ${primaryCurrency.short} ≈ ${rate.toStringAsFixed(2)} ${secondaryCurrency!.short}';

  int pendingOps = 0; // offline "changes waiting to sync" counter
  int stars = 24; // the kids' stars

  /// Lightweight localization fallback (EN / SN / ND). Phase 2 migrates to flutter gen-l10n;
  /// see lib/core/l10n/app_strings.dart.
  String localeCode = 'en';

  /// Elder-friendly large text (spec J6) - scales the whole app.
  bool largeText = false;

  /// App theme: 0 = system, 1 = light, 2 = dark (G1).
  int themeMode = 0;

  /// G5: privacy mask - every hero balance shows dots instead of numbers.
  bool hideAmounts = false;

  /// Phase 2: Overspend policy - warn & confirm (default) vs strict block.
  OverspendPolicy overspendPolicy = OverspendPolicy.warn;

  final Set<String> _processedMutationIds = <String>{};

  /// Payday-aligned cycle start (spec A1/B5). 1 = calendar month.
  int monthStartDay = 1;

  /// M5 notifications (J2/J3) - device-local; config persisted in kv.
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
  // Opt-in privacy: balances remain visible unless the user enables it.
  bool autoHideAmounts = false;
  bool hydrating = false;
  bool refreshing = false; // soft refresh in flight (tree stays mounted)
  bool _loadedOnce = false;

  /// Interface pass 3: set when hydration fails; the app shows a retry pane
  /// instead of pretending everything is fine.
  String? lastError;

  /// First-run onboarding finished (persisted in kv).
  bool onboardingComplete = false;
  String onboardingStage = 'create';
  List<Map<String, String>> onboardingTemplates = const [];
  bool gettingStartedDismissed = false;

  /// Mukando (savings circle) is OPT-IN: the Home card and the Savings
  /// section only appear when the family chose to track rounds.
  bool mukandoEnabled = false;

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

  /// First kid jar (works for synced families).
  Goal? kidJarFor(String memberId) {
    for (final g in goals) {
      if (g.isKidJar && g.ownerMemberId == memberId) return g;
    }
    // Legacy/offline jars pre-date owner_member_id. Keep a single unassigned
    // jar usable, but never give one child's assigned jar to another child.
    for (final g in goals) {
      if (g.isKidJar && g.ownerMemberId == null) return g;
    }
    return null;
  }

  Goal? get kidJarGoal => kidJarFor(_user.id);

  /// The signed-in teen's own savings goal (or null).
  Goal? get teenJarGoal {
    for (final g in goals) {
      if (!g.isKidJar && g.ownerMemberId == _user.id) return g;
    }
    return null;
  }

  // ── Sync getters for UI ────────────────────────────────────────────────
  bool get isLive => env.isConfigured;
  bool get hasSpace => sync?.spaceId != null;
  String? get spaceName => sync?.spaceName;
  String? get inviteCode => sync?.inviteCode;
  DateTime? get lastSyncAt => sync?.lastSyncAt;
  SyncStatus? get syncStatus => sync?.status;
  String? get syncLastError => sync?.lastError;

  SyncHealthState get syncHealth {
    if (syncStatus == SyncStatus.syncing) {
      return SyncHealthState.syncing;
    }
    if (syncStatus == SyncStatus.needsSignIn ||
        syncStatus == SyncStatus.error ||
        (syncLastError != null && syncLastError!.isNotEmpty)) {
      return SyncHealthState.needsAttention;
    }
    if (pendingOps > 0 || syncStatus == SyncStatus.offline) {
      return SyncHealthState.saved;
    }
    if (lastSyncAt != null) {
      return SyncHealthState.synced;
    }
    return SyncHealthState.saved;
  }

  // ── Persistence plumbing (M1) ─────────────────────────────────────────────

  /// Completes when the startup hydrate (load stored state, or seed a fresh
  /// database) has finished.
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
        // Persistence must never crash the app - surfacing only.
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

  void _persistBudgetPlan(BudgetCyclePlan plan) {
    if (_store != null) _fire(_store!.saveBudgetPlan(plan));
  }

  void _persistGoalTx(GoalTx t) {
    if (_store != null) _fire(_store!.saveGoalTx(t, serverId: t.id));
  }

  void _persistGoal(Goal g) {
    if (_store != null) _fire(_store!.saveGoal(g));
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
      // GO-LIVE GUARD (one-time): devices upgraded from early builds carry
      // stale markers (onboarding_done, outbox, legacy kv) in their local
      // db. On the first boot we wipe leftover user data so the app starts
      // truly empty. Never fires once real adoption/session markers exist
      // (members_v1 / space_name / auth_user_id) - a real family is never
      // touched.
      if ((await db?.kvGet('live_purged_v1') ?? '') == '') {
        final v1 = await db?.kvGet('members_v1');
        final sn = await db?.kvGet('space_name');
        final sid = await db?.kvGet('space_id');
        final aid = await db?.kvGet('auth_user_id');
        final adopted = (v1 != null && v1.isNotEmpty) ||
            (sn != null && sn.isNotEmpty) ||
            (sid != null && sid.isNotEmpty) ||
            (aid != null && aid.isNotEmpty);
        if (!adopted) await db?.wipeUserData();
        await db?.kvSet('live_purged_v1', '1');
      }
      // Device-local family identity (live): owner member + space name.
      final rawMembers = await db?.kvGet('members_v1');
      if (rawMembers != null && rawMembers.isNotEmpty) {
        _loadMembersJson(rawMembers);
      }
      final savedName = await db?.kvGet('space_name');
      if (savedName != null && savedName.isNotEmpty) {
        space = FamilySpace(name: savedName);
      }
      final meId = await db?.kvGet('me_id');
      if (members.isNotEmpty) {
        _user = members.firstWhere(
          (m) => m.id == meId,
          orElse: () => members.first,
        );
      }
      final muk = await db?.kvGet('mukando_enabled');
      mukandoEnabled = muk == '1';
      // Onboarding state is valid even before a new family has envelopes or
      // transactions. Previously it was only read inside `hasData()`, so an
      // empty but successfully created family reopened the create screen.
      final onboardingMarker = await db?.kvGet('onboarding_done');
      final savedStage = await db?.kvGet('onboarding_stage');
      if (savedStage != null && savedStage.isNotEmpty) {
        onboardingStage = savedStage;
      }
      onboardingComplete = onboardingMarker == '1';
      final savedTemplates = await db?.kvGet('onboarding_templates');
      if (savedTemplates != null && savedTemplates.isNotEmpty) {
        try {
          final decoded = jsonDecode(savedTemplates);
          if (decoded is List) {
            onboardingTemplates = decoded
                .whereType<Map>()
                .map((item) => <String, String>{
                      for (final entry in item.entries)
                        entry.key.toString(): entry.value.toString(),
                    })
                .toList(growable: false);
          }
        } catch (_) {
          onboardingTemplates = const [];
        }
      }
      // Families created before staged onboarding do not have either marker.
      // A persisted family id is sufficient to identify those as established,
      // while new staged families always persist `onboarding_stage`.
      if (onboardingMarker == null &&
          (savedStage == null || savedStage.isEmpty)) {
        final existingSpaceId = await db?.kvGet('space_id');
        if (existingSpaceId != null && existingSpaceId.isNotEmpty) {
          onboardingComplete = true;
        }
      }
      final dismissedMarker = await db?.kvGet('dismissed_getting_started');
      gettingStartedDismissed = dismissedMarker == '1';
      final monthStartMarker = await db?.kvGet('month_start_day');
      if (monthStartMarker != null && monthStartMarker.isNotEmpty) {
        final parsed = int.tryParse(monthStartMarker);
        if (parsed != null && parsed >= 1 && parsed <= 28) {
          monthStartDay = parsed;
        }
      }
      final tm = await db?.kvGet('theme_mode');
      if (tm != null && tm.isNotEmpty) {
        final parsed = int.tryParse(tm);
        if (parsed != null) themeMode = parsed.clamp(0, 2);
      }
      final ha = await db?.kvGet('hide_amounts');
      if (ha != null && ha.isNotEmpty) {
        hideAmounts = ha == '1';
      }
      final ah = await db?.kvGet('auto_hide');
      if (ah != null && ah.isNotEmpty) {
        autoHideAmounts = ah == '1';
      }
      final pc = await db?.kvGet('primary_currency');
      if (pc != null && pc.isNotEmpty) {
        for (final c in Currency.values) {
          if (c.name == pc) primaryCurrency = c;
        }
      }
      final sc = await db?.kvGet('secondary_currency');
      if (sc != null) {
        if (sc.isEmpty || sc == 'none') {
          secondaryCurrency = null;
        } else {
          for (final c in Currency.values) {
            if (c.name == sc) secondaryCurrency = c;
          }
        }
      }
      final dc = await db?.kvGet('displayCurrency');
      if (dc != null && dc.isNotEmpty) {
        for (final c in Currency.values) {
          if (c.name == dc) displayCurrency = c;
        }
      }
      Money.primaryCurrency = primaryCurrency;
      Money.secondaryCurrency = secondaryCurrency;

      // FX precedence: user custom rate for active pair > benchmark default.
      if (secondaryCurrency != null) {
        final pairKey =
            'rate_${primaryCurrency.name}_${secondaryCurrency!.name}';
        final pairRate = await db?.kvGet(pairKey);
        if (pairRate != null && pairRate.isNotEmpty) {
          final v = double.tryParse(pairRate);
          if (v != null && v > 0) rate = v;
        } else {
          final custom = await db?.kvGet('custom_rate');
          final isZwgPair = primaryCurrency == Currency.zwg ||
              secondaryCurrency == Currency.zwg;
          final v = custom != null ? double.tryParse(custom) : null;
          if (v != null && v > 0 && (isZwgPair || v < 15)) {
            rate = v;
          } else {
            rate = primaryCurrency.defaultRateTo(secondaryCurrency!);
          }
        }
      }
      final ne = await db?.kvGet('notify_enabled');
      if (ne != null && ne.isNotEmpty) {
        notifyEnabled = ne != '0';
      }
      final lt = await db?.kvGet('large_text');
      if (lt != null && lt.isNotEmpty) {
        largeText = lt == '1';
      }
      final lc = await db?.kvGet('locale');
      if (lc != null && lc.isNotEmpty) {
        localeCode = lc;
      }
      final op = await db?.kvGet('overspend_policy');
      if (op != null && op.isNotEmpty) {
        for (final p in OverspendPolicy.values) {
          if (p.name == op) overspendPolicy = p;
        }
      }
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
        txAllocations
          ..clear()
          ..addAll(data.txAllocations);
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
        budgetPlans
          ..clear()
          ..addAll(data.budgetPlans);
        familyActivities
          ..clear()
          ..addAll(data.familyActivities);
        familyChatMessages
          ..clear()
          ..addAll(data.familyChatMessages);
        familyTasks
          ..clear()
          ..addAll(data.familyTasks);
        contributionCampaigns
          ..clear()
          ..addAll(data.contributionCampaigns);
        contributionPledges
          ..clear()
          ..addAll(data.contributionPledges);
        contributionPayments
          ..clear()
          ..addAll(data.contributionPayments);
        familyDebts
          ..clear()
          ..addAll(data.familyDebts);
        debtRepayments
          ..clear()
          ..addAll(data.debtRepayments);
        if (data.monthStartDay != null) monthStartDay = data.monthStartDay!;
        onboardingComplete = onboardingComplete || data.onboardingDone;
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
        final pc = data.primaryCurrency;
        if (pc != null) {
          for (final c in Currency.values) {
            if (c.name == pc) primaryCurrency = c;
          }
        }
        final sc = data.secondaryCurrency;
        if (sc != null) {
          if (sc.isEmpty || sc == 'none') {
            secondaryCurrency = null;
          } else {
            for (final c in Currency.values) {
              if (c.name == sc) secondaryCurrency = c;
            }
          }
        }
        final dc = data.displayCurrency;
        if (dc != null) {
          for (final c in Currency.values) {
            if (c.name == dc) displayCurrency = c;
          }
        }
        Money.primaryCurrency = primaryCurrency;
        Money.secondaryCurrency = secondaryCurrency;
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
      deduplicateEnvelopes();
      _resyncReminders();
      notifyListeners();
    }
  }

  // ── Recurring expenses (C7 - reviewed, never silent) ──────────────────

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

  Tx? lastPaymentFor(RecurringRule rule) {
    for (final tx in txs) {
      if (tx.recurringRuleId == rule.id && tx.type == TxType.expense) return tx;
    }
    return null;
  }

  bool recurringPaidThisCycle(RecurringRule rule) {
    final payment = lastPaymentFor(rule);
    return payment != null && !payment.when.isBefore(cycleStart);
  }

  List<RecurringRule> get sortedBills {
    final today = DateTime(now.year, now.month, now.day);
    int rank(RecurringRule rule) {
      if (!rule.active) return 4;
      final due =
          DateTime(rule.nextDue.year, rule.nextDue.month, rule.nextDue.day);
      if (due.isBefore(today)) return 0;
      if (!due.isAfter(today.add(const Duration(days: 3)))) return 1;
      if (recurringPaidThisCycle(rule)) return 3;
      return 2;
    }

    return [...recurring]..sort((a, b) {
        final byStatus = rank(a).compareTo(rank(b));
        return byStatus != 0 ? byStatus : a.nextDue.compareTo(b.nextDue);
      });
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
      recurringRuleId: r.id,
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

  bool updateRecurring(
    RecurringRule rule, {
    required String name,
    required Money amount,
    required Frequency frequency,
    required DateTime nextDue,
    String? envelopeId,
    required String memberId,
    required Method method,
  }) {
    if (!canEditBudgets || name.trim().isEmpty || amount.minor <= 0) {
      return false;
    }
    rule
      ..name = name.trim()
      ..amount = amount
      ..frequency = frequency
      ..nextDue = nextDue
      ..envelopeId = envelopeId
      ..memberId = memberId
      ..method = method;
    _persistRecurring(rule);
    _queue('recurring', rule);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool archiveRecurring(RecurringRule rule) {
    if (!canAdmin) return false;
    rule.isArchived = true;
    _persistRecurring(rule);
    _queue('recurring', rule);
    recurring.removeWhere((r) => r.id == rule.id);
    pendingOps++;
    notifyListeners();
    return true;
  }

  // ── Onboarding, settings & export (M4) ────────────────────────────────

  Future<void> completeOnboarding() async {
    onboardingComplete = true;
    onboardingStage = 'complete';
    if (db != null) {
      await db!.kvSet('onboarding_done', '1');
      await db!.kvSet('onboarding_stage', 'complete');
    }
    _resyncReminders();
    notifyListeners();
  }

  Future<void> applyFamilySetupSettings({
    required String stage,
    String? primary,
    String? secondary,
    int? monthStart,
    List<Map<String, String>>? templates,
  }) async {
    onboardingStage = stage;
    onboardingComplete = stage == 'complete';
    await db?.kvSet('onboarding_stage', stage);
    await db?.kvSet('onboarding_done', onboardingComplete ? '1' : '0');
    if (templates != null) {
      onboardingTemplates = templates
          .map((item) => Map<String, String>.from(item))
          .toList(growable: false);
      await db?.kvSet('onboarding_templates', jsonEncode(onboardingTemplates));
    }
    final primaryValue = Currency.values.where((c) => c.code == primary);
    if (primaryValue.isNotEmpty) setPrimaryCurrency(primaryValue.first);
    final secondaryValue = Currency.values.where((c) => c.code == secondary);
    setSecondaryCurrency(secondaryValue.isEmpty ? null : secondaryValue.first);
    if (monthStart != null) setMonthStartDay(monthStart);
    notifyListeners();
  }

  /// Whether the guided first-time home state should be active.
  /// Disappears once there is real financial activity (income/expense), or
  /// at least one configured budget limit, or user explicitly dismissed it.
  bool get isGuidedHomeActive {
    if (gettingStartedDismissed) return false;
    final nonPersonal = envelopes.where((e) => !e.isPersonal).toList();
    final hasPositiveLimit = nonPersonal.any((e) => e.limit.minor > 0);
    final hasRealTxs = txs.isNotEmpty;
    final hasRealGoals = goals.any((g) => !g.isKidJar && g.target.minor > 0);
    return !hasPositiveLimit && !hasRealTxs && !hasRealGoals;
  }

  void dismissGettingStarted() {
    gettingStartedDismissed = true;
    _persistKv('dismissed_getting_started', '1');
    notifyListeners();
  }

  /// Small local note storage (Family Meeting notes, etc.) - kv-backed,
  /// fire-and-forget, device-local.
  void saveLocalNote(String key, String value) {
    _persistKv(key, value);
    notifyListeners();
  }

  /// Payday-aligned cycles (B5) - e.g. 25 for salary-cycle budgeting.
  void setMonthStartDay(int day) {
    if (day < 1 || day > 28) return;
    monthStartDay = day;
    _persistKv('month_start_day', '$day');
    _resyncReminders();
    notifyListeners();
  }

  /// I6 - CSV export of every transaction. Returns the file path, or null
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
  /// ─── Notifications (M5 - spec J2/J3) ─────────────────────────────────

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
      circle: mukandoEnabled ? circle : null,
      memberNames: {for (final m in members) m.id: m.name},
      monthStartDay: monthStartDay,
      campaigns: contributionCampaigns,
      extra: List.of(_reminderExtras),
    );
  }

  /// Push a new plan to the OS bridge - only when it actually changed
  /// (sync ticks call this often; dedupe keeps it free).
  void _resyncReminders() {
    _reminderExtras.removeWhere((r) => !r.when.isAfter(DateTime.now()));
    final plan = planReminders();
    if (listEquals(plan, _lastPlan)) return;
    _lastPlan = plan;
    reminderHook?.call(plan);
  }

  /// Goal milestone event (J2) - crossing 25/50/75/100% fires a nudge.
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
          ? '${g.name} - goal reached! 🎉'
          : '${g.name} is ${(bands[al] * 100).round()}% full',
      body: 'Show the family - progress like this keeps everyone going.',
      when: DateTime.now().add(const Duration(minutes: 2)),
    ));
    _resyncReminders();
  }

  /// Kid-side: a synced request got its answer (J2's "kid gets a friendly
  /// result" - arrives locally when the parent's decision syncs over).
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
            ? '${r.amount.text} for ${r.reason} - check your jar.'
            : '${r.reason}: ask a parent about it - there is always a reason.',
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
    try {
      final n = await e.pendingCount();
      if (pendingOps != n) {
        pendingOps = n;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Live-mode mutations land in the outbox via the engine (fire-and-forget;
  /// enqueue never throws into the caller's flow).
  void _queue(String entity, Object domain) {
    final e = sync;
    if (e == null || !env.isConfigured) return;
    _fire(e.enqueue(entity, domain).then((_) => refreshPending()));
  }

  void addChatMessage(FamilyChatMessage message) {
    final clean = FamilyChatMessage(
      id: message.id,
      familyId: message.familyId,
      senderId: message.senderId,
      text: message.text.trim(),
      createdAt: message.createdAt,
      isSystem: message.isSystem,
      senderName: message.senderName,
      senderAvatar: message.senderAvatar,
      status: message.status,
      referenceType: message.referenceType,
      referenceId: message.referenceId,
      referenceTitle: message.referenceTitle,
      referenceMeta: message.referenceMeta,
      deleted: message.deleted,
    );
    final existingIndex =
        familyChatMessages.indexWhere((m) => m.id == clean.id);
    if (existingIndex >= 0) {
      familyChatMessages[existingIndex] = clean;
    } else {
      familyChatMessages.add(clean);
    }
    familyChatMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _store?.saveChatMessage(clean);
    notifyListeners();
  }

  void addFamilyTask(FamilyTask task) {
    final clean = FamilyTask(
      id: task.id,
      title: task.title.trim(),
      note: task.note?.trim(),
      assigneeMemberId: task.assigneeMemberId,
      createdByMemberId: task.createdByMemberId,
      createdAt: task.createdAt,
      dueDate: task.dueDate,
      status: task.status,
      points: task.points,
      isArchived: task.isArchived,
    );
    final existingIndex = familyTasks.indexWhere((t) => t.id == clean.id);
    if (existingIndex >= 0) {
      familyTasks[existingIndex] = clean;
    } else {
      familyTasks.add(clean);
    }
    familyTasks.sort((a, b) {
      final dueA = a.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dueB = b.dueDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return dueA.compareTo(dueB);
    });
    _store?.saveFamilyTask(clean);
    notifyListeners();
  }

  void updateFamilyTask(FamilyTask task) {
    final index = familyTasks.indexWhere((t) => t.id == task.id);
    final previous = index >= 0 ? familyTasks[index] : null;
    if (previous != null && previous.status != task.status) {
      if (previous.status != FamilyTaskStatus.done && task.status == FamilyTaskStatus.done) {
        stars += task.points;
        addChatMessage(FamilyChatMessage(
          id: newUuid(),
          familyId: sync?.spaceId ?? space.name,
          senderId: user.id,
          text: 'Completed: ${task.title} (+${task.points} pts)',
          createdAt: DateTime.now(),
          senderName: 'Family',
          senderAvatar: null,
          status: ChatMessageStatus.sent,
          isSystem: true,
          referenceType: ChatReferenceType.task,
          referenceId: task.id,
          referenceTitle: task.title,
          referenceMeta: '${task.points} pts earned',
        ));
      } else if (previous.status == FamilyTaskStatus.done && task.status != FamilyTaskStatus.done) {
        stars = (stars - previous.points).clamp(0, 1000000000);
        addChatMessage(FamilyChatMessage(
          id: newUuid(),
          familyId: sync?.spaceId ?? space.name,
          senderId: user.id,
          text: 'Reopened: ${task.title}',
          createdAt: DateTime.now(),
          senderName: 'Family',
          senderAvatar: null,
          status: ChatMessageStatus.sent,
          isSystem: true,
          referenceType: ChatReferenceType.task,
          referenceId: task.id,
          referenceTitle: task.title,
          referenceMeta: 'Task reopened',
        ));
      }
      _persistKv('stars', '$stars');
    }
    addFamilyTask(task);
  }

  void toggleFamilyTaskCompletion(FamilyTask task) {
    final nextStatus = task.status == FamilyTaskStatus.done
        ? FamilyTaskStatus.open
        : FamilyTaskStatus.done;
    updateFamilyTask(task.copyWith(status: nextStatus));
  }

  /// Engine wiped local synced tables after adopting a family space - the
  /// in-memory image follows so the UI is honest until the first pull lands.
  /// Called by the sync engine after create_space / join_space. Clears all
  /// synced data and bootstraps the REAL device-local
  /// family identity: one owner member derived from the signed-in email.
  void onSpaceAdopted({String? spaceName}) {
    txs.clear();
    txAllocations.clear();
    envelopes.clear();
    goals.clear();
    goalTxs.clear();
    items.clear();
    requests.clear();
    proposals.clear();
    earnings.clear();
    chores.clear();
    recurring.clear();
    budgetPlans.clear();
    familyActivities.clear();
    familyChatMessages.clear();
    familyTasks.clear();
    contributionCampaigns.clear();
    contributionPledges.clear();
    contributionPayments.clear();
    familyDebts.clear();
    debtRepayments.clear();
    // Neutral placeholder until the family's mukando row arrives in the
    // first pull (collecting before that would push this neutral header).
    circle = _neutralCircle;

    // Real identity: the signed-in user IS their server identity - the id
    // equals auth.users.id, which join/create_space already registered as a
    // user_profile row. Every pushed row therefore satisfies its FK.
    final email = auth?.session?.email ?? '';
    final serverId = auth?.session?.userId;
    final me = Member(
      id: (serverId == null || serverId.isEmpty) ? newUuid() : serverId,
      name: email.isEmpty ? 'Me' : email.split('@').first,
      emoji: 'person',
      role: Role.owner,
    );
    members
      ..clear()
      ..add(me);
    _user = me;
    if (spaceName != null && spaceName.trim().isNotEmpty) {
      space = FamilySpace(name: spaceName.trim());
      _persistKv('space_name', space.name);
    }
    _persistKv('members_v1', _membersJson());
    _persistKv('me_id', me.id);
    pendingOps = 0;
    notifyListeners();
  }

  String _membersJson() => jsonEncode([
        for (final m in members)
          {
            'id': m.id,
            'name': m.name,
            'emoji': m.emoji,
            'role': m.role.name,
            if (m.avatarUrl != null) 'avatar_url': m.avatarUrl,
          },
      ]);

  /// Live-only: updates the space name after the engine fetched it (join
  /// path). Persisted so restarts keep the real family name.
  void adoptSpaceName(String name) {
    if (name.trim().isEmpty) return;
    space = FamilySpace(name: name.trim());
    notifyListeners();
  }

  /// Sprint B: mirror server envelope_tx links into local transactions.
  /// Only rewrites rows whose link actually changed; each change is persisted
  /// locally (no re-queue - the server is the source for links).
  Future<void> applyEnvelopeLinks(Map<String, String> txToEnvelope) async {
    var changed = false;
    for (var i = 0; i < txs.length; i++) {
      final link = txToEnvelope[txs[i].id];
      if (link == null) continue;
      if ((txs[i].envelopeId ?? '') == link) continue;
      final t = txs[i];
      txs[i] = Tx(
        id: t.id,
        envelopeId: link,
        memberId: t.memberId,
        type: t.type,
        amount: t.amount,
        method: t.method,
        note: t.note,
        when: t.when,
        deletedAt: t.deletedAt,
        receiptUri: t.receiptUri,
        recurringRuleId: t.recurringRuleId,
      );
      await _store?.saveTx(txs[i]);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  /// Latest server FX snapshot - never overrides a user-set custom rate.
  Future<void> applyServerRate(double v) async {
    if (await db?.kvGet('custom_rate') case final cr? when cr.isNotEmpty) {
      return; // user override wins (spec §5.1 market profile)
    }
    if ((v - rate).abs() < 0.0001) return;
    rate = v;
    _persistKv('server_rate', v.toStringAsFixed(4));
    notifyListeners();
  }

  /// Mukando opt-in switch (Home card + Savings section + Settings).
  void setMukandoEnabled(bool v) {
    if (mukandoEnabled == v) return;
    mukandoEnabled = v;
    _persistKv('mukando_enabled', v ? '1' : '0');
    _resyncReminders();
    notifyListeners();
  }

  /// Updates MY profile picture (device-local immediately, server push via
  /// the sync engine). Empty url clears the photo.
  void setMyName(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final u = _user;
    _user = Member(
      id: u.id,
      name: clean,
      emoji: u.emoji,
      role: u.role,
      avatarUrl: u.avatarUrl,
    );
    for (var i = 0; i < members.length; i++) {
      if (members[i].id == u.id) {
        members[i] = _user;
        break;
      }
    }
    _persistKv('members_v1', _membersJson());
    sync?.updateMyProfile({'name': clean});
    notifyListeners();
  }

  void setMyAvatar(String url) {
    final u = _user;
    final clean = url.trim();
    _user = Member(
      id: u.id,
      name: u.name,
      emoji: u.emoji,
      role: u.role,
      avatarUrl: clean.isEmpty ? null : clean,
    );
    for (var i = 0; i < members.length; i++) {
      if (members[i].id == u.id) {
        members[i] = _user;
        break;
      }
    }
    _persistKv('members_v1', _membersJson());
    sync?.updateMyProfile({
      'avatar_url': clean.isEmpty ? null : clean,
    });
    notifyListeners();
  }

  /// Skip-for-now recovery: reopen the family-setup flow (Home banner).
  void reopenFamilySetup() {
    onboardingComplete = false;
    _persistKv('onboarding_done', '0');
    notifyListeners();
  }

  /// Server family roster (from the membership/user_profile pull) replaces
  /// the local list. Local profile edits (renames/avatars) always win; if the
  /// server still calls me 'Member', the local display name is kept.
  Future<void> setFamilyMembers(List<Member> incoming) async {
    if (incoming.isEmpty) return;
    String? editsRaw;
    try {
      editsRaw = await db?.kvGet('profile_edits');
    } catch (_) {}
    final meId = _user.id;
    final localMe = _user;
    final resolved = <Member>[];
    for (final m in incoming) {
      var name = m.name;
      var emoji = m.emoji;
      if (m.id == meId && (name == 'Member' || name.isEmpty)) {
        name = localMe.name;
        emoji = localMe.emoji;
      }
      resolved.add(Member(
        id: m.id,
        name: name,
        emoji: emoji,
        role: m.role,
        // A profile update can still be in flight when the roster is pulled.
        // Keep the locally persisted photo until the server returns one.
        avatarUrl: m.avatarUrl ?? (m.id == meId ? localMe.avatarUrl : null),
      ));
    }
    members
      ..clear()
      ..addAll(resolved);
    _applyProfileEdits(editsRaw);
    _user = members.firstWhere(
      (m) => m.id == meId,
      orElse: () => members.first,
    );
    _persistKv('members_v1', _membersJson());
    notifyListeners();
  }

  void _loadMembersJson(String raw) {
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      members
        ..clear()
        ..addAll([
          for (final j in list)
            Member(
              id: j['id'] as String,
              name: j['name'] as String? ?? 'Member',
              emoji: j['emoji'] as String? ?? 'person',
              role: Role.values.byName(j['role'] as String? ?? 'adult'),
              avatarUrl: j['avatar_url'] as String?,
            ),
        ]);
    } catch (_) {
      // Corrupt row → keep whatever we have; next adopt re-bootstraps.
    }
  }

  Future<void> clearLocalAccountData({String? deletedUserId}) async {
    final database = db;
    if (database != null) {
      final userId = deletedUserId ?? auth?.session?.userId;
      if (userId != null && userId.isNotEmpty) {
        await database.deleteAccountCache(userId);
      }
      await Persistence(database).wipeSynced();
      await database.raw.delete('account');
      await database.raw.delete('outbox');
      await database.raw.delete('kv');
    }
    accounts.clear();
    onSpaceAdopted();
  }

  /// Clears the in-memory image before a different authenticated account is
  /// allowed to render. The database/outbox boundary is cleared by
  /// [SyncEngine.ensureUserIsolation].
  void resetForAccount(String userId, {String? email}) {
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
    accounts.clear();
    circle = _neutralCircle;
    final member = Member(
      id: userId,
      name:
          (email == null || email.isEmpty) ? 'Member' : email.split('@').first,
      emoji: 'person',
      role: Role.adult,
    );
    members
      ..clear()
      ..add(member);
    _user = member;
    _realUserId = userId;
    _previewId = userId;
    space = const FamilySpace(name: 'Family');
    onboardingComplete = false;
    onboardingStage = 'create';
    onboardingTemplates = const [];
    pendingOps = 0;
    notifyListeners();
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
          if (row['deleted_at'] != null) {
            txs.removeWhere((x) => x.id == row['id']);
            changed = true;
            continue;
          }
          final t = adapter.decode(row) as Tx;
          txs.removeWhere((x) => x.id == t.id);
          txs.insert(0, t);
          changed = true;
        }
        txs.sort((a, b) => b.when.compareTo(a.when));
      case 'tx_allocation':
        for (final row in rows) {
          final value = adapter.decode(row) as TxAllocation;
          txAllocations.removeWhere((x) => x.id == value.id);
          txAllocations.add(value);
          changed = true;
        }
      case 'envelope':
        for (final row in rows) {
          final e2 = adapter.decode(row) as Envelope;
          envelopes.removeWhere((x) => x.id == e2.id);
          if (!e2.isArchived) envelopes.add(e2);
          changed = true;
        }
        deduplicateEnvelopes();
      case 'budget_cycle_plan':
        for (final row in rows) {
          final plan = adapter.decode(row) as BudgetCyclePlan;
          budgetPlans.removeWhere((x) => x.id == plan.id);
          budgetPlans.add(plan);
          changed = true;
        }
      case 'family_activity':
        for (final row in rows) {
          final activity = adapter.decode(row) as FamilyActivity;
          familyActivities.removeWhere((x) => x.id == activity.id);
          familyActivities.add(activity);
          changed = true;
        }
        familyActivities.sort((a, b) => b.at.compareTo(a.at));
      case 'contribution_campaign':
        for (final row in rows) {
          final value = adapter.decode(row) as ContributionCampaign;
          contributionCampaigns.removeWhere((x) => x.id == value.id);
          if (value.status == 'active') contributionCampaigns.add(value);
          changed = true;
        }
      case 'contribution_pledge':
        for (final row in rows) {
          final value = adapter.decode(row) as ContributionPledge;
          contributionPledges.removeWhere((x) => x.id == value.id);
          contributionPledges.add(value);
          changed = true;
        }
      case 'contribution_payment':
        for (final row in rows) {
          final value = adapter.decode(row) as ContributionPayment;
          final isNew = !contributionPayments.any((x) => x.id == value.id);
          contributionPayments.removeWhere((x) => x.id == value.id);
          contributionPayments.add(value);
          if (isNew &&
              value.memberId != realUser.id &&
              now.difference(value.paidAt).abs() < const Duration(days: 1)) {
            final campaign = contributionCampaigns
                .where((c) => c.id == value.campaignId)
                .firstOrNull;
            final contributor = member(value.memberId)?.name ?? 'A member';
            _reminderExtras.add(Reminder(
              key: 'contribution_received_${value.id}',
              category: ReminderCategory.contributions,
              title: '$contributor contributed ${value.amount.text}',
              body: campaign == null
                  ? 'A family contribution was received.'
                  : 'Received for ${campaign.name}.',
              when: now.add(const Duration(minutes: 1)),
            ));
          }
          changed = true;
        }
      case 'family_debt':
        for (final row in rows) {
          final value = adapter.decode(row) as FamilyDebt;
          familyDebts.removeWhere((x) => x.id == value.id);
          if (value.status != 'archived') familyDebts.add(value);
          changed = true;
        }
      case 'debt_repayment':
        for (final row in rows) {
          final value = adapter.decode(row) as DebtRepayment;
          debtRepayments.removeWhere((x) => x.id == value.id);
          debtRepayments.add(value);
          changed = true;
        }
      case 'goal':
        for (final row in rows) {
          final g = adapter.decode(row) as Goal;
          goals.removeWhere((x) => x.id == g.id);
          if (g.status != 'archived') goals.add(g);
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
            final goal = goals.where((item) => item.id == g.goalId).firstOrNull;
            final before = goal == null ? 0 : savedOn(goal).minor;
            goalTxs.add(g);
            if (goal != null) {
              _maybeMilestone(goal,
                  before: before,
                  after: before +
                      g.amount.inCurrency(goal.target.currency, rate).minor);
            }
            changed = true;
          }
        }
      case 'list_item':
        for (final row in rows) {
          final i = adapter.decode(row) as ListItem;
          final previous = items.where((x) => x.id == i.id).firstOrNull;
          final newlyAssigned = i.assignedToId == realUser.id &&
              i.state != ItemState.done &&
              previous?.assignedToId != realUser.id;
          items.removeWhere((x) => x.id == i.id);
          if (i.deletedAt == null) {
            // Tombstones stay out of memory - they were removed above.
            items.insert(0, i);
          }
          if (newlyAssigned) {
            _reminderExtras.add(Reminder(
              key: 'shopping_assigned_${i.id}',
              category: ReminderCategory.shopping,
              title: '${i.name} was assigned to you',
              body: 'Quantity ${i.qty} · estimated ${i.est.text}.',
              when: now.add(const Duration(minutes: 1)),
            ));
          }
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
          if (!r.isArchived) recurring.add(r);
          changed = true;
        }
      case 'chore':
        for (final row in rows) {
          final c = adapter.decode(row) as Chore;
          chores.removeWhere((x) => x.id == c.id);
          if (!c.isArchived) chores.add(c);
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
            avatarUrl: members[i].avatarUrl,
          );
        }
      }
    } catch (_) {
      // corrupt overrides are ignored - seed data stays intact
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
      avatarUrl: m.avatarUrl,
    );
    if (id == _user.id) _user = members[i];
    _persistKv(
      'profile_edits',
      jsonEncode({
        for (final m2 in members) m2.id: {'name': m2.name, 'emoji': m2.emoji},
      }),
    );
    _persistKv('members_v1', _membersJson());
    notifyListeners();
  }

  /// Sets the authoritative authenticated member for this session.
  void setRealUser(Member m) {
    _realUserId = m.id;
    _previewId = m.id;
    _user = m;
    notifyListeners();
  }

  void switchUser(Member m) {
    // "Preview as…", not impersonation: the switch is labelled in the UI,
    // a banner on Home always shows who is being previewed, and it resets
    // on restart (never persisted). The real signed-in identity stays
    // [_realUserId] so [exitPreview] always lands back on it.
    _realUserId ??= _user.id;
    _previewId = m.id;
    _user = m;
    notifyListeners();
  }

  String? _realUserId;
  String? _previewId;

  /// True while the UI is previewing a member other than the signed-in user.
  bool get isPreviewing {
    final real = _realUserId ?? _user.id;
    return _previewId != null && _previewId != real;
  }

  /// Leaves "Preview as…" mode and restores the signed-in member.
  void exitPreview() {
    if (!isPreviewing) return;
    final me = members.firstWhere(
      (m) => m.id == _realUserId,
      orElse: () => _user,
    );
    _user = me;
    _previewId = me.id;
    notifyListeners();
  }

  /// Host of the configured sync endpoint (for the Sync & data screen).
  String? get syncHost {
    final u = env.supabaseUrl;
    if (u == null || u.isEmpty) return null;
    return Uri.tryParse(u)?.host;
  }

  /// Restore-after-reinstall: the engine recovered this device's family
  /// from the auth token - the setup screen yields to the shell.
  void markOnboardingRestored() {
    onboardingComplete = true;
    notifyListeners();
  }

  // ── Role switches (owner-controlled, enforced by RLS - migration 011) ──────

  /// Mirror of family_space.settings -> role_permissions. Absent keys behave
  /// exactly like the server defaults, so UI and RLS never disagree.
  Map<String, bool> _rolePerms = {};

  static const Map<String, bool> _permDefaults = {
    'child_wallet': true,
    'child_transactions': false,
    'child_budget': true,
    'teen_wallet': true,
    'teen_transactions': true,
    'teen_budget': true,
  };

  Future<void> applyRolePermissions(Map<String, bool> perms) async {
    if (!canAdmin) {
      debugPrint(
          'Mhuri: unauthorized applyRolePermissions for role: ${authRole.name}');
      return;
    }
    _rolePerms = perms;
    notifyListeners();
  }

  bool perm(String key) => _rolePerms[key] ?? _permDefaults[key] ?? true;

  Member get realUser {
    final realId = _realUserId ?? _user.id;
    return members.firstWhere((m) => m.id == realId, orElse: () => _user);
  }

  /// The authoritative role for permission checks (actions, write mutations,
  /// administration). When previewing another member, permission checks MUST
  /// evaluate against the real authenticated user, never the previewed member.
  Role get authRole => realUser.role;

  /// Whether the authenticated member has admin/owner rights to manage settings,
  /// invitations, or approve requests.
  bool get canAdmin => authRole == Role.owner;

  /// Whether the authenticated member can invite new members.
  bool get canInvite => authRole == Role.owner;

  /// Whether the authenticated member can approve requests or proposals.
  bool get canApprove => authRole == Role.owner || authRole == Role.adult;

  /// Whether the authenticated member can edit budgets or move allocations.
  bool get canEditBudgets => authRole == Role.owner || authRole == Role.adult;

  /// Whether the authenticated member can transfer ownership of the family space.
  bool get canTransferOwnership => authRole == Role.owner;

  /// Whether the authenticated member can delete the family space.
  bool get canDeleteSpace => authRole == Role.owner;

  /// Whether the member has permission to initiate a transaction based on their
  /// authoritative role and family permission switches.
  bool canTransactFor(Role r) => switch (r) {
        Role.owner || Role.adult => true,
        Role.teen => teenCanTransact,
        Role.kid => kidCanTransact,
        Role.viewer => false,
      };

  bool get canAuthorTransact => canTransactFor(authRole);

  bool canViewBudgetFor(Role r) => switch (r) {
        Role.owner || Role.adult || Role.viewer => true,
        Role.teen => teenCanSeeBudget,
        Role.kid => kidCanSeeBudget,
      };

  bool get canAuthorViewBudget => canViewBudgetFor(authRole);

  bool canViewWalletFor(Role r) => switch (r) {
        Role.owner || Role.adult || Role.viewer => true,
        Role.teen => perm('teen_wallet'),
        Role.kid => perm('child_wallet'),
      };

  bool get canAuthorViewWallet => canViewWalletFor(authRole);

  bool get canEditLists => authRole == Role.owner || authRole == Role.adult;
  bool get canContributeSavings => authRole != Role.viewer;

  bool get kidCanTransact => perm('child_transactions');
  bool get teenCanTransact => perm('teen_transactions');
  bool get kidCanSeeBudget => perm('child_budget');
  bool get teenCanSeeBudget => perm('teen_budget');

  void toggleDisplayCurrency() {
    final list = activeCurrencies;
    if (list.length <= 1) return;
    final idx = list.indexOf(displayCurrency);
    displayCurrency = list[(idx + 1) % list.length];
    _persistKv('displayCurrency', displayCurrency.name);
    notifyListeners();
  }

  void setDisplayCurrency(Currency c) {
    displayCurrency = c;
    _persistKv('displayCurrency', c.name);
    notifyListeners();
  }

  void setPrimaryCurrency(Currency c) {
    primaryCurrency = c;
    if (secondaryCurrency == c) secondaryCurrency = null;
    displayCurrency = c;
    Money.primaryCurrency = primaryCurrency;
    Money.secondaryCurrency = secondaryCurrency;
    _persistKv('primary_currency', c.name);
    _persistKv('displayCurrency', c.name);
    if (secondaryCurrency != null) {
      rate = primaryCurrency.defaultRateTo(secondaryCurrency!);
      _persistKv('rate_${primaryCurrency.name}_${secondaryCurrency!.name}',
          rate.toStringAsFixed(4));
    }
    notifyListeners();
  }

  void setSecondaryCurrency(Currency? c) {
    secondaryCurrency = c;
    if (c == null && displayCurrency != primaryCurrency) {
      displayCurrency = primaryCurrency;
    }
    Money.primaryCurrency = primaryCurrency;
    Money.secondaryCurrency = secondaryCurrency;
    _persistKv('secondary_currency', c?.name ?? 'none');
    if (c != null) {
      rate = primaryCurrency.defaultRateTo(c);
      _persistKv(
          'rate_${primaryCurrency.name}_${c.name}', rate.toStringAsFixed(4));
    }
    notifyListeners();
  }

  /// Custom exchange rate from Settings → Currency & rates.
  void setCustomRate(double r) {
    rate = r.clamp(0.0001, 10000000);
    _persistKv('custom_rate', rate.toStringAsFixed(4));
    if (secondaryCurrency != null) {
      _persistKv('rate_${primaryCurrency.name}_${secondaryCurrency!.name}',
          rate.toStringAsFixed(4));
    }
    notifyListeners();
  }

  void setAutoHideAmounts(bool on) {
    autoHideAmounts = on;
    _persistKv('auto_hide', on ? '1' : '0');
    notifyListeners();
  }

  void setOverspendPolicy(OverspendPolicy p) {
    if (!canAdmin) {
      debugPrint(
          'Mhuri: unauthorized setOverspendPolicy for role: ${authRole.name}');
      return;
    }
    overspendPolicy = p;
    _persistKv('overspend_policy', p.name);
    notifyListeners();
  }

  Money disp(Money m) => m.inCurrency(displayCurrency, rate);

  void syncNow({bool force = false}) {
    final e = sync;
    if (e != null && env.isConfigured) {
      e.syncNow(force: force);
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

  /// Family Pool = opening/tagged account balances plus the transaction
  /// ledger. Income adds to available family money; expenses reduce it.
  ///
  /// Transactions are the only way the current UI changes money, so ignoring
  /// them made the pool stay at zero while Recent activity showed otherwise.
  Money poolCombined(Currency c) {
    var sum = 0;
    for (final a in accounts) {
      sum += a.balance.inCurrency(c, rate).minor;
    }
    for (final t in txs) {
      final amount = t.amount.inCurrency(c, rate).minor;
      sum += t.type == TxType.income ? amount : -amount;
    }
    return Money(sum, c);
  }

  /// Money held across all savings goals. Goal contributions are transfers
  /// out of spendable cash, not expenses, so they remain part of the family's
  /// total money while no longer being available to spend.
  Money totalSaved(Currency c) {
    var sum = 0;
    for (final t in goalTxs) {
      sum += t.amount.inCurrency(c, rate).minor;
    }
    return Money(sum, c);
  }

  /// Cash that can still be spent after money moved into savings.
  Money availableToSpend(Currency c) => Money(
        poolCombined(c).minor - totalSaved(c).minor,
        c,
      );

  // ── Cycle math (M4: payday-aligned months + rollover carry) ──────────────

  /// Start of the cycle containing [now] (e.g. day 25 for salary cycles).
  DateTime cycleStartFor(DateTime now) => now.day >= monthStartDay
      ? DateTime(now.year, now.month, monthStartDay)
      : DateTime(now.year, now.month - 1, monthStartDay);

  DateTime nextCycleStartFor(DateTime now) {
    final cs = cycleStartFor(now);
    return DateTime(cs.year, cs.month + 1, monthStartDay);
  }

  DateTime get now => _clock();
  DateTime get cycleStart => cycleStartFor(now);
  DateTime get nextCycleStart => nextCycleStartFor(now);

  BudgetCyclePlan? get currentBudgetPlan {
    final key = _cycleKey(cycleStart);
    for (final plan in budgetPlans) {
      if (_cycleKey(plan.cycleStart) == key) return plan;
    }
    return null;
  }

  BudgetCyclePlan? get previousBudgetPlan {
    final previous =
        DateTime(cycleStart.year, cycleStart.month - 1, monthStartDay);
    final key = _cycleKey(previous);
    for (final plan in budgetPlans) {
      if (_cycleKey(plan.cycleStart) == key) return plan;
    }
    return null;
  }

  String _cycleKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Saves the family's explicit plan for the current cycle. The allocation
  /// snapshot is versioned with the cycle while envelope limits power the
  /// existing day-to-day budget calculations.
  bool saveCurrentBudgetPlan({
    required IncomePlanMode incomeMode,
    Money? expectedIncome,
  }) {
    if (!canEditBudgets ||
        (incomeMode == IncomePlanMode.knownMonthly &&
            (expectedIncome == null || expectedIncome.minor <= 0))) {
      return false;
    }
    var plan = currentBudgetPlan;
    if (plan?.isClosed ?? false) return false;
    final allocations = {for (final e in envelopes) e.id: e.limit.minor};
    plan ??= BudgetCyclePlan(
      id: uuidFromSeed(
          '${sync?.spaceId ?? space.name}:${_cycleKey(cycleStart)}'),
      cycleStart: cycleStart,
      incomeMode: incomeMode,
      allocations: allocations,
    );
    plan
      ..incomeMode = incomeMode
      ..expectedIncome =
          incomeMode == IncomePlanMode.knownMonthly ? expectedIncome : null
      ..allocations = allocations;
    if (!budgetPlans.contains(plan)) budgetPlans.add(plan);
    _persistBudgetPlan(plan);
    _queue('budget_cycle_plan', plan);
    pendingOps++;
    notifyListeners();
    return true;
  }

  /// Applies last cycle's agreed allocations to this cycle and records the
  /// provenance. Historical plans are never edited.
  bool useLastMonthPlan() {
    if (!canEditBudgets || (currentBudgetPlan?.isClosed ?? false)) return false;
    final source = previousBudgetPlan;
    if (source == null) return false;
    for (final envelope in envelopes) {
      final amount = source.allocations[envelope.id];
      if (amount == null) continue;
      envelope.limit = Money(amount, envelope.limit.currency);
      _persistEnvelope(envelope);
      _queue('envelope', envelope);
    }
    final plan = BudgetCyclePlan(
      id: uuidFromSeed(
          '${sync?.spaceId ?? space.name}:${_cycleKey(cycleStart)}'),
      cycleStart: cycleStart,
      incomeMode: source.incomeMode,
      expectedIncome: source.expectedIncome,
      allocations: Map<String, int>.from(source.allocations),
      copiedFrom: source.cycleStart,
    );
    budgetPlans
        .removeWhere((p) => _cycleKey(p.cycleStart) == _cycleKey(cycleStart));
    budgetPlans.add(plan);
    _persistBudgetPlan(plan);
    _queue('budget_cycle_plan', plan);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool closeCurrentBudgetPlan() {
    if (!canEditBudgets) return false;
    final plan = currentBudgetPlan;
    if (plan == null || plan.isClosed) return false;
    plan
      ..isClosed = true
      ..closedAt = now;
    _persistBudgetPlan(plan);
    _queue('budget_cycle_plan', plan);
    pendingOps++;
    notifyListeners();
    return true;
  }

  int get daysLeftInCycle => nextCycleStart.difference(now).inDays + 1;

  Money _spentInCycle(Envelope e, DateTime from, DateTime to) {
    var sum = 0;
    for (final t in txs) {
      if (t.type != TxType.expense ||
          t.when.isBefore(from) ||
          !t.when.isBefore(to)) {
        continue;
      }
      final splits = txAllocations.where((a) => a.txId == t.id).toList();
      if (splits.isNotEmpty) {
        for (final a in splits.where((a) => a.envelopeId == e.id)) {
          sum += a.amount.inCurrency(e.limit.currency, rate).minor;
        }
      } else if (t.envelopeId == e.id) {
        sum += t.amount.inCurrency(e.limit.currency, rate).minor;
      }
    }
    return Money(sum, e.limit.currency);
  }

  Money get allocated {
    var sum = 0;
    for (final e in envelopes) {
      sum += e.limit.inCurrency(primaryCurrency, rate).minor;
    }
    return Money(sum, primaryCurrency);
  }

  Money get spentTotal {
    var sum = 0;
    for (final e in envelopes) {
      final s = spentOn(e).inCurrency(primaryCurrency, rate).minor;
      if (s > 0) sum += s;
    }
    return Money(sum, primaryCurrency);
  }

  Money get _remainingUsd {
    var sum = 0;
    for (final e in envelopes) {
      final left = e.limit.inCurrency(primaryCurrency, rate).minor -
          spentOn(e).inCurrency(primaryCurrency, rate).minor;
      if (left > 0) sum += left;
    }
    return Money(sum, primaryCurrency);
  }

  /// Unspent positive envelope commitments in the current budget cycle.
  /// Over-budget envelopes contribute zero rather than cancelling money that
  /// is still reserved for another envelope.
  Money get reservedForEnvelopes => _remainingUsd;

  /// "Safe to spend today" = flexible money left ÷ days left in cycle.
  Money get safeToSpend {
    final pool = availableToSpend(displayCurrency).minor -
        _remainingUsd.inCurrency(displayCurrency, rate).minor;
    final v = (pool / daysLeftInCycle).floor();
    return Money(v < 0 ? 0 : v, displayCurrency);
  }

  // ── Envelopes ─────────────────────────────────────────────────────────────

  /// Spending on an envelope within the CURRENT cycle, in the envelope's
  /// own currency.
  Money spentOn(Envelope e) => _spentInCycle(e, cycleStart, nextCycleStart);

  Money remainingOn(Envelope e) =>
      Money(effectiveLimit(e).minor - spentOn(e).minor, e.limit.currency);

  void addEnvelope({
    required String name,
    required Money limit,
    Rollover rollover = Rollover.reset,
    String emoji = 'money',
  }) {
    if (!canEditBudgets) {
      debugPrint('Mhuri: unauthorized addEnvelope for role: ${authRole.name}');
      return;
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    // Guard against duplicate envelopes with the same name
    final existingIndex = envelopes.indexWhere(
      (e) =>
          !e.isPersonal &&
          e.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    );
    if (existingIndex != -1) {
      final existing = envelopes[existingIndex];
      existing
        ..name = trimmedName
        ..emoji = emoji
        ..limit = limit
        ..rollover = rollover
        ..isArchived = false;
      _persistEnvelope(existing);
      _queue('envelope', existing);
      pendingOps++;
      notifyListeners();
      return;
    }

    final envelope = Envelope(
      id: _seq('e'),
      name: trimmedName,
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

  bool updateEnvelope(
    Envelope envelope, {
    required String name,
    required Money limit,
    required Rollover rollover,
  }) {
    if (!canEditBudgets || name.trim().isEmpty || limit.minor <= 0) {
      return false;
    }
    envelope
      ..name = name.trim()
      ..limit = limit
      ..rollover = rollover;
    _persistEnvelope(envelope);
    _queue('envelope', envelope);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool archiveEnvelope(Envelope envelope) {
    if (!canAdmin) return false;
    envelope.isArchived = true;
    _persistEnvelope(envelope);
    _queue('envelope', envelope);
    envelopes.removeWhere((e) => e.id == envelope.id);
    pendingOps++;
    notifyListeners();
    return true;
  }

  /// Removes an envelope from the active budget list. Previous transaction history is preserved.
  bool removeEnvelope(Envelope envelope) => archiveEnvelope(envelope);

  /// Safely resolves and cleans up duplicate non-personal envelopes by name.
  /// Retains the envelope with transactions or configured limit, redirects
  /// any dangling transaction references, archives redundant duplicates
  /// locally and across sync, and updates in-memory state.
  void deduplicateEnvelopes() {
    if (envelopes.isEmpty) return;

    final byName = <String, List<Envelope>>{};
    for (final e in envelopes) {
      if (e.isPersonal) continue;
      final key = e.name.trim().toLowerCase();
      if (key.isEmpty) continue;
      byName.putIfAbsent(key, () => []).add(e);
    }

    var changed = false;
    for (final entry in byName.entries) {
      final list = entry.value;
      if (list.length <= 1) continue;

      // Duplicate envelopes detected for this name
      Envelope pickBest(List<Envelope> candidates) {
        final withTxs = candidates
            .where((e) => txs.any((t) => t.envelopeId == e.id))
            .toList();
        if (withTxs.isNotEmpty) {
          withTxs.sort((a, b) => b.limit.minor.compareTo(a.limit.minor));
          return withTxs.first;
        }
        final withLimit = candidates.where((e) => e.limit.minor > 0).toList();
        if (withLimit.isNotEmpty) {
          withLimit.sort((a, b) => b.limit.minor.compareTo(a.limit.minor));
          return withLimit.first;
        }
        return candidates.first;
      }

      final keep = pickBest(list);
      for (final dup in list) {
        if (dup.id == keep.id) continue;

        // Re-link transactions pointing to duplicate
        for (var i = 0; i < txs.length; i++) {
          if (txs[i].envelopeId == dup.id) {
            txs[i] = Tx(
              id: txs[i].id,
              memberId: txs[i].memberId,
              amount: txs[i].amount,
              envelopeId: keep.id,
              type: txs[i].type,
              method: txs[i].method,
              note: txs[i].note,
              when: txs[i].when,
              deletedAt: txs[i].deletedAt,
              receiptUri: txs[i].receiptUri,
              recurringRuleId: txs[i].recurringRuleId,
            );
            _persistTx(txs[i]);
          }
        }

        // Archive and delete duplicate
        dup.isArchived = true;
        _persistEnvelope(dup);
        _queue('envelope', dup);
        envelopes.removeWhere((e) => e.id == dup.id);
        pendingOps++;
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Effective limit including rollover carry (spec D4).
  ///
  ///  * roll: one-cycle lookback - carry = unspent from the previous cycle.
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
    final now = this.now;
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

  /// D7 - move allocation between envelopes with a reason.
  bool moveMoney(Envelope from, Envelope to, Money amount, String reason,
      {String? id}) {
    if (!canEditBudgets) {
      debugPrint('Mhuri: unauthorized moveMoney for role: ${authRole.name}');
      return false;
    }
    final opId = id ??
        '${from.id}_${to.id}_${amount.minor}_${DateTime.now().millisecondsSinceEpoch ~/ 500}';
    if (_processedMutationIds.contains(opId)) {
      debugPrint('Mhuri: duplicate moveMoney ignored: $opId');
      return false;
    }
    _processedMutationIds.add(opId);
    final amtTo = amount.inCurrency(to.limit.currency, rate);
    from.limit = Money(from.limit.minor - amount.minor, from.limit.currency);
    to.limit = Money(to.limit.minor + amtTo.minor, to.limit.currency);
    _persistEnvelope(from);
    _persistEnvelope(to);
    _queue('envelope', from);
    _queue('envelope', to);
    pendingOps++;
    notifyListeners();
    return true;
  }

  // ── Transactions ──────────────────────────────────────────────────────────

  /// Client row ids must be well-formed uuids - server id columns are
  /// uuid and a sequential 'tx0' would fail the cast on real Postgres.
  String _seq(String p) => newUuid();

  bool addTx({
    required TxType type,
    required Money amount,
    required String memberId,
    required Method method,
    required String note,
    DateTime? when,
    String? envelopeId,
    String? receiptUri,
    String? recurringRuleId,
    Map<String, Money>? allocations,
    String? id,
    bool force = false,
  }) {
    final txId = id ?? _seq('t');
    if (!canAuthorTransact) {
      debugPrint('Mhuri: unauthorized addTx for role: ${authRole.name}');
      return false;
    }
    if (txs.any((t) => t.id == txId) || _processedMutationIds.contains(txId)) {
      debugPrint('Mhuri: duplicate addTx ignored: $txId');
      return false;
    }
    if (allocations != null && allocations.isNotEmpty) {
      final total = allocations.values.fold<int>(0,
          (sum, value) => sum + value.inCurrency(amount.currency, rate).minor);
      if (total != amount.minor ||
          allocations.values.any((v) => v.minor <= 0) ||
          allocations.keys.any((id) => envelope(id) == null)) {
        return false;
      }
    }

    if (type == TxType.expense && envelopeId != null && !force) {
      final env = envelope(envelopeId);
      if (env != null && overspendPolicy == OverspendPolicy.block) {
        final remaining = remainingOn(env);
        final entered = amount.inCurrency(env.limit.currency, rate);
        if (entered.minor > remaining.minor) {
          debugPrint(
              'Mhuri: transaction blocked by envelope overspend policy: $txId');
          return false;
        }
      }
    }

    _processedMutationIds.add(txId);
    final t = Tx(
      id: txId,
      envelopeId: envelopeId,
      memberId: memberId,
      type: type,
      amount: amount,
      method: method,
      note: note,
      when: when ?? DateTime.now(),
      receiptUri: receiptUri,
      recurringRuleId: recurringRuleId,
    );
    txs.insert(0, t);
    _persistTx(t);
    _queue('tx', t);
    if (allocations != null) {
      for (final entry in allocations.entries) {
        final allocation = TxAllocation(
            id: uuidFromSeed('$txId:${entry.key}'),
            txId: txId,
            envelopeId: entry.key,
            amount: entry.value);
        txAllocations.add(allocation);
        if (_store != null) _fire(_store!.saveTxAllocation(allocation));
        _queue('tx_allocation', allocation);
      }
    }
    pendingOps++;
    _resyncReminders();
    notifyListeners();
    return true;
  }

  bool updateTx(
    Tx tx, {
    required Money amount,
    required Method method,
    required String note,
    required DateTime when,
    String? envelopeId,
  }) {
    final owns = tx.memberId == realUser.id;
    if ((!owns && !canAdmin) || amount.minor <= 0) return false;
    final updated = Tx(
      id: tx.id,
      memberId: tx.memberId,
      type: tx.type,
      amount: amount,
      method: method,
      note: note.trim(),
      when: when,
      envelopeId: envelopeId,
      deletedAt: tx.deletedAt,
      receiptUri: tx.receiptUri,
      recurringRuleId: tx.recurringRuleId,
    );
    final index = txs.indexWhere((t) => t.id == tx.id);
    if (index >= 0) txs[index] = updated;
    _persistTx(updated);
    _queue('tx', updated);
    txs.sort((a, b) => b.when.compareTo(a.when));
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool deleteTx(Tx tx) {
    final owns = tx.memberId == realUser.id;
    if (!owns && !canAdmin) return false;
    final deleted = Tx(
      id: tx.id,
      memberId: tx.memberId,
      type: tx.type,
      amount: tx.amount,
      method: tx.method,
      note: tx.note,
      when: tx.when,
      envelopeId: tx.envelopeId,
      deletedAt: DateTime.now(),
      receiptUri: tx.receiptUri,
      recurringRuleId: tx.recurringRuleId,
    );
    _persistTx(deleted);
    _queue('tx', deleted);
    txs.removeWhere((t) => t.id == tx.id);
    pendingOps++;
    notifyListeners();
    return true;
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

  Money actualShoppingFor(Currency c) {
    var sum = 0;
    for (final i in items) {
      if (i.state == ItemState.done || i.state == ItemState.incart) {
        sum += (i.actual ?? i.est).inCurrency(c, rate).minor * i.qty;
      }
    }
    return Money(sum, c);
  }

  void addItem(String name, int qty, Money est, {String? assignedToId}) {
    if (!canEditLists) {
      debugPrint('Mhuri: unauthorized addItem for role: ${authRole.name}');
      return;
    }
    final i = ListItem(
      id: _seq('i'),
      name: name,
      qty: qty,
      est: est,
      addedById: _user.id,
      assignedToId: assignedToId,
    );
    items.insert(0, i);
    _persistItem(i);
    _queue('list_item', i);
    pendingOps++;
    notifyListeners();
  }

  bool updateItem(
    ListItem item, {
    required String name,
    required int qty,
    required Money estimate,
    Money? actual,
    String? assignedToId,
  }) {
    if (!canEditLists || name.trim().isEmpty || qty < 1 || estimate.minor < 0) {
      return false;
    }
    item
      ..name = name.trim()
      ..qty = qty
      ..est = estimate
      ..actual = actual
      ..assignedToId = assignedToId;
    _persistItem(item);
    _queue('list_item', item);
    pendingOps++;
    notifyListeners();
    return true;
  }

  /// Removes an item everywhere: tombstone locally + sync flag - other
  /// devices remove their copy when the tombstone arrives. Never a hard
  /// delete (those cannot sync).
  void deleteItem(ListItem item) {
    if (!canEditLists) {
      debugPrint('Mhuri: unauthorized deleteItem for role: ${authRole.name}');
      return;
    }
    item.deletedAt = DateTime.now();
    items.removeWhere((x) => x.id == item.id);
    _persistItem(item); // kept locally with the tombstone for the push
    _queue('list_item', item);
    pendingOps++;
    notifyListeners();
  }

  void advanceItem(ListItem item) {
    if (!canEditLists) {
      debugPrint('Mhuri: unauthorized advanceItem for role: ${authRole.name}');
      return;
    }
    if (item.checkedOut && item.state == ItemState.done) {
      // Explicitly moving a purchased item back to "to buy" starts a new
      // shopping cycle and makes it eligible for checkout again.
      item.checkedOut = false;
      item.state = ItemState.tobuy;
      item.actual = null;
      item.purchasedById = null;
    } else {
      item.state = item.state.next;
    }
    _persistItem(item);
    _queue('list_item', item);
    pendingOps++;
    notifyListeners();
  }

  /// F5 - "Finish shopping" closes the loop: checked items become one expense
  /// pre-filled with the estimate, posted to the linked envelope.
  Money finishShopping({
    String? txId,
    String? envelopeId,
    Method method = Method.bankCard,
  }) {
    // Prefer a Groceries envelope; fall back to the first shared one.
    Envelope? target;
    if (envelopeId != null) target = envelope(envelopeId);
    if (target == null) {
      for (final e in envelopes) {
        if (!e.isPersonal && e.name.toLowerCase().contains('grocer')) {
          target = e;
          break;
        }
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
    final cur = target?.limit.currency ?? primaryCurrency;

    if (!canAuthorTransact) {
      debugPrint(
          'Mhuri: unauthorized finishShopping for role: ${authRole.name}');
      return Money(0, cur);
    }
    var sum = 0;
    for (final i in items) {
      if (!i.checkedOut &&
          (i.state == ItemState.done || i.state == ItemState.incart)) {
        sum += (i.actual ?? i.est).inCurrency(cur, rate).minor * i.qty;
        i.state = ItemState.done;
        i.checkedOut = true;
        i.purchasedById = _user.id;
        _persistItem(i);
        _queue('list_item', i);
      }
    }
    final total = Money(sum, cur);
    if (total.isZero) return total;

    addTx(
      id: txId,
      type: TxType.expense,
      amount: total,
      memberId: _user.id,
      method: method,
      note: 'Groceries run - FreshMart',
      envelopeId: target?.id,
    );
    return total;
  }

  // ── Goals & savings circles (Module E) ────────────────────────────────────────────

  void createContributionCampaign(
      {required String name,
      required Money target,
      required DateTime deadline}) {
    if (!canEditBudgets || name.trim().isEmpty || target.minor <= 0) return;
    final value = ContributionCampaign(
        id: newUuid(),
        name: name.trim(),
        target: target,
        deadline: deadline,
        createdById: realUser.id);
    contributionCampaigns.add(value);
    if (_store != null) _fire(_store!.saveContributionCampaign(value));
    _queue('contribution_campaign', value);
    pendingOps++;
    notifyListeners();
  }

  Money pledgedFor(ContributionCampaign campaign, [String? memberId]) {
    var sum = 0;
    for (final p in contributionPledges) {
      if (p.campaignId == campaign.id &&
          (memberId == null || p.memberId == memberId)) {
        sum += p.amount.inCurrency(campaign.target.currency, rate).minor;
      }
    }
    return Money(sum, campaign.target.currency);
  }

  Money collectedFor(ContributionCampaign campaign, [String? memberId]) {
    var sum = 0;
    for (final p in contributionPayments) {
      if (p.campaignId == campaign.id &&
          (memberId == null || p.memberId == memberId)) {
        sum += p.amount.inCurrency(campaign.target.currency, rate).minor;
      }
    }
    return Money(sum, campaign.target.currency);
  }

  bool setContributionPledge(
      ContributionCampaign campaign, String memberId, Money amount) {
    if ((!canAdmin && memberId != realUser.id) || amount.minor <= 0) {
      return false;
    }
    final id = uuidFromSeed('${campaign.id}:pledge:$memberId');
    final existing = contributionPledges.where((p) => p.id == id).firstOrNull;
    final value = existing ??
        ContributionPledge(
            id: id,
            campaignId: campaign.id,
            memberId: memberId,
            amount: amount,
            createdAt: now);
    value.amount = amount;
    if (existing == null) contributionPledges.add(value);
    if (_store != null) _fire(_store!.saveContributionPledge(value));
    _queue('contribution_pledge', value);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool recordContributionPayment(
      ContributionCampaign campaign, String memberId, Money amount,
      {String? id}) {
    if ((!canAdmin && memberId != realUser.id) || amount.minor <= 0) {
      return false;
    }
    final paymentId = id ?? newUuid();
    if (contributionPayments.any((p) => p.id == paymentId)) return false;
    final value = ContributionPayment(
        id: paymentId,
        campaignId: campaign.id,
        memberId: memberId,
        amount: amount,
        paidAt: now);
    contributionPayments.add(value);
    if (_store != null) _fire(_store!.saveContributionPayment(value));
    _queue('contribution_payment', value);
    pendingOps++;
    notifyListeners();
    return true;
  }

  void createDebt(
      {required String name,
      required DebtDirection direction,
      required Money principal,
      String? counterpartyMemberId,
      DateTime? dueDate}) {
    if (!canEditBudgets || name.trim().isEmpty || principal.minor <= 0) return;
    final value = FamilyDebt(
        id: newUuid(),
        name: name.trim(),
        direction: direction,
        principal: principal,
        createdById: realUser.id,
        counterpartyMemberId: counterpartyMemberId,
        dueDate: dueDate);
    familyDebts.add(value);
    if (_store != null) _fire(_store!.saveFamilyDebt(value));
    _queue('family_debt', value);
    pendingOps++;
    notifyListeners();
  }

  Money repaidOn(FamilyDebt debt) {
    var total = 0;
    for (final p in debtRepayments) {
      if (p.debtId == debt.id) {
        total += p.amount.inCurrency(debt.principal.currency, rate).minor;
      }
    }
    return Money(total, debt.principal.currency);
  }

  Money remainingOnDebt(FamilyDebt debt) => Money(
      (debt.principal.minor - repaidOn(debt).minor)
          .clamp(0, debt.principal.minor),
      debt.principal.currency);

  bool recordDebtRepayment(FamilyDebt debt, Money amount, {String? id}) {
    if (!canEditBudgets || amount.minor <= 0 || debt.status != 'active') {
      return false;
    }
    final paymentId = id ?? newUuid();
    if (debtRepayments.any((p) => p.id == paymentId)) return false;
    final inDebt = amount.inCurrency(debt.principal.currency, rate);
    if (inDebt.minor > remainingOnDebt(debt).minor) return false;
    final value = DebtRepayment(
        id: paymentId,
        debtId: debt.id,
        memberId: realUser.id,
        amount: amount,
        paidAt: now);
    debtRepayments.add(value);
    if (remainingOnDebt(debt).minor == 0) {
      debt.status = 'settled';
      if (_store != null) _fire(_store!.saveFamilyDebt(debt));
      _queue('family_debt', debt);
    }
    if (_store != null) _fire(_store!.saveDebtRepayment(value));
    _queue('debt_repayment', value);
    pendingOps++;
    notifyListeners();
    return true;
  }

  Money savedOn(Goal g) {
    var sum = 0;
    for (final t in goalTxs) {
      if (t.goalId == g.id) {
        sum += t.amount.inCurrency(g.target.currency, rate).minor;
      }
    }
    return Money(sum, g.target.currency);
  }

  void addGoal({
    required String name,
    required Money target,
    String emoji = 'goal',
    bool isKidJar = false,
    String? ownerMemberId,
  }) {
    if (!canEditBudgets) {
      debugPrint('Mhuri: unauthorized addGoal for role: ${authRole.name}');
      return;
    }
    final goal = Goal(
      id: _seq('g'),
      name: name.trim(),
      emoji: emoji,
      target: target,
      isKidJar: isKidJar,
      ownerMemberId: ownerMemberId,
    );
    goals.insert(0, goal);
    _persistGoal(goal);
    _queue('goal', goal);
    pendingOps++;
    _resyncReminders();
    notifyListeners();
  }

  bool updateGoal(Goal goal, {required String name, required Money target}) {
    if (!canEditBudgets || name.trim().isEmpty || target.minor <= 0) {
      return false;
    }
    final updated = Goal(
      id: goal.id,
      name: name.trim(),
      emoji: goal.emoji,
      target: target,
      autoSave: goal.autoSave,
      isKidJar: goal.isKidJar,
      ownerMemberId: goal.ownerMemberId,
      status: goal.status,
    );
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) goals[index] = updated;
    _persistGoal(updated);
    _queue('goal', updated);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool completeGoal(Goal goal) {
    if (!canEditBudgets) return false;
    final updated = Goal(
      id: goal.id,
      name: goal.name,
      emoji: goal.emoji,
      target: goal.target,
      autoSave: goal.autoSave,
      isKidJar: goal.isKidJar,
      ownerMemberId: goal.ownerMemberId,
      status: 'done',
    );
    final index = goals.indexWhere((g) => g.id == goal.id);
    if (index >= 0) goals[index] = updated;
    _persistGoal(updated);
    _queue('goal', updated);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool archiveGoal(Goal goal) {
    if (!canAdmin) return false;
    final archived = Goal(
      id: goal.id,
      name: goal.name,
      emoji: goal.emoji,
      target: goal.target,
      autoSave: goal.autoSave,
      isKidJar: goal.isKidJar,
      ownerMemberId: goal.ownerMemberId,
      status: 'archived',
    );
    _persistGoal(archived);
    _queue('goal', archived);
    goals.removeWhere((g) => g.id == goal.id);
    pendingOps++;
    notifyListeners();
    return true;
  }

  void contribute(Goal g, Money amount, {String? id}) {
    if (!canContributeSavings) {
      debugPrint('Mhuri: unauthorized contribute for role: ${authRole.name}');
      return;
    }
    if (id != null) {
      if (_processedMutationIds.contains(id)) return;
      if (goalTxs.any((t) => t.id == id)) return;
      _processedMutationIds.add(id);
    }
    final before = savedOn(g).minor;
    final t = GoalTx(
      id: id ?? newUuid(),
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

  void circleCollect({String? id}) {
    if (!canAdmin) return;
    if (id != null) {
      if (_processedMutationIds.contains(id)) return;
      _processedMutationIds.add(id);
    }
    if (circle.currentRound < circle.totalRounds) {
      circle.currentRound++;
      _persistSavingsCircle();
      _queue('mukando', circle);
      _resyncReminders();
      pendingOps++;
      notifyListeners();
    }
  }

  /// Undo for [circleCollect] - rounds are overwrite-safe (records only).
  void undoCircleCollect() {
    if (!canAdmin) return;
    if (circle.currentRound > 1) {
      circle.currentRound--;
      _persistSavingsCircle();
      _queue('mukando', circle);
      _resyncReminders();
      notifyListeners();
    }
  }

  // ── Kids Mode (Module G) ──────────────────────────────────────────────────

  Chore? addChore({required String name, required int starsReward}) {
    if (!canApprove) {
      debugPrint('Mhuri: unauthorized addChore for role: ${authRole.name}');
      return null;
    }
    final cleanName = name.trim();
    if (cleanName.isEmpty || starsReward < 1) return null;
    final chore = Chore(
      id: _seq('chore'),
      name: cleanName,
      stars: starsReward.clamp(1, 100),
    );
    chores.add(chore);
    _persistChore(chore);
    _queue('chore', chore);
    _resyncReminders();
    pendingOps++;
    notifyListeners();
    return chore;
  }

  bool updateChore(Chore chore,
      {required String name, required int starsReward, String? assigneeId}) {
    if (!canApprove || name.trim().isEmpty || starsReward < 1) return false;
    chore
      ..name = name.trim()
      ..stars = starsReward.clamp(1, 100)
      ..assigneeMemberId = assigneeId;
    _persistChore(chore);
    _queue('chore', chore);
    pendingOps++;
    notifyListeners();
    return true;
  }

  bool archiveChore(Chore chore) {
    if (!canApprove) return false;
    chore.isArchived = true;
    _persistChore(chore);
    _queue('chore', chore);
    chores.removeWhere((c) => c.id == chore.id);
    pendingOps++;
    notifyListeners();
    return true;
  }

  void claimChore(Chore c) {
    if (authRole != Role.kid || c.state != ChoreState.todo) return;
    if (c.assigneeMemberId != null && c.assigneeMemberId != realUser.id) return;
    c.assigneeMemberId ??= realUser.id;
    c.state = ChoreState.waiting;
    _persistChore(c);
    _queue('chore', c);
    _resyncReminders();
    pendingOps++;
    notifyListeners();
  }

  void confirmChore(Chore c) {
    if (!canApprove) {
      debugPrint('Mhuri: unauthorized confirmChore for role: ${authRole.name}');
      return;
    }
    if (c.state != ChoreState.waiting) return;
    c.state = ChoreState.confirmed;
    stars += c.stars;
    _persistChore(c);
    _queue('chore', c);
    _persistKv('stars', '$stars');
    pendingOps++;
    _resyncReminders();
    notifyListeners();
  }

  /// Undo for [confirmChore] - safe because chores are overwrite-safe.
  void unconfirmChore(Chore c) {
    if (!canApprove) {
      debugPrint(
          'Mhuri: unauthorized unconfirmChore for role: ${authRole.name}');
      return;
    }
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
    if (authRole != Role.kid || amount.minor <= 0 || reason.trim().isEmpty) {
      return;
    }
    final r = KidRequest(
      id: _seq('r'),
      kidId: _user.id,
      amount: amount,
      reason: reason.trim(),
    );
    requests.insert(0, r);
    _persistRequest(r);
    _queue('kid_request', r);
    pendingOps++;
    notifyListeners();
  }

  /// Approved money lands in the kid's jar (G5 → G2).
  void approveRequest(KidRequest r) {
    if (!canApprove) return;
    if (r.state != RequestState.pending) return;
    r.state = RequestState.approved;
    _persistRequest(r);
    _queue('kid_request', r);
    _resyncReminders();
    final jar = kidJarFor(r.kidId);
    if (jar != null) {
      final t = GoalTx(
        id: newUuid(),
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
    if (!canApprove) return;
    if (r.state != RequestState.pending) return;
    r.state = RequestState.declined;
    _persistRequest(r);
    _queue('kid_request', r);
    _resyncReminders();
    pendingOps++;
    notifyListeners();
  }

  // ── Teen Zone (Module H) ──────────────────────────────────────────────────

  /// H4 - parents match 50% of what the teen saves into their jar.
  double get teenMatchRate => 0.5;

  Money get teenMatchTotal {
    final jar = teenJarGoal;
    if (jar == null) return Money(0, displayCurrency);
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
        sum += e.amount.inCurrency(displayCurrency, rate).minor;
      }
    }
    return Money(sum, displayCurrency);
  }

  void addEarning(Money amount, String note) {
    if (authRole != Role.teen || amount.minor <= 0 || note.trim().isEmpty) {
      return;
    }
    final e = Earning(
      id: _seq('e'),
      memberId: _user.id,
      note: note.trim(),
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
    if (authRole != Role.teen ||
        amount.minor <= 0 ||
        reason.trim().isEmpty ||
        envelope(envelopeId) == null) {
      return;
    }
    final p = Proposal(
      id: _seq('p'),
      teenId: _user.id,
      amount: amount,
      envelopeId: envelopeId,
      reason: reason.trim(),
    );
    proposals.insert(0, p);
    _persistProposal(p);
    _queue('kid_request', p);
    pendingOps++;
    notifyListeners();
  }

  /// Approved teen proposal becomes a real expense on the family budget.
  void approveProposal(Proposal p) {
    if (!canApprove) return;
    if (p.state != RequestState.pending) return;
    final posted = addTx(
      type: TxType.expense,
      amount: p.amount,
      memberId: p.teenId,
      method: Method.cash,
      note: 'Approved: ${p.reason}',
      envelopeId: p.envelopeId,
    );
    if (!posted) return;
    p.state = RequestState.approved;
    _persistProposal(p);
    _queue('kid_request', p);
  }

  void declineProposal(Proposal p) {
    if (!canApprove) return;
    if (p.state != RequestState.pending) return;
    p.state = RequestState.declined;
    _persistProposal(p);
    _queue('kid_request', p);
    pendingOps++;
    notifyListeners();
  }

  // ── Reports (Module I1/I2 basics) ─────────────────────────────────────────

  /// One chronological family feed. Synced audit rows are authoritative;
  /// unsynced money events are derived locally so they appear immediately.
  List<FamilyActivity> get activityFeed {
    final result = List<FamilyActivity>.of(familyActivities);
    final audited = <String>{
      for (final a in familyActivities)
        if (a.entityId != null) '${a.entity}:${a.entityId}',
    };
    for (final t in txs) {
      if (audited.contains('transaction:${t.id}')) continue;
      result.add(FamilyActivity(
        id: 'local-tx-${t.id}',
        actorId: t.memberId,
        action: 'tx.create',
        entity: 'transaction',
        entityId: t.id,
        at: t.when,
        detail: {
          'amount_minor': t.amount.minor,
          'currency': t.amount.currency.code,
          'member_id': t.memberId,
        },
      ));
    }
    for (var i = 0; i < goalTxs.length; i++) {
      final t = goalTxs[i];
      if (t.id != null && audited.contains('goal_tx:${t.id}')) continue;
      result.add(FamilyActivity(
        id: 'local-goal-${t.id ?? '${t.goalId}-${t.at.millisecondsSinceEpoch}-$i'}',
        actorId: t.byMemberId,
        action: 'goal.contribute',
        entity: 'goal_tx',
        entityId: t.id,
        at: t.at,
        detail: {
          'amount_minor': t.amount.minor,
          'currency': t.amount.currency.code,
          'goal_id': t.goalId,
        },
      ));
    }
    for (final plan in budgetPlans) {
      if (audited.contains('budget_cycle_plan:${plan.id}')) continue;
      result.add(FamilyActivity(
        id: 'local-plan-${plan.id}',
        actorId: realUser.id,
        action: plan.isClosed ? 'plan.close' : 'plan.save',
        entity: 'budget_cycle_plan',
        entityId: plan.id,
        at: plan.closedAt ?? plan.cycleStart,
        detail: {'cycle_start': _cycleKey(plan.cycleStart)},
      ));
    }
    result.sort((a, b) => b.at.compareTo(a.at));
    return result;
  }

  List<Tx> get _txsInCurrentCycle => txs
      .where((t) =>
          !t.when.isBefore(cycleStart) && t.when.isBefore(nextCycleStart))
      .toList();

  Money get monthIncome {
    var sum = 0;
    for (final t in _txsInCurrentCycle) {
      if (t.type == TxType.income) {
        sum += t.amount.inCurrency(displayCurrency, rate).minor;
      }
    }
    return Money(sum, displayCurrency);
  }

  Money get monthSpend {
    var sum = 0;
    for (final t in _txsInCurrentCycle) {
      if (t.type == TxType.expense) {
        sum += t.amount.inCurrency(displayCurrency, rate).minor;
      }
    }
    return Money(sum, displayCurrency);
  }

  Money get monthSaved {
    var sum = 0;
    for (final t in goalTxs) {
      if (!t.at.isBefore(cycleStart) && t.at.isBefore(nextCycleStart)) {
        sum += t.amount.inCurrency(displayCurrency, rate).minor;
      }
    }
    return Money(sum, displayCurrency);
  }

  /// I1 - "envelope health": % of envelopes still on track (north-star).
  double get envelopeHealth {
    if (envelopes.isEmpty) return 1;
    final ok = envelopes.where((e) => paceOf(e) != Pace.over).length;
    return ok / envelopes.length;
  }

  /// "Cash leak" - share of expenses paid in untraceable cash (spec C5).
  double get cashLeakShare {
    var cash = 0;
    var all = 0;
    for (final t in _txsInCurrentCycle) {
      if (t.type == TxType.expense) {
        all += t.amount.inCurrency(displayCurrency, rate).minor;
        if (t.method == Method.cash) {
          cash += t.amount.inCurrency(displayCurrency, rate).minor;
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
