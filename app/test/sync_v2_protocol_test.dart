import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mhuri_money/core/auth/auth_controller.dart';
import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/db/persistence.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/outbox.dart';
import 'package:mhuri_money/core/sync/realtime_sync_signal.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/sync/sync_engine.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_auth.dart';

/// In-memory Sync Protocol v2 mock server simulating `push_sync_ops` and
/// `pull_family_changes` with monotonic `sync_seq`, `sync_applied_op`
/// idempotency, 3-way merge, `envelope_tx` inline projection, and natural-key
/// collision adoption (`adopted_existing`).
class MockSyncV2Server extends http.BaseClient {
  int _seq = 100;
  bool disableV2Rpcs = false;

  final Map<String, Map<String, Object?>> appliedOps = {};
  final Map<String, List<Map<String, Object?>>> tables = {
    for (final adapter in kSyncAdapters.values) adapter.table: [],
    'envelope_tx': [],
    'family_space': [],
    'membership': [],
    'user_profile': [],
    'rate_snapshot': [],
  };
  final List<List<String>> pushedTableBatches = [];

  int nextSeq() => ++_seq;

  static final Map<String, String> _tableToEntity = {
    for (final entry in kSyncAdapters.entries) entry.value.table: entry.key,
  };

  void seedSpace({
    required String spaceId,
    required String name,
    required List<Member> members,
  }) {
    tables['family_space'] = [
      {
        'id': spaceId,
        'name': name,
        'base_currency': 'USD',
        'month_start_day': 1,
        'sync_seq': nextSeq(),
        'settings': {'onboarding_stage': 'complete'},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      },
    ];
    tables['shopping_list'] = [
      {
        'id': 'list_default',
        'space_id': spaceId,
        'name': 'Weekly',
        'status': 'active',
        'sync_seq': nextSeq(),
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      },
    ];
    tables['membership'] = [
      for (final m in members)
        {
          'space_id': spaceId,
          'user_id': m.id,
          'role': m.role == Role.admin ? 'co_parent' : m.role.name,
          'invite_status': 'active',
        },
    ];
    tables['user_profile'] = [
      for (final m in members)
        {
          'id': m.id,
          'name': m.name,
          'email': '${m.id}@mhuri.test',
        },
    ];
  }

  Map<String, Object?> _decorateTx(Map<String, Object?> row) {
    final txId = row['id']?.toString();
    final link = tables['envelope_tx']!
        .where((l) => l['transaction_id']?.toString() == txId)
        .firstOrNull;
    return {
      ...row,
      '_has_envelope_link': true,
      '_envelope_id': link?['envelope_id'],
    };
  }

  static const List<String> _remappableFields = [
    'id',
    'account_id',
    'envelope_id',
    '_envelope_id',
    'goal_id',
    'list_id',
    'recurring_rule_id',
    'commitment_id',
    'occurrence_id',
    'campaign_id',
    'pledge_id',
    'debt_id',
    'settled_tx_id',
    'transaction_id',
  ];

  Map<String, Object?> _remapPayloadIds(
    Map<String, Object?> src,
    Map<String, String> idRemap,
  ) {
    if (idRemap.isEmpty) return src;
    final out = Map<String, Object?>.from(src);
    for (final field in _remappableFields) {
      final v = out[field];
      if (v is String && idRemap.containsKey(v)) {
        out[field] = idRemap[v];
      }
    }
    final alloc = out['allocations'];
    if (alloc is Map) {
      final mappedAlloc = <String, Object?>{};
      for (final e in alloc.entries) {
        final k = e.key.toString();
        final mappedKey = idRemap[k] ?? k;
        final prev = mappedAlloc[mappedKey];
        if (prev is num && e.value is num) {
          mappedAlloc[mappedKey] = prev + (e.value as num);
        } else {
          mappedAlloc[mappedKey] = e.value;
        }
      }
      out['allocations'] = mappedAlloc;
    }
    return out;
  }

  Map<String, Object?> _applyOp(
    Map<String, Object?> rawOp,
    Map<String, String> idRemap,
  ) {
    final opId = rawOp['op_id']?.toString() ?? '';
    if (opId.isNotEmpty && appliedOps.containsKey(opId)) {
      return appliedOps[opId]!;
    }

    final table = rawOp['table']?.toString() ?? '';
    final spaceId = rawOp['space_id']?.toString() ?? '';
    final payload = _remapPayloadIds(
      Map<String, Object?>.from((rawOp['payload'] as Map?) ?? const {}),
      idRemap,
    );
    final hasEnvFlag = payload.remove('_has_envelope_link') == true;
    final envId = payload.remove('_envelope_id')?.toString();
    var rowId = (rawOp['id'] ?? payload['id'])?.toString() ?? '';
    if (idRemap.containsKey(rowId)) {
      rowId = idRemap[rowId]!;
    }
    final baseUpdatedAt = rawOp['base_updated_at']?.toString();
    final baseMap = rawOp['base'] is Map
        ? _remapPayloadIds(
            Map<String, Object?>.from(rawOp['base'] as Map),
            idRemap,
          )
        : null;

    final rows = tables.putIfAbsent(table, () => []);
    final existingIdx = rows.indexWhere((r) => '${r['id']}' == rowId);
    final nowIso = DateTime.utc(2026, 11, 25, 12, 0, nextSeq()).toIso8601String();
    final seq = _seq;

    // Natural-key collision check on active shared envelopes:
    // `(space_id, lower(btrim(name))) WHERE sharing = 'shared' AND is_archived = false`
    if (table == 'envelope' && existingIdx < 0) {
      final sharing = (payload['sharing'] ?? 'shared').toString();
      final nameNorm = (payload['name'] ?? '').toString().trim().toLowerCase();
      final nkIdx = rows.indexWhere((r) =>
          r['space_id'] == spaceId &&
          (r['sharing'] ?? 'shared') == sharing &&
          r['is_archived'] != true &&
          (r['name'] ?? '').toString().trim().toLowerCase() == nameNorm);
      if (nkIdx >= 0 && sharing == 'shared') {
        final existing = Map<String, Object?>.from(rows[nkIdx]);
        existing['sync_seq'] = seq;
        existing['updated_at'] = nowIso;
        rows[nkIdx] = existing;
        final res = <String, Object?>{
          'op_id': opId,
          'status': 'applied',
          'outcome': 'adopted_existing',
          'replaced_id': rowId,
          'sync_seq': seq,
          'row': existing,
        };
        if (opId.isNotEmpty) appliedOps[opId] = res;
        return res;
      }
    }

    Map<String, Object?> stored;
    var outcome = 'inserted';
    if (existingIdx < 0) {
      stored = {
        ...payload,
        'id': rowId,
        'updated_at': nowIso,
        'sync_seq': seq,
      };
      rows.add(stored);
    } else {
      final current = rows[existingIdx];
      final currentUa = current['updated_at']?.toString();
      if (baseUpdatedAt != null &&
          baseUpdatedAt == currentUa) {
        outcome = 'updated';
        stored = {
          ...current,
          ...payload,
          'id': rowId,
          'updated_at': nowIso,
          'sync_seq': seq,
        };
      } else if (baseMap != null) {
        outcome = 'merged';
        final merged = Map<String, Object?>.from(current);
        for (final entry in payload.entries) {
          final k = entry.key;
          if (k == 'id' || k == 'space_id' || k == 'updated_at' || k == 'sync_seq') {
            continue;
          }
          if ('${baseMap[k] ?? ''}' != '${entry.value ?? ''}') {
            merged[k] = entry.value;
          }
        }
        merged['updated_at'] = nowIso;
        merged['sync_seq'] = seq;
        stored = merged;
      } else {
        outcome = 'updated';
        stored = {
          ...current,
          ...payload,
          'id': rowId,
          'updated_at': nowIso,
          'sync_seq': seq,
        };
      }
      rows[existingIdx] = stored;
    }

    if (table == 'transaction') {
      if (hasEnvFlag || payload['account_id'] != null) {
        tables['envelope_tx']!
            .removeWhere((l) => l['transaction_id']?.toString() == rowId);
        if (payload['account_id'] == null &&
            envId != null &&
            envId.isNotEmpty) {
          tables['envelope_tx']!.add({
            'envelope_id': envId,
            'transaction_id': rowId,
            'allocated_minor': stored['amount_minor'] ?? 0,
            'currency': stored['currency'] ?? 'USD',
          });
        }
      }
      stored = _decorateTx(stored);
    }

    final result = <String, Object?>{
      'op_id': opId,
      'status': 'applied',
      'outcome': outcome,
      'sync_seq': seq,
      'row': stored,
    };
    if (opId.isNotEmpty) appliedOps[opId] = result;
    return result;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final bodyText = request is http.Request ? request.body : '';

    if (path.endsWith('/rpc/push_sync_ops')) {
      if (disableV2Rpcs) {
        return _resp(
          {'code': 'PGRST202', 'message': 'Could not find the function push_sync_ops'},
          404,
        );
      }
      final decoded = jsonDecode(bodyText) as Map<String, Object?>;
      final ops = (decoded['p_ops'] as List).cast<Map>();
      pushedTableBatches.add([for (final op in ops) '${op['table']}']);
      final idRemap = <String, String>{};
      final out = <Map<String, Object?>>[];
      for (final op in ops) {
        final res = _applyOp(Map<String, Object?>.from(op), idRemap);
        if (res['outcome'] == 'adopted_existing') {
          final replacedId = res['replaced_id']?.toString();
          final canonicalId = (res['row'] as Map?)?['id']?.toString();
          if (replacedId != null &&
              canonicalId != null &&
              replacedId != canonicalId) {
            idRemap[replacedId] = canonicalId;
          }
        }
        out.add(res);
      }
      return _resp({'results': out}, 200);
    }

    if (path.endsWith('/rpc/pull_family_changes')) {
      if (disableV2Rpcs) {
        return _resp(
          {
            'code': 'PGRST202',
            'message': 'Could not find the function pull_family_changes',
          },
          404,
        );
      }
      final decoded = jsonDecode(bodyText) as Map<String, Object?>;
      final sid = decoded['p_space_id']?.toString() ?? '';
      final rawCursors = (decoded['p_cursors'] as Map?) ?? const {};
      final cursors = <String, int>{
        for (final e in rawCursors.entries)
          e.key.toString(): (e.value as num).toInt(),
      };
      final changes = <String, List<Map<String, Object?>>>{};
      final nextCursors = Map<String, int>.from(cursors);

      for (final entry in _tableToEntity.entries) {
        final table = entry.key;
        final entity = entry.value;
        final sinceSeq = cursors[entity] ?? 0;
        final matching = (tables[table] ?? const [])
            .where((r) =>
                (r['space_id'] == null || r['space_id'] == sid) &&
                ((r['sync_seq'] as num?)?.toInt() ?? 0) > sinceSeq)
            .toList()
          ..sort((a, b) => ((a['sync_seq'] as num?)?.toInt() ?? 0)
              .compareTo((b['sync_seq'] as num?)?.toInt() ?? 0));
        if (matching.isEmpty) continue;
        final decorated = [
          for (final r in matching)
            table == 'transaction' ? _decorateTx(r) : Map<String, Object?>.from(r),
        ];
        changes[entity] = decorated;
        nextCursors[entity] = (matching.last['sync_seq'] as num).toInt();
      }

      return _resp({
        'protocol': 2,
        'signal_seq': _seq,
        'has_more': false,
        'cursors': nextCursors,
        'family_space': tables['family_space'],
        'roster': {
          'changed': true,
          'membership': tables['membership'],
          'user_profile': tables['user_profile'],
        },
        'rate_snapshot': tables['rate_snapshot'],
        'changes': changes,
      }, 200);
    }

    // Fallback v1 PostgREST endpoints (used for rate_snapshot & v1 fallback test)
    if (path.contains('/rest/v1/')) {
      final table = path.split('/rest/v1/').last;
      if (request.method == 'POST') {
        final decoded = jsonDecode(bodyText);
        final incoming = decoded is List
            ? decoded.cast<Map>()
            : <Map>[decoded as Map];
        final out = <Map<String, Object?>>[];
        for (final raw in incoming) {
          final map = Map<String, Object?>.from(raw);
          map['updated_at'] = DateTime.now().toUtc().toIso8601String();
          map['sync_seq'] = nextSeq();
          tables.putIfAbsent(table, () => []).add(map);
          out.add(map);
        }
        return _resp(out, 201);
      }
      if (request.method == 'GET') {
        return _resp(tables[table] ?? const [], 200);
      }
    }

    return _resp(const [], 200);
  }

  http.StreamedResponse _resp(Object? body, int status) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );
}

class _V2Device {
  _V2Device({
    required this.db,
    required this.kv,
    required this.state,
    required this.engine,
  });

  final AppDatabase db;
  final Map<String, String> kv;
  final AppState state;
  final SyncEngine engine;

  static Future<_V2Device> boot({
    required MockSyncV2Server server,
    required Member user,
    bool useBatchProtocol = true,
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
      'space_id': 'sp_v2',
      'space_name': 'Moyo Family',
      'invite_code': 'MHRI-V2',
      'default_list_id': 'list_default',
    };
    const env = AppEnv(
      supabaseUrl: 'https://v2.sync.mhuri',
      supabaseAnonKey: 'anon-key',
    );
    final fakeAuth = FakeAuthService();
    await fakeAuth.signIn('${user.id}@mhuri.test', 'password123');
    final auth = AuthController(env: env, service: fakeAuth);
    await auth.restore();

    final state = AppState(db: db, env: env, auth: auth);
    await state.ready();
    state.setRealUser(user);

    final engine = SyncEngine(
      client: SupabaseSyncClient(
        baseUrl: env.supabaseUrl!,
        anonKey: env.supabaseAnonKey!,
        tokenGet: () async => 'token-${user.id}',
        client: server,
      ),
      database: db.raw,
      persistence: Persistence(db),
      state: state,
      kvGet: (k) async => kv[k],
      kvSet: (k, v) async => kv[k] = v,
      autoSchedule: false,
      useBatchProtocol: useBatchProtocol,
    );
    state.attachSync(engine);
    await engine.start();
    return _V2Device(db: db, kv: kv, state: state, engine: engine);
  }

  Future<void> sync() async {
    await state.flushWrites();
    await engine.syncNow(force: true);
    await state.flushWrites();
  }

  Future<void> dispose() async {
    engine.dispose();
    await db.raw.close();
  }
}

class _FakeWebSocket extends Stream<dynamic> implements WebSocket {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final List<String> sentFrames = [];
  bool closed = false;

  @override
  Duration? pingInterval;

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      incoming.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  void add(dynamic data) {
    if (data is String) sentFrames.add(data);
  }

  @override
  Future<dynamic> close([int? code, String? reason]) async {
    closed = true;
    await incoming.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const ownerA = Member(
    id: 'usr_owner_a',
    name: 'Tendai',
    emoji: 'crown',
    role: Role.owner,
  );
  const partnerB = Member(
    id: 'usr_partner_b',
    name: 'Rudo',
    emoji: 'person',
    role: Role.admin,
  );

  group('Sync Engine v2 protocol & zero-friction convergence', () {
    late MockSyncV2Server server;
    late _V2Device devA;
    late _V2Device devB;

    setUp(() async {
      server = MockSyncV2Server()
        ..seedSpace(
          spaceId: 'sp_v2',
          name: 'Moyo Family',
          members: const [ownerA, partnerB],
        );
      devA = await _V2Device.boot(server: server, user: ownerA);
      devB = await _V2Device.boot(server: server, user: partnerB);
      // Clear default seeded local envelopes so tests control exact rows.
      devA.state.envelopes.clear();
      devB.state.envelopes.clear();
      await devA.db.raw.delete('envelope');
      await devB.db.raw.delete('envelope');
    });

    tearDown(() async {
      await devA.dispose();
      await devB.dispose();
    });

    test(
        '1. Offline natural-key envelope collision adopts canonical id and remaps local tx + SQLite references',
        () async {
      // Both devices create "Electricity" offline with distinct client ids.
      devA.state.addEnvelope(
        name: 'Electricity',
        limit: const Money(8000, Currency.usd),
      );
      final envIdA = devA.state.envelopes.single.id;

      devB.state.addEnvelope(
        name: 'Electricity',
        limit: const Money(9500, Currency.usd),
      );
      final envIdB = devB.state.envelopes.single.id;
      expect(envIdA, isNot(equals(envIdB)));

      // Device B also logs an expense against its local `envIdB` before syncing!
      devB.state.addTx(
        id: 'tx_zesa_token',
        type: TxType.expense,
        amount: const Money(2500, Currency.usd),
        memberId: partnerB.id,
        method: Method.mobileMoney,
        note: 'ZESA token',
        envelopeId: envIdB,
      );
      await devB.state.flushWrites();

      // Device A syncs first -> `envIdA` becomes canonical on server.
      await devA.sync();
      expect(devA.engine.status, SyncStatus.idle);

      // Device B syncs -> `envIdB` is adopted into `envIdA`, and `tx_zesa_token`
      // is remapped to `envIdA` both locally and on the server!
      await devB.sync();
      expect(devB.engine.status, SyncStatus.idle);
      expect(await devB.engine.conflictCount(), 0);
      expect(await devB.engine.pendingCount(), 0);

      expect(devB.state.envelopes.map((e) => e.id).toList(), [envIdA]);
      final remappedTxB =
          devB.state.txs.singleWhere((t) => t.id == 'tx_zesa_token');
      expect(remappedTxB.envelopeId, envIdA);

      // Verify SQLite on Device B also remapped `envelope` and `tx.envelope_id`.
      final dbEnvsB = await devB.db.raw.query('envelope');
      expect(dbEnvsB.map((r) => r['id']).toList(), [envIdA]);
      final dbTxB = await devB.db.raw
          .query('tx', where: 'id = ?', whereArgs: ['tx_zesa_token']);
      expect(dbTxB.single['envelope_id'], envIdA);

      // Device A pulls and sees Device B's transaction attributed to `envIdA`!
      await devA.sync();
      final pulledTxA =
          devA.state.txs.singleWhere((t) => t.id == 'tx_zesa_token');
      expect(pulledTxA.envelopeId, envIdA);
    });

    test(
        '2. Multiple offline edits to same row preserve initial CAS base for 3-way merge',
        () async {
      devA.state.addEnvelope(
        name: 'Groceries',
        limit: const Money(10000, Currency.usd),
        rollover: Rollover.reset,
      );
      await devA.sync();
      await devB.sync();

      final envA = devA.state.envelopes.single;
      final envB = devB.state.envelopes.single;

      // Device B updates rollover to roll and syncs to server first (t2).
      devB.state.updateEnvelope(
        envB,
        name: envB.name,
        limit: envB.limit,
        rollover: Rollover.roll,
      );
      await devB.sync();

      // Device A (still at t1) makes TWO sequential offline edits to `envA`:
      // first changes limit -> $140, then renames -> 'Family Groceries'.
      devA.state.updateEnvelope(
        envA,
        name: 'Groceries',
        limit: const Money(14000, Currency.usd),
        rollover: Rollover.reset,
      );
      devA.state.updateEnvelope(
        envA,
        name: 'Family Groceries',
        limit: const Money(14000, Currency.usd),
        rollover: Rollover.reset,
      );

      // Sync Device A: collapsed unit preserves t1 base, so 3-way merge keeps
      // Device B's `Rollover.roll` AND Device A's `Family Groceries` + `$140`!
      await devA.sync();
      await devB.sync();

      expect(devA.engine.status, SyncStatus.idle);
      expect(await devA.engine.conflictCount(), 0);
      expect(devA.state.envelopes.single.name, 'Family Groceries');
      expect(devA.state.envelopes.single.limit.minor, 14000);
      expect(devA.state.envelopes.single.rollover, Rollover.roll);
      expect(devB.state.envelopes.single.name, 'Family Groceries');
      expect(devB.state.envelopes.single.limit.minor, 14000);
      expect(devB.state.envelopes.single.rollover, Rollover.roll);
    });

    test(
        '3. Un-attributing a transaction from an envelope propagates cleanly via _has_envelope_link',
        () async {
      devA.state.addEnvelope(
        name: 'Transport',
        limit: const Money(5000, Currency.usd),
      );
      await devA.sync();
      final envId = devA.state.envelopes.single.id;

      devA.state.addTx(
        id: 'tx_kombi',
        type: TxType.expense,
        amount: const Money(800, Currency.usd),
        memberId: ownerA.id,
        method: Method.cash,
        note: 'Kombi fare',
        envelopeId: envId,
      );
      await devA.sync();
      await devB.sync();
      expect(
        devB.state.txs.singleWhere((t) => t.id == 'tx_kombi').envelopeId,
        envId,
      );

      // Owner A removes budget attribution (`envelopeId: null`).
      final txA = devA.state.txs.singleWhere((t) => t.id == 'tx_kombi');
      final ok = devA.state.updateTx(
        txA,
        amount: txA.amount,
        method: txA.method,
        note: txA.note,
        when: txA.when,
        envelopeId: null,
      );
      expect(ok, isTrue);

      await devA.sync();
      await devB.sync();

      expect(
        devB.state.txs.singleWhere((t) => t.id == 'tx_kombi').envelopeId,
        isNull,
      );
      final dbRowB = await devB.db.raw
          .query('tx', where: 'id = ?', whereArgs: ['tx_kombi']);
      expect(dbRowB.single['envelope_id'], isNull);
    });

    test(
        '4. Mukando payment record and unrecord soft-delete tombstone syncs across devices',
        () async {
      await devA.sync();
      await devB.sync();

      expect(
        devA.state.configureMukando(
          name: 'Family Circle',
          contribution: const Money(5000, Currency.usd),
          frequency: 'monthly',
          participants: const [ownerA, partnerB],
        ),
        isTrue,
      );
      expect(devA.state.recordMukandoPayment(ownerA.id), isTrue);
      await devA.sync();
      await devB.sync();

      expect(devB.state.mukandoPayments.length, 1);
      expect(devB.state.mukandoPayments.single.memberId, ownerA.id);

      // Unrecord on Device A -> tombstone syncs and removes payment on Device B!
      expect(devA.state.unrecordMukandoPayment(ownerA.id), isTrue);
      await devA.sync();
      await devB.sync();

      expect(devA.state.mukandoPayments, isEmpty);
      expect(devB.state.mukandoPayments, isEmpty);
      expect(await devB.db.raw.query('mukando_payment'), isEmpty);
    });

    test(
        '5. Topological kPushOrder pushes FK parents (recurring) before FK children (tx)',
        () async {
      server.pushedTableBatches.clear();

      // Queue a `tx` first and a `recurring` rule second in outbox order,
      // verifying `_buildPushUnits` reorders `recurring_rule` before `transaction`.
      await Outbox(devA.db.raw).enqueue('tx', 'op_tx_child', {
        'id': 'tx_from_rule',
        'space_id': 'sp_v2',
        'member_id': ownerA.id,
        'type': 'expense',
        'amount_minor': 3000,
        'currency': 'USD',
        'method': 'cash',
        'note': 'WiFi bill',
        'recurring_rule_id': 'rc_wifi',
        'occurred_at': '2026-11-25T10:00:00Z',
      });
      await Outbox(devA.db.raw).enqueue('recurring', 'op_rc_parent', {
        'id': 'rc_wifi',
        'space_id': 'sp_v2',
        'name': 'WiFi',
        'emoji': 'wifi',
        'amount_minor': 3000,
        'currency': 'USD',
        'member_id': ownerA.id,
        'method': 'cash',
        'frequency': 'monthly',
        'next_due': '2026-12-25',
      });

      await devA.sync();
      expect(server.pushedTableBatches, isNotEmpty);
      final batch = server.pushedTableBatches.last;
      expect(
        batch.indexOf('recurring_rule'),
        lessThan(batch.indexOf('transaction')),
      );
    });

    test(
        '6. Dirty-row guard prevents pull from clobbering unpushed local edits while updating sync_version',
        () async {
      devA.state.addEnvelope(
        name: 'School Fees',
        limit: const Money(20000, Currency.usd),
      );
      await devA.sync();
      final env = devA.state.envelopes.single;

      // Device A edits locally ($250) WITHOUT syncing yet -> dirty in outbox.
      devA.state.updateEnvelope(
        env,
        name: 'School Fees',
        limit: const Money(25000, Currency.usd),
        rollover: env.rollover,
      );
      await devA.state.flushWrites();
      final dirtyIds = await Outbox(devA.db.raw).dirtyRowIdsForEntity('envelope');
      expect(dirtyIds, contains(env.id));

      // Simulate an incoming server pull carrying an older/other snapshot ($210).
      await Persistence(devA.db).applyServerRows(
        'envelope',
        [
          {
            'id': env.id,
            'space_id': 'sp_v2',
            'name': 'School Fees',
            'icon': 'money',
            'limit_minor': 21000,
            'limit_currency': 'USD',
            'rollover': 'reset',
            'sharing': 'shared',
            'is_archived': false,
            'updated_at': '2026-11-25T15:00:00Z',
          },
        ],
        dirtyIds: dirtyIds,
      );

      // Local SQLite row keeps unpushed $250 (`25000`), while `sync_version`
      // records the latest server version (`2026-11-25T15:00:00Z`).
      final localRow = (await devA.db.raw
              .query('envelope', where: 'id = ?', whereArgs: [env.id]))
          .single;
      expect(localRow['limit_minor'], 25000);

      final verRow = (await devA.db.raw.query(
        'sync_version',
        where: 'entity = ? AND row_id = ?',
        whereArgs: ['envelope', env.id],
      ))
          .single;
      expect(verRow['server_updated_at'], '2026-11-25T15:00:00Z');
      expect(verRow['server_payload'], isNotNull);
    });

    test(
        '7. Calm SyncHealthState stays saved on transient offline/error and falls back cleanly if v2 RPCs are absent',
        () async {
      // Transient offline and error states never alarm the user with needsAttention.
      devA.engine.status = SyncStatus.offline;
      expect(devA.state.syncHealth, SyncHealthState.saved);
      devA.engine.status = SyncStatus.error;
      expect(devA.state.syncHealth, SyncHealthState.saved);
      devA.engine.status = SyncStatus.needsSignIn;
      expect(devA.state.syncHealth, SyncHealthState.needsAttention);

      // Graceful v2 -> v1 fallback when `push_sync_ops` returns 404 PGRST202.
      server.disableV2Rpcs = true;
      devA.state.addTx(
        id: 'tx_fallback_v1',
        type: TxType.expense,
        amount: const Money(500, Currency.usd),
        memberId: ownerA.id,
        method: Method.cash,
        note: 'Bread',
      );
      await devA.sync();
      expect(devA.engine.status, SyncStatus.idle);
      expect(await devA.engine.pendingCount(), 0);
      expect(
        server.tables['transaction']!.any((r) => r['id'] == 'tx_fallback_v1'),
        isTrue,
      );
    });

    test(
        '8. RealtimeSyncSignal joins Phoenix channel, parses latest_seq, and coalesces rapid bursts',
        () async {
      late _FakeWebSocket fakeWs;
      final observedSeqs = <int?>[];

      final signal = RealtimeSyncSignal(
        baseUrl: 'https://v2.sync.mhuri',
        anonKey: 'anon-key',
        tokenGet: () async => 'jwt-token',
        onSignal: (seq) => observedSeqs.add(seq),
        connector: (_) async {
          fakeWs = _FakeWebSocket();
          return fakeWs;
        },
        coalesceWindow: const Duration(milliseconds: 25),
      );

      signal.configure(spaceId: 'sp_v2', active: true);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(fakeWs.sentFrames, isNotEmpty);
      final joinFrame = jsonDecode(fakeWs.sentFrames.first) as Map;
      expect(joinFrame['event'], 'phx_join');
      expect(
        joinFrame['topic'],
        'realtime:public:family_sync_signal:space_id=eq.sp_v2',
      );

      // Rapid burst of latest_seq 51, 52, 55 coalesces into ONE callback with max seq 55!
      for (final seq in [51, 52, 55]) {
        fakeWs.incoming.add(jsonEncode({
          'event': 'postgres_changes',
          'payload': {
            'data': {
              'record': {'space_id': 'sp_v2', 'latest_seq': seq},
            },
          },
        }));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(observedSeqs, [55]);

      signal.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fakeWs.closed, isTrue);
    });
  });
}
