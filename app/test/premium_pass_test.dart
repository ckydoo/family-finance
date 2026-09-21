import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:mhuri_money/core/utils/ids.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Premium frontend pass (G1–G13) — the parts that are pure Dart:
///   G1 dark palette exists and differs; themeMode clamps + persists
///   G5 balance privacy toggle + persistence round-trip
///   G7 locale-aware money grouping (intl) with en default untouched
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;

  setUp(() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await AppDatabase.createSchema(d);
      },
    );
    db = AppDatabase.wrap(raw);
  });

  tearDown(() async {
    await db.raw.close();
  });

  Future<AppState> fresh() async {
    final s = AppState(db: db);
    await s.ready();
    return s;
  }

  test('G1: dark palette differs from light on every key surface', () {
    const l = MhuriColors.light;
    const d = MhuriColors.dark;
    expect(d.bg, isNot(l.bg));
    expect(d.card, isNot(l.card));
    expect(d.ink, isNot(l.ink));
    expect(d.primary, isNot(l.primary));
    // Dark surfaces are darker than the ink text on them (contrast sanity).
    expect(d.bg.computeLuminance() < d.ink.computeLuminance(), isTrue);
    // Light theme factory still builds.
    expect(buildAppTheme().brightness, Brightness.light);
    expect(buildAppDarkTheme().brightness, Brightness.dark);
  });

  test('G1: themeMode clamps to 0..2 and survives a persistence round-trip',
      () async {
    final s = await fresh();
    s.setThemeMode(5);
    expect(s.themeMode, 2);
    s.setThemeMode(-1);
    expect(s.themeMode, 0);
    s.setThemeMode(2);
    expect(s.themeMode, 2);

    final s2 = await fresh();
    expect(s2.themeMode, 2);
  });

  test('G5: hideAmounts toggles and survives a persistence round-trip',
      () async {
    final s = await fresh();
    expect(s.hideAmounts, isFalse);
    s.setHideAmounts(true);
    expect(s.hideAmounts, isTrue);

    final s2 = await fresh();
    expect(s2.hideAmounts, isTrue);
    s2.setHideAmounts(false);
  });

  test('G7: money grouping stays en-US by default (tests + boot)', () {
    Money.localeTag = null;
    expect(Money.fromMajor(1240.50, Currency.usd).text, 'US\$ 1,240.50');
    expect(Money(18940, Currency.zwg).text, 'ZiG 18,940');
  });

  test('G7: es/fr/pt locales regroup amounts (1.234,56)', () {
    Money.localeTag = 'es';
    expect(Money.fromMajor(1240.50, Currency.usd).text, 'US\$ 1.240,50');
    Money.localeTag = 'fr';
    // fr uses narrow no-break space as the grouping separator.
    expect(
      Money.fromMajor(1240.50, Currency.usd)
          .text
          .replaceAll('\u202F', ' ')
          .replaceAll('\u00A0', ' '),
      'US\$ 1 240,50',
    );
    Money.localeTag = 'pt';
    expect(Money.fromMajor(1240.50, Currency.usd).text, 'US\$ 1.240,50');
    // Untranslated locales fall back to the en grouping.
    Money.localeTag = 'sn';
    expect(Money.fromMajor(1240.50, Currency.usd).text, 'US\$ 1,240.50');
    Money.localeTag = null;
  });
  test('Interface pass 3: refresh() re-hydrates and preserves settings',
      () async {
    final s = await fresh();
    s.setHideAmounts(true);
    s.setThemeMode(2);
    await s.refresh();
    expect(s.hideAmounts, isTrue);
    expect(s.themeMode, 2);
    expect(s.hydrating, isFalse);
    expect(s.lastError, isNull);
  });

  test('Interface pass 3: circle collect is undoable (records only)',
      () async {
    final s = await fresh();
    final before = s.circle.currentRound;
    s.circleCollect();
    expect(s.circle.currentRound, before + 1);
    s.undoCircleCollect();
    expect(s.circle.currentRound, before);
  });

  test('Interface pass 3: chore confirm is undoable (stars returned)',
      () async {
    final s = await fresh();
    final chore = s.chores.firstWhere((c) => c.state == ChoreState.confirmed);
    final starsBefore = s.stars;
    s.unconfirmChore(chore);
    expect(chore.state, ChoreState.waiting);
    expect(s.stars, starsBefore - chore.stars);
  });

  // ── Premium pass: sync-scope completion (chore / mukando / recurring) ────
  const ctx = SyncCtx(spaceId: 'sp1', newId: _nid);

  test('recurring adapter round-trip preserves rule', () {
    final r = RecurringRule(
      id: 'rc1',
      name: 'School fees',
      emoji: '🎓',
      amount: Money(2500, Currency.usd),
      memberId: 'm1',
      method: Method.bankTransfer,
      frequency: Frequency.term,
      nextDue: DateTime(2026, 2, 1),
    );
    final row = kSyncAdapters['recurring']!.encode(r, ctx);
    final r2 = kSyncAdapters['recurring']!.decode(row) as RecurringRule;
    expect(r2.id, 'rc1');
    expect(r2.name, 'School fees');
    expect(r2.amount.minor, 2500);
    expect(r2.amount.currency, Currency.usd);
    expect(r2.method, Method.bankTransfer);
    expect(r2.frequency, Frequency.term);
    expect(r2.active, isTrue);
  });

  test('chore adapter round-trip preserves state and stars', () {
    final c = Chore(id: 'ch1', name: 'Dishes', stars: 3, state: ChoreState.waiting);
    final row = kSyncAdapters['chore']!.encode(c, ctx);
    final c2 = kSyncAdapters['chore']!.decode(row) as Chore;
    expect(c2.id, 'ch1');
    expect(c2.name, 'Dishes');
    expect(c2.stars, 3);
    expect(c2.state, ChoreState.waiting);
  });

  test('mukando adapter uses a deterministic per-space id', () {
    final circle = SavingsCircle(
      name: 'Mukando',
      contribution: Money(2000, Currency.zwg),
      totalRounds: 6,
      currentRound: 2,
      order: const ['Mai', 'Baba', 'Sekuru', 'Gogo', 'Zoe', 'Tapiwa'],
    );
    final row = kSyncAdapters['mukando']!.encode(circle, ctx);
    expect(row['id'], uuidFromSeed('mukando/sp1'));
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(row['id'] as String), isTrue);
    final c2 = kSyncAdapters['mukando']!.decode(row) as SavingsCircle;
    expect(c2.totalRounds, 6);
    expect(c2.currentRound, 2);
    expect(c2.order, circle.order);
    expect(c2.contribution.currency, Currency.zwg);
  });

  test('every synced entity has exactly one pull slot', () {
    for (final k in kSyncAdapters.keys) {
      expect(kPullOrder.contains(k), isTrue, reason: '$k missing from kPullOrder');
    }
    expect(kPullOrder.length, kSyncAdapters.length);
  });

  test('uuid helpers produce well-formed, unique, deterministic ids', () {
    final a = newUuid();
    final b = newUuid();
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
          .hasMatch(a),
      isTrue,
      reason: 'v4 shape',
    );
    expect(a, isNot(b));
    expect(uuidFromSeed('mukando/sp1'), uuidFromSeed('mukando/sp1'));
    expect(uuidFromSeed('mukando/sp2'), isNot(uuidFromSeed('mukando/sp1')));
  });

  test('settings: custom rate, display currency and auto-hide persist', () async {
    final state = AppState(db: db);
    await state.ready();
    state.setCustomRate(16.4);
    state.setDisplayCurrency(Currency.zwg);
    state.setAutoHideAmounts(false);
    await state.flushWrites();

    final second = AppState(db: db);
    await second.ready();
    expect(second.rate, 16.4);
    expect(second.displayCurrency, Currency.zwg);
    expect(second.autoHideAmounts, isFalse);
    // clamping guard
    state.setCustomRate(0);
    expect(state.rate, greaterThan(0));
  });
}

String _nid() => 'n1';
