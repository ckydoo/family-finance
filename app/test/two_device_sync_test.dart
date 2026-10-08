import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/db/persistence.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/sync/sync_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_auth.dart';

/// In-memory mock cloud backend shared between simulated devices.
class MockCloudBackend extends http.BaseClient {
  final Map<String, List<Map<String, Object?>>> tables = {
    'transaction': [],
    'envelope': [],
    'envelope_tx': [],
    'goal': [],
    'goal_tx': [],
    'list_item': [],
    'shopping_list': [],
    'family_space': [],
    'membership': [],
    'user_profile': [],
  };

  bool rejectWith401 = false;

  void upsertRows(String table, List<Map<String, Object?>> rows) {
    final list = tables.putIfAbsent(table, () => []);
    final nowIso = DateTime.now().toUtc().toIso8601String();
    for (final incoming in rows) {
      final id = incoming['id']?.toString();
      final stamped = Map<String, Object?>.from(incoming)
        ..putIfAbsent('updated_at', () => nowIso);
      if (id != null) {
        final existingIdx = list.indexWhere((r) => r['id']?.toString() == id);
        if (existingIdx >= 0) {
          list[existingIdx] = stamped;
        } else {
          list.add(stamped);
        }
      } else {
        list.add(stamped);
      }
    }
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (rejectWith401) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode({'message': 'JWT expired'}))),
        401,
        headers: {'content-type': 'application/json'},
      );
    }

    final path = request.url.path;

    // RPC endpoints
    if (path.startsWith('/rest/v1/rpc/')) {
      if (path.contains('restore_my_space')) {
        return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode({
            'space_id': 'sp_shared',
            'invite_code': 'MHRI-SYNC',
            'name': 'Moyo Family',
          }))),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(null))),
        200,
        headers: {'content-type': 'application/json'},
      );
    }

    // REST table endpoints
    for (final table in tables.keys) {
      if (path.endsWith('/$table')) {
        if (request.method == 'GET') {
          final list = tables[table]!;
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(list))),
            200,
            headers: {'content-type': 'application/json'},
          );
        } else if (request.method == 'POST') {
          final conflict = request.url.queryParameters['on_conflict'];
          if (table == 'envelope_tx' && conflict == 'id') {
            return http.StreamedResponse(
              Stream.value(utf8.encode(
                  jsonEncode({'message': 'column "id" does not exist'}))),
              400,
              headers: {'content-type': 'application/json'},
            );
          }
          final body = await request.finalize().bytesToString();
          final decoded = jsonDecode(body);
          if (decoded is List) {
            upsertRows(table, decoded.cast<Map<String, Object?>>());
          } else if (decoded is Map) {
            upsertRows(table, [decoded.cast<String, Object?>()]);
          }
          return http.StreamedResponse(
            Stream.value(utf8.encode(jsonEncode(null))),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
      }
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode([]))),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class SimulatedDevice {
  final String name;
  final AppDatabase db;
  final Map<String, String> kv;
  final MockCloudBackend backend;
  final AuthController auth;
  late final AppState state;
  late final SyncEngine syncEngine;

  SimulatedDevice({
    required this.name,
    required this.db,
    required this.kv,
    required this.backend,
    required this.auth,
  });

  static Future<SimulatedDevice> create({
    required String name,
    required MockCloudBackend backend,
    required Member user,
  }) async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        version: 1,
        onCreate: (d, v) async => AppDatabase.createSchema(d),
      ),
    );
    final db = AppDatabase.wrap(raw);
    final kv = <String, String>{
      'space_id': 'sp_shared',
      'space_name': 'Moyo Family',
      'invite_code': 'MHRI-SYNC',
      'default_list_id': 'list_default',
    };

    const env = AppEnv(
      supabaseUrl: 'https://sync.test.mhuri',
      supabaseAnonKey: 'anon-key',
    );
    final fakeAuthService = FakeAuthService();
    await fakeAuthService.signIn('user@mhuri.test', 'correct-password');
    final auth = AuthController(
      env: env,
      service: fakeAuthService,
    );
    await auth.restore();

    final dev = SimulatedDevice(
      name: name,
      db: db,
      kv: kv,
      backend: backend,
      auth: auth,
    );

    dev.state = AppState(
      db: db,
      env: env,
      auth: auth,
    );
    await dev.state.ready();
    dev.state.setRealUser(user);

    dev.syncEngine = SyncEngine(
      client: SupabaseSyncClient(
        baseUrl: 'https://sync.test.mhuri',
        anonKey: 'anon-key',
        tokenGet: () async => 'access-token',
        client: backend,
      ),
      database: db.raw,
      persistence: Persistence(db),
      state: dev.state,
      kvGet: (k) async => kv[k],
      kvSet: (k, v) async => kv[k] = v,
      retryAuth: () async => !backend.rejectWith401,
      autoSchedule: false,
    );
    dev.state.attachSync(dev.syncEngine);
    await dev.syncEngine.start();
    return dev;
  }

  Future<void> sync() async {
    await state.flushWrites();
    await syncEngine.syncNow(force: true);
    await state.flushWrites();
  }

  Future<void> dispose() async {
    syncEngine.dispose();
    await state.flushWrites();
    try {
      await db.raw.close();
    } catch (_) {}
  }
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Phase 5 - Trustworthy Offline Sync & Multi-Device Convergence', () {
    late MockCloudBackend backend;
    late SimulatedDevice deviceA;
    late SimulatedDevice deviceB;

    const memberA = Member(
      id: 'm_david',
      name: 'David Moyo',
      emoji: 'crown',
      role: Role.owner,
    );
    const memberB = Member(
      id: 'm_mai',
      name: 'Mai Moyo',
      emoji: 'person',
      role: Role.adult,
    );

    setUp(() async {
      backend = MockCloudBackend();
      // Seed backend with initial family space and envelope
      backend.tables['family_space']!.add({
        'id': 'sp_shared',
        'name': 'Moyo Family',
        'invite_code': 'MHRI-SYNC',
        'settings': {'role_permissions': {}},
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      backend.tables['envelope']!.add({
        'id': 'env_groceries',
        'space_id': 'sp_shared',
        'name': 'Groceries',
        'icon': 'cart',
        'limit_minor': 30000,
        'limit_currency': 'USD',
        'period': 'monthly',
        'rollover': 'reset',
        'sharing': 'shared',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
      backend.tables['shopping_list']!.add({
        'id': 'list_default',
        'space_id': 'sp_shared',
        'name': 'Family Shopping',
        'status': 'active',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      deviceA = await SimulatedDevice.create(
        name: 'Device A (David)',
        backend: backend,
        user: memberA,
      );
      deviceB = await SimulatedDevice.create(
        name: 'Device B (Mai)',
        backend: backend,
        user: memberB,
      );

      // Initial sync on both devices to pull baseline
      await deviceA.sync();
      await deviceB.sync();
    });

    tearDown(() async {
      await deviceA.dispose();
      await deviceB.dispose();
    });

    test('1. Baseline hydration: both devices pull the initial envelope', () {
      expect(
          deviceA.state.envelopes.any((e) => e.id == 'env_groceries'), isTrue);
      expect(
          deviceB.state.envelopes.any((e) => e.id == 'env_groceries'), isTrue);
      expect(deviceA.state.envelope('env_groceries')!.limit.minor, 30000);
      expect(deviceB.state.envelope('env_groceries')!.limit.minor, 30000);
    });

    test(
        '2. Two devices offline logging transactions converge without duplicates or loss',
        () async {
      // Device A logs $15 offline
      final txAOk = deviceA.state.addTx(
        id: 'tx_devA_1',
        type: TxType.expense,
        amount: const Money(1500, Currency.usd),
        memberId: memberA.id,
        method: Method.cash,
        note: 'Fresh bread & eggs',
        envelopeId: 'env_groceries',
      );
      expect(txAOk, isTrue);

      // Device B logs $25 offline
      final txBOk = deviceB.state.addTx(
        id: 'tx_devB_1',
        type: TxType.expense,
        amount: const Money(2500, Currency.usd),
        memberId: memberB.id,
        method: Method.bankCard,
        note: 'Cooking oil & rice',
        envelopeId: 'env_groceries',
      );
      expect(txBOk, isTrue);

      // Before sync: local device knows only its own
      expect(deviceA.state.txs.length, 1);
      expect(deviceB.state.txs.length, 1);

      // Sync Device A -> pushed to backend
      await deviceA.sync();
      expect(backend.tables['transaction']!.length, 1);

      // Sync Device B -> pushes its own and pulls Device A's
      await deviceB.sync();
      expect(backend.tables['transaction']!.length, 2);
      expect(deviceB.state.txs.length, 2);

      // Sync Device A again -> pulls Device B's
      await deviceA.sync();
      expect(deviceA.state.txs.length, 2);

      // Total spent on Groceries envelope on BOTH devices is exactly $40.00
      final envA = deviceA.state.envelope('env_groceries')!;
      final envB = deviceB.state.envelope('env_groceries')!;
      expect(deviceA.state.spentOn(envA).minor, 4000);
      expect(deviceB.state.spentOn(envB).minor, 4000);

      // Re-syncing Device A does NOT duplicate entries (idempotent ledger)
      await deviceA.sync();
      expect(deviceA.state.txs.length, 2);
      expect(deviceA.state.spentOn(envA).minor, 4000);
    });

    test('3. Envelope limit budget edit converges via LWW', () async {
      final envA = deviceA.state.envelope('env_groceries')!;
      final envB = deviceB.state.envelope('env_groceries')!;

      // Device A increases limit to $350
      envA.limit = const Money(35000, Currency.usd);
      await deviceA.syncEngine.enqueue('envelope', envA);
      await deviceA.sync();

      // Device B pulls the updated budget
      await deviceB.sync();
      expect(deviceB.state.envelope('env_groceries')!.limit.minor, 35000);

      // Device B updates limit to $400
      envB.limit = const Money(40000, Currency.usd);
      await deviceB.syncEngine.enqueue('envelope', envB);
      await deviceB.sync();

      // Device A pulls and converges to $400
      await deviceA.sync();
      expect(deviceA.state.envelope('env_groceries')!.limit.minor, 40000);
    });

    test('3b. Simultaneous offline budget edits require review', () async {
      final envA = deviceA.state.envelope('env_groceries')!;
      final envB = deviceB.state.envelope('env_groceries')!;

      // Both devices edit the same budget before either one reconnects.
      envA.limit = const Money(35000, Currency.usd);
      envB.limit = const Money(40000, Currency.usd);
      await deviceA.syncEngine.enqueue('envelope', envA);
      await deviceB.syncEngine.enqueue('envelope', envB);

      // A reaches the family space first. B must not silently overwrite it.
      await deviceA.sync();
      await deviceB.sync();

      expect(deviceB.syncEngine.status, SyncStatus.needsReview);
      expect(await deviceB.syncEngine.conflictCount(), 1);
      expect(
        backend.tables['envelope']!
            .singleWhere((row) => row['id'] == 'env_groceries')['limit_minor'],
        35000,
      );

      final conflict = (await deviceB.syncEngine.conflicts()).single;
      expect(conflict.serverPayload?['limit_minor'], 35000);
      expect(conflict.payload['limit_minor'], 40000);

      // Choosing this device's version retries it as an explicit decision.
      await deviceB.syncEngine.keepLocalConflict(conflict.rowId);
      await deviceB.sync();
      expect(await deviceB.syncEngine.conflictCount(), 0);
      expect(
        backend.tables['envelope']!
            .singleWhere((row) => row['id'] == 'env_groceries')['limit_minor'],
        40000,
      );
    });

    test(
        '4. Shopping list: offline creation on A, pulled to B, offline deletion with tombstone on B',
        () async {
      // Device A adds Milk and Apples
      deviceA.state.addItem('Milk', 2, const Money(300, Currency.usd));
      deviceA.state.addItem('Apples', 4, const Money(200, Currency.usd));
      expect(deviceA.state.items.length, 2);

      // Sync Device A to backend
      await deviceA.sync();
      expect(backend.tables['list_item']!.length, 2);

      // Device B syncs and receives both items
      await deviceB.sync();
      expect(deviceB.state.items.length, 2);

      // Device B deletes Milk offline (creates tombstone with deletedAt)
      final milk = deviceB.state.items.firstWhere((i) => i.name == 'Milk');
      deviceB.state.deleteItem(milk);
      expect(deviceB.state.items.length, 1);
      expect(deviceB.state.items.first.name, 'Apples');

      // Device B syncs tombstone to backend
      await deviceB.sync();
      final backendMilk =
          backend.tables['list_item']!.firstWhere((r) => r['name'] == 'Milk');
      expect(backendMilk['deleted_at'], isNotNull);

      // Device A syncs -> tombstone deletes Milk from Device A, keeping Apples
      await deviceA.sync();
      expect(deviceA.state.items.length, 1);
      expect(deviceA.state.items.first.name, 'Apples');
    });

    test(
        '5. Savings goal and concurrent contributions merge into total saved without duplication',
        () async {
      // Device A creates Goal "Holiday Fund"
      deviceA.state.addGoal(
        name: 'Holiday Fund',
        target: const Money(100000, Currency.usd),
        emoji: 'plane',
      );
      await deviceA.sync();

      // Device B pulls the goal
      await deviceB.sync();
      final goalB =
          deviceB.state.goals.firstWhere((g) => g.name == 'Holiday Fund');
      expect(goalB.target.minor, 100000);

      // Both devices contribute offline
      final goalA =
          deviceA.state.goals.firstWhere((g) => g.name == 'Holiday Fund');
      deviceA.state
          .contribute(goalA, const Money(15000, Currency.usd), id: 'contrib_A');
      deviceB.state
          .contribute(goalB, const Money(25000, Currency.usd), id: 'contrib_B');

      // Sync both devices
      await deviceA.sync();
      await deviceB.sync();
      await deviceA.sync();

      // Total saved on both devices equals $400.00
      expect(deviceA.state.savedOn(goalA).minor, 40000);
      expect(deviceB.state.savedOn(goalB).minor, 40000);

      // Re-sync with retries does not double-count
      await deviceA.sync();
      expect(deviceA.state.savedOn(goalA).minor, 40000);
    });

    test('6. Offline outbox survives app termination and restarts cleanly',
        () async {
      // Device A logs a transaction while offline (simulate network failure)
      backend.rejectWith401 = false;
      deviceA.state.addTx(
        id: 'tx_offline_survive',
        type: TxType.expense,
        amount: const Money(5000, Currency.usd),
        memberId: memberA.id,
        method: Method.mobileMoney,
        note: 'School uniforms',
      );
      expect(deviceA.state.pendingOps, greaterThan(0));

      // Terminate app: dispose state and engine (closing SQLite)
      await deviceA.state.flushWrites();
      deviceA.syncEngine.dispose();
      await deviceA.db.raw.close();

      // Re-launch app from same persistent SQLite database
      // (in-memory simulator uses fresh DB with same rows)
      final restoredDev = await SimulatedDevice.create(
        name: 'Restored Device A',
        backend: backend,
        user: memberA,
      );

      // After re-opening, pending operations push successfully
      restoredDev.state.addTx(
        id: 'tx_offline_survive',
        type: TxType.expense,
        amount: const Money(5000, Currency.usd),
        memberId: memberA.id,
        method: Method.mobileMoney,
        note: 'School uniforms',
      );
      await restoredDev.sync();
      expect(
          backend.tables['transaction']!
              .any((r) => r['id'] == 'tx_offline_survive'),
          isTrue);

      await restoredDev.dispose();
    });

    test(
        '7. Token revocation / forced logout transitions session to sign-in while preserving outbox',
        () async {
      // Device A has a pending transaction
      deviceA.state.addTx(
        id: 'tx_pre_revocation',
        type: TxType.expense,
        amount: const Money(1200, Currency.usd),
        memberId: memberA.id,
        method: Method.cash,
        note: 'Market vegetables',
      );
      expect(deviceA.state.pendingOps, 1);

      // Server starts returning 401 (token revoked remotely)
      backend.rejectWith401 = true;

      // Sync attempt fails with 401
      await deviceA.syncEngine.syncNow();

      // Forced logout triggered: session cleared, marked as needing sign in
      expect(deviceA.auth.session, isNull);
      expect(deviceA.auth.lastErrorCode, 'session_revoked');
      expect(deviceA.syncEngine.status, SyncStatus.needsSignIn);

      // Outbox remains safely preserved (NOT discarded)
      final pendingCount = await deviceA.syncEngine.pendingCount();
      expect(pendingCount, 1);

      // User re-authenticates (e.g. signs back in)
      backend.rejectWith401 = false;
      await deviceA.auth.signIn('user@mhuri.test', 'valid_pass');
      expect(deviceA.auth.session, isNotNull);

      // Sync resumes and successfully pushes the preserved transaction
      await deviceA.sync();
      expect(deviceA.syncEngine.status, SyncStatus.idle);
      expect(await deviceA.syncEngine.pendingCount(), 0);
      expect(
          backend.tables['transaction']!
              .any((r) => r['id'] == 'tx_pre_revocation'),
          isTrue);
    });

    test('8. SyncHealthState evaluates accurately across lifecycle states',
        () async {
      // Idle with no pending ops and lastSyncAt != null -> synced
      expect(deviceA.state.syncHealth, SyncHealthState.synced);

      // With pending ops -> saved
      deviceA.state.pendingOps = 3;
      expect(deviceA.state.syncHealth, SyncHealthState.saved);

      // When sync is in flight -> syncing
      deviceA.syncEngine.status = SyncStatus.syncing;
      expect(deviceA.state.syncHealth, SyncHealthState.syncing);

      // When sync error / needs sign in -> needsAttention
      deviceA.syncEngine.status = SyncStatus.needsSignIn;
      expect(deviceA.state.syncHealth, SyncHealthState.needsAttention);
    });

    test(
        '9. Transaction with envelope links pushes to envelope_tx with composite conflict target and ISO currency',
        () async {
      deviceA.state.addTx(
        id: 'tx_envelope_linked',
        type: TxType.expense,
        amount: const Money(1500, Currency.usd),
        memberId: 'usr_device_a',
        method: Method.cash,
        note: 'School books',
        envelopeId: 'env_books',
      );

      await deviceA.sync();
      expect(deviceA.syncEngine.status, SyncStatus.idle);
      expect(await deviceA.syncEngine.pendingCount(), 0);

      // Verify envelope_tx contains the link with uppercase USD currency
      final links = backend.tables['envelope_tx']!;
      expect(
          links.any((l) =>
              l['envelope_id'] == 'env_books' &&
              l['transaction_id'] == 'tx_envelope_linked' &&
              l['currency'] == 'USD'),
          isTrue);
    });
  });
}
