import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mhuri_money/core/config/app_env.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/db/persistence.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/sync_engine.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/sync/outbox.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Routes requests to canned handlers so multi-endpoint sync flows can be
/// exercised fully offline.
class FakeServer extends http.BaseClient {
  FakeServer(this.handler);

  Future<http.Response> Function(http.BaseRequest request) handler;
  final List<http.BaseRequest> sent = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sent.add(request);
    final r = await handler(request);
    return http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      headers: r.headers,
    );
  }
}

http.Response _json(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json',
    });

const _liveEnv = AppEnv(
  supabaseUrl: 'https://abcdefgh.supabase.co',
  supabaseAnonKey: 'anon-key',
);

Future<AppDatabase> _freshDb() async {
  final raw = await databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (d, v) async => AppDatabase.createSchema(d),
    ),
  );
  return AppDatabase.wrap(raw);
}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('sync mappers', () {
    test('tx survives encode→decode with enum bridges', () {
      final ctx = SyncCtx(spaceId: 'sp1', newId: () => 'x1');
      final t = Tx(
        id: 't1',
        envelopeId: 'e1',
        memberId: 'm1',
        type: TxType.expense,
        amount: Money.fromMajor(12.34, Currency.usd),
        method: Method.bankCard,
        note: 'FreshMart',
        when: DateTime(2026, 9, 21, 10, 15),
      );
      final j = kSyncAdapters['tx']!.encode(t, ctx);
      expect(j['method'], 'bank_card');
      expect(j['space_id'], 'sp1');
      final back = kSyncAdapters['tx']!.decode(j) as Tx;
      expect(back.id, t.id);
      expect(back.method, Method.bankCard);
      expect(back.amount.minor, t.amount.minor);
      expect(back.note, t.note);
    });

    test('envelope rollover roll ↔ "rollover"', () {
      final ctx = SyncCtx(spaceId: 'sp1', newId: () => 'x1');
      final e = Envelope(
        id: 'e7',
        name: 'Emergency buffer',
        emoji: 'lifebuoy',
        limit: Money.fromMajor(100, Currency.usd),
        rollover: Rollover.roll,
      );
      final j = kSyncAdapters['envelope']!.encode(e, ctx);
      expect(j['rollover'], 'rollover');
      final back = kSyncAdapters['envelope']!.decode(j) as Envelope;
      expect(back.rollover, Rollover.roll);
      expect(back.isPersonal, isFalse);
    });

    test('kid_request kind routes to KidRequest vs Proposal', () {
      final ctx = SyncCtx(spaceId: 'sp1', newId: () => 'x1');
      final req = KidRequest(
        id: 'r1',
        kidId: 'k1',
        amount: Money.fromMajor(5, Currency.usd),
        reason: 'trip',
      );
      final decodedReq = kSyncAdapters['kid_request']!
          .decode(kSyncAdapters['kid_request']!.encode(req, ctx)) as KidRequest;
      expect(decodedReq.kidId, 'k1');

      final prop = Proposal(
        id: 'p1',
        teenId: 't1',
        amount: Money.fromMajor(15, Currency.usd),
        envelopeId: 'e6',
        reason: 'movie night',
      );
      final j = kSyncAdapters['kid_request']!.encode(prop, ctx);
      expect(j['kind'], 'expense_proposal');
      final decodedProp = kSyncAdapters['kid_request']!.decode(j) as Proposal;
      expect(decodedProp.envelopeId, 'e6');
    });

    test('goal_tx gets a server id from the context at encode time', () {
      var n = 0;
      final ctx = SyncCtx(spaceId: 'sp1', newId: () => 'gen${n++}');
      final g = GoalTx(
        goalId: 'g1',
        byMemberId: 'm1',
        amount: Money.fromMajor(25, Currency.usd),
        at: DateTime(2026, 9, 21),
      );
      final j = kSyncAdapters['goal_tx']!.encode(g, ctx);
      expect(j['id'], 'gen0');
    });
  });

  group('outbox', () {
    late AppDatabase db;

    setUp(() async {
      db = await _freshDb();
    });

    tearDown(() async {
      await db.raw.close();
    });

    test('enqueue → take (ordered) → delete → count', () async {
      final outbox = Outbox(db.raw);
      await outbox.enqueue('tx', 'op1', {'id': 'a'});
      await outbox.enqueue('tx', 'op2', {'id': 'b'});
      expect(await outbox.count(), 2);

      final ops = await outbox.take(10);
      expect(ops.map((o) => o.opId).toList(), ['op1', 'op2']);

      await outbox.deleteRows([ops[0].rowId]);
      expect(await outbox.count(), 1);
      expect((await outbox.take(10)).first.payload['id'], 'b');
    });
  });

  group('SyncEngine (offline, FakeServer)', () {
    late AppDatabase db;
    late Map<String, String> kv;
    late FakeServer server;
    late AppState state;
    late SyncEngine engine;

    setUp(() async {
      db = await _freshDb();
      kv = {};
      server = FakeServer((request) async {
        final path = request.url.path;
        if (path.startsWith('/rest/v1/rpc/create_space')) {
          return _json({'id': 'sp_new', 'invite_code': 'MHRI-AB12'});
        }
        if (request.method == 'GET' && path == '/rest/v1/envelope') {
          return _json([
            {
              'id': 'env9',
              'space_id': 'sp_new',
              'name': 'Rent',
              'icon': 'home',
              'limit_minor': 20000,
              'limit_currency': 'USD',
              'period': 'monthly',
              'rollover': 'reset',
              'sharing': 'shared',
              'updated_at': '2026-09-21T10:00:00+00:00',
            }
          ]);
        }
        // every other pull table + pushes succeed empty/OK
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      });
      state = AppState(db: db, env: _liveEnv);
      await state.ready();
      engine = SyncEngine(
        client: SupabaseSyncClient(
          baseUrl: 'https://abcdefgh.supabase.co',
          anonKey: 'anon-key',
          tokenGet: () async => 'test-token',
          client: server,
        ),
        database: db.raw,
        persistence: Persistence(db),
        state: state,
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
      );
      state.attachSync(engine);
    });

    tearDown(() async {
      engine.dispose();
      await state.flushWrites();
      await db.raw.close();
    });

    test('sync client refuses an empty token (never sends an empty JWT)',
      () async {
    final client = SupabaseSyncClient(
      baseUrl: 'https://abcdefgh.supabase.co',
      anonKey: 'anon-key',
      tokenGet: () async => '',
      client: server, // must never be reached
    );
    await expectLater(
      client.rpc('create_space', {'p_name': 'X'}),
      throwsA(isA<SyncException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.message, 'message', contains('sign in again'))),
    );
  });

  test('createSpace stores id/code, wipes local rows, pulls family data',
        () async {
      // One locally recorded envelope from before adoption (offline-first
      // start) — adoption wipes it so the family's server data takes over.
      final local = Envelope(
        id: 'e1',
        name: 'Local stash',
        emoji: 'box',
        limit: Money.fromMajor(40, Currency.usd),
      );
      state.envelopes.add(local);
      await Persistence(db).saveEnvelope(local);
      expect(state.envelopes.length, 1);

      final ok = await engine.createSpace('The Taylor Family');
      expect(ok, isTrue);
      expect(kv['space_id'], 'sp_new');
      expect(kv['invite_code'], 'MHRI-AB12');
      expect(engine.inviteCode, 'MHRI-AB12');

      // local rows wiped — family starts clean
      expect(state.envelopes.any((e) => e.id == 'e1'), isFalse);

      // the pulled family envelope arrived and is live in memory
      final rent = state.envelope('env9');
      expect(rent, isNotNull);
      expect(rent!.name, 'Rent');
      expect(kv['sync_cursor'], '2026-09-21T10:00:00+00:00');
    });

    test('mutation → outbox → verbatim push → outbox drains', () async {
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();

      state.addTx(
        type: TxType.expense,
        amount: Money.fromMajor(7, Currency.usd),
        memberId: 'm_maya',
        method: Method.mobileMoney,
        note: 'Synced expense',
        envelopeId: 'e1',
      );
      // debounced enqueue → give it a moment
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await engine.pendingCount(), greaterThanOrEqualTo(1));

      await engine.syncNow();

      // outbox drained
      expect(await engine.pendingCount(), 0);

      // the push hit the right endpoint with the right semantics
      final push = server.sent.firstWhere(
        (r) => r.url.path == '/rest/v1/transaction' && r.method == 'POST',
      ) as http.Request;
      expect(push.url.queryParameters['on_conflict'], 'id');
      expect(push.headers['prefer'], contains('merge-duplicates'));
      expect(push.headers['authorization'], 'Bearer test-token');
      final body = jsonDecode(push.body) as List;
      final row = body.first as Map<String, dynamic>;
      expect(row['note'], 'Synced expense');
      expect(row['method'], 'mobile_money');
      expect(row.containsKey('space_id'), isTrue);
    });

    test('pull applies remote rows and advances the cursor', () async {
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();
      await engine.syncNow();

      final rent = state.envelope('env9');
      expect(rent, isNotNull);
      expect(state.syncStatus, SyncStatus.idle);
      expect(kv['sync_cursor'], '2026-09-21T10:00:00+00:00');
    });

    test('server rows persist locally and survive a "restart"', () async {
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();
      await engine.syncNow();

      final second = AppState(db: db, env: _liveEnv);
      await second.ready();
      // hydrated from the local DB: pulled envelope survived
      expect(second.envelope('env9'), isNotNull);
    });

    test('joinSpace with a bad code surfaces a friendly error', () async {
      server.handler = (request) async {
        if (request.url.path.startsWith('/rest/v1/rpc/join_space')) {
          return _json({'message': 'INVALID_CODE'}, 400);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      final ok = await engine.joinSpace('MHRI-ZZZZ');
      expect(ok, isFalse);
      expect(engine.status, SyncStatus.error);
      expect(engine.lastError, contains('invite code was not found'));
    });

    test(
        'premium entities: remote chore / recurring_rule / mukando pull applies',
        () async {
      server.handler = (request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/rest/v1/chore') {
          return _json([
            {
              'id': 'c7b1a2f3-1111-4222-8333-444455556666',
              'space_id': 'sp1',
              'name': 'Wash dishes',
              'star_value': 3,
              'state': 'waiting',
              'updated_at': '2026-09-21T09:00:00+00:00',
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/recurring_rule') {
          return _json([
            {
              'id': 'd8c2b3a4-2222-4333-9444-555566667777',
              'space_id': 'sp1',
              'name': 'Rent',
              'emoji': 'home',
              'amount_minor': 80000,
              'currency': 'USD',
              'envelope_id': null,
              'member_id': null,
              'method': 'cash',
              'frequency': 'monthly',
              'next_due': '2026-10-01',
              'active': true,
              'updated_at': '2026-09-21T09:05:00+00:00',
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/mukando') {
          return _json([
            {
              'id': 'e9d3c4b5-3333-4444-a555-666677778888',
              'space_id': 'sp1',
              'name': 'Family circle',
              'contribution_minor': 5000,
              'currency': 'ZWG',
              'frequency': 'monthly',
              'total_rounds': 6,
              'current_round': 3,
              'round_order': ['Mai', 'Baba', 'Sekuru'],
              'updated_at': '2026-09-21T09:10:00+00:00',
            }
          ]);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();
      await engine.syncNow();

      final ch = state.chores.firstWhere((c) => c.id.startsWith('c7b1a2f3'));
      expect(ch.state, ChoreState.waiting);
      expect(ch.stars, 3);
      final rc = state.recurring.firstWhere((r) => r.id.startsWith('d8c2b3a4'));
      expect(rc.frequency, Frequency.monthly);
      expect(rc.nextDue, DateTime(2026, 10, 1));
      expect(state.circle.name, 'Family circle');
      expect(state.circle.nextCollector, 'Mai');
      expect(kv['sync_cursor'], '2026-09-21T09:10:00+00:00');
    });

    test('premium entities: chore / recurring / circle mutations push',
        () async {
      server.handler = (request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/rest/v1/chore') {
          return _json([
            {
              'id': 'c7b1a2f3-1111-4222-8333-444455556666',
              'space_id': 'sp1',
              'name': 'Wash dishes',
              'star_value': 3,
              'state': 'todo',
              'updated_at': '2026-09-21T09:00:00+00:00',
            }
          ]);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();

      // claim the PULLED chore (uuid id, as server rows always are)
      state.claimChore(
        state.chores.firstWhere((c) => c.id.startsWith('c7b1a2f3')),
      );
      state.addRecurring(
        name: 'Airtime',
        emoji: 'phone',
        amount: Money.fromMajor(10, Currency.usd),
        memberId: 'm_maya',
        method: Method.mobileMoney,
        frequency: Frequency.monthly,
        nextDue: DateTime(2026, 10, 1),
      );
      state.circleCollect();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      await engine.syncNow();
      expect(await engine.pendingCount(), 0);

      final pushed = server.sent
          .where((r) => r.method == 'POST')
          .map((r) => r.url.path)
          .toSet();
      expect(
        pushed,
        containsAll(<String>[
          '/rest/v1/chore',
          '/rest/v1/recurring_rule',
          '/rest/v1/mukando',
        ]),
      );
      // every pushed row id is a well-formed uuid (server columns are uuid)
      final uuidRe = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      for (final r in server.sent.where((r) => r.method == 'POST')) {
        final body = jsonDecode((r as http.Request).body) as List;
        for (final row in body) {
          expect(uuidRe.hasMatch((row as Map<String, dynamic>)['id'] as String),
              isTrue,
              reason: 'pushed id for ' + r.url.path + ' must be uuid');
        }
      }
    });
  });
}
