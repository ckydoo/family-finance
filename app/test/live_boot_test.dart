import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/auth/auth_service.dart';
import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mhuri_money/core/db/app_database.dart';

/// REAL-DATA GUARANTEE (live mode): a fresh install boots EMPTY — no seeded
/// demo family, no fiction. Identity is bootstrapped only by adopting a
/// family space (create/join). Demo mode keeps its fixtures for tests.
///
/// Sprint A: the local owner's id IS the server identity (auth.users id), so
/// pushed rows satisfy their user_profile FKs, and the family roster can be
/// pulled and merged with real names.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<(AppState, AuthController)> liveState() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async => await AppDatabase.createSchema(d),
    );
    final env = AppEnv.parse(
      'APP_ENV=live\n'
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=k\n',
    );
    final auth = AuthController(env: env, service: DemoAuthService())
      ..signIn('tendi@mhuri.app', '123456');
    final s = AppState(db: AppDatabase.wrap(raw), env: env, auth: auth);
    await s.ready();
    return (s, auth);
  }

  /// Same as [liveState] but also returns the raw database so tests can
  /// assert what was actually persisted (kv, tx rows).
  Future<(AppState, AuthController, Database)> liveStateRaw() async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async => await AppDatabase.createSchema(d),
    );
    final env = AppEnv.parse(
      'APP_ENV=live\n'
      'SUPABASE_URL=https://abcdefgh.supabase.co\n'
      'SUPABASE_ANON_KEY=k\n',
    );
    final auth = AuthController(env: env, service: DemoAuthService())
      ..signIn('tendi@mhuri.app', '123456');
    final s = AppState(db: AppDatabase.wrap(raw), env: env, auth: auth);
    await s.ready();
    return (s, auth, raw);
  }

  test('live fresh boot contains ZERO demo data', () async {
    final (s, _) = await liveState();

    // No demo family, no demo members, no demo content.
    expect(s.space.name, isNot(contains('Taylor')));
    expect(s.members, isEmpty);
    expect(s.envelopes, isEmpty);
    expect(s.txs, isEmpty);
    expect(s.goals, isEmpty);
    expect(s.items, isEmpty);
    expect(s.chores, isEmpty);
    expect(s.requests, isEmpty);
    expect(s.stars, 0);
    final dump = '${s.space.name} ${s.circle.name}';
    expect(dump.contains('Marufu'), isFalse);
  });

  test('adopting a space bootstraps the owner with the SERVER identity id',
      () async {
    final (s, auth) = await liveState();
    final session = await auth.restoreSession();
    expect(session, isNotNull);

    s.onSpaceAdopted(spaceName: 'The Marufu Family');

    expect(s.space.name, 'The Marufu Family');
    expect(s.members, hasLength(1));
    final me = s.members.single;
    expect(me.role.name, 'owner');
    expect(me.name, 'tendi'); // email prefix
    // Sprint A keystone: local owner id == auth session id, which exists as
    // a user_profile row server-side → FKs on pushed rows are satisfied.
    expect(me.id, session!.userId);
    expect(s.user.id, session.userId);
  });

  test('membersFromServer maps roster rows (roles, names, me-first)',
      () async {
    final (s, _) = await liveState();
    s.onSpaceAdopted(spaceName: 'Marufu');
    final meId = s.user.id;

    final roster = membersFromServer(
      membershipRows: [
        {'space_id': 'sp', 'user_id': meId, 'role': 'owner'},
        {
          'space_id': 'sp',
          'user_id': 'uuid-mai',
          'role': 'co_parent',
        },
        {'space_id': 'sp', 'user_id': 'uuid-zoe', 'role': 'kid'},
      ],
      profileRows: [
        {'id': meId, 'name': 'Member', 'email': 'tendi@mhuri.app'},
        {'id': 'uuid-mai', 'name': 'Mai', 'email': 'mai@mhuri.app'},
        {'id': 'uuid-zoe', 'name': 'Zoe', 'email': 'zoe@mhuri.app'},
      ],
      meId: meId,
    );

    expect(roster.first.id, meId); // me first
    expect(roster, hasLength(3));
    final mai = roster.firstWhere((m) => m.id == 'uuid-mai');
    expect(mai.role, Role.adult); // co_parent maps to adult
    expect(mai.name, 'Mai');
    expect(roster.firstWhere((m) => m.id == 'uuid-zoe').role, Role.kid);
  });

  test('setFamilyMembers merges the roster; local identity kept for me',
      () async {
    final (s, _) = await liveState();
    s.onSpaceAdopted(spaceName: 'Marufu');
    final meId = s.user.id;

    // Server still says 'Member' for me (003/SQL rename not yet applied).
    await s.setFamilyMembers([
      Member(id: meId, name: 'Member', emoji: 'person', role: Role.owner),
      Member(id: 'uuid-mai', name: 'Mai', emoji: 'person', role: Role.adult),
    ]);

    expect(s.members, hasLength(2));
    expect(s.user.id, meId); // binding survives the merge
    expect(s.user.name, 'tendi'); // local display name kept
    expect(s.members.any((m) => m.id == 'uuid-mai' && m.name == 'Mai'),
        isTrue);
  });

  test('demo mode keeps its fixtures (tests + demo builds)', () async {
    final s = AppState(); // no db, demo env
    expect(s.members, isNotEmpty);
    expect(s.envelopes, isNotEmpty);
  });

  test('applyEnvelopeLinks mirrors server links, persists, skips no-ops',
      () async {
    final (s, _, raw) = await liveStateRaw();

    // tx_keep already points at env-a (server agrees → untouched);
    // tx_link is unlinked (server says env-b → rewritten + persisted).
    final ts = DateTime.now();
    s.txs = [
      Tx(
        id: 'tx_keep',
        envelopeId: 'env-a',
        memberId: 'mem1',
        type: TxType.expense,
        amount: const Money(2500, Currency.usd),
        method: Method.cash,
        note: 'groceries',
        when: ts,
      ),
      Tx(
        id: 'tx_link',
        memberId: 'mem1',
        type: TxType.expense,
        amount: const Money(900, Currency.zwg),
        method: Method.mobileMoney,
        note: 'fare',
        when: ts,
      ),
    ];

    // 'tx_ghost' is unknown locally → ignored (device-only mirror).
    await s.applyEnvelopeLinks(
        {'tx_link': 'env-b', 'tx_keep': 'env-a', 'tx_ghost': 'env-x'});

    expect(s.txs.firstWhere((t) => t.id == 'tx_link').envelopeId, 'env-b');
    expect(s.txs.firstWhere((t) => t.id == 'tx_keep').envelopeId, 'env-a');
    final row = (await raw.query('tx', where: 'id = ?', whereArgs: ['tx_link'])).single;
    expect(row['envelope_id'], 'env-b'); // persisted for next boot
    expect(await raw.query('tx', where: 'id = ?', whereArgs: ['tx_ghost']),
        isEmpty);
  });

  test('server FX fills the gap; a custom user rate wins', () async {
    final (s, _, raw) = await liveStateRaw();
    expect(s.rate, 15.27); // boot default

    await s.applyServerRate(15.95);
    expect(s.rate, 15.95);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final kv = (await raw.query('kv', where: 'k = ?', whereArgs: ['server_rate'])).single;
    expect(kv['v'], '15.9500'); // hydrated at next boot

    s.setCustomRate(16.4);
    await s.applyServerRate(17.25); // must NOT override the user
    expect(s.rate, 16.4);
  });

  test('skip-for-now recovery: reopenFamilySetup re-arms the setup flow',
      () async {
    final (s, _, raw) = await liveStateRaw();
    s.completeOnboarding();
    expect(s.onboardingComplete, isTrue);

    s.reopenFamilySetup();
    expect(s.onboardingComplete, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final kv = (await raw.query('kv', where: 'k = ?', whereArgs: ['onboarding_done'])).single;
    expect(kv['v'], '0'); // banner path can flip it back on
  });
}
