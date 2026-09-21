import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/db/persistence.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/sync/sync_engine.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// M7 — sync reliability: exponential backoff, poison-batch parking, and
/// the pluggable error-report hook, exercised against a server that keeps
/// failing pushes with a 500.
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

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase db;
  late AppState state;
  late FakeServer server;
  late SyncEngine engine;
  late Map<String, String> kv;
  final errorWheres = <String>[];

  int txPosts() => server.sent
      .where(
          (r) => r.method == 'POST' && r.url.toString().contains('/rest/v1/tx'))
      .length;

  setUp(() async {
    SyncEngine.reportError = (where, e, st) => errorWheres.add(where);
    errorWheres.clear();
    kv = {};
    server = FakeServer((request) async {
      final url = request.url.toString();
      if (url.contains('/rpc/create_space')) {
        return _json({'id': 'sp_new', 'invite_code': 'MHRI-T7'});
      }
      if (request.method == 'GET') return _json([]);
      return _json({'message': 'server exploded'}, 500);
    });
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, v) async => AppDatabase.createSchema(d),
      ),
    );
    db = AppDatabase.wrap(raw);
    state = AppState(db: db);
    await state.ready();
    engine = SyncEngine(
      client: SupabaseSyncClient(
        baseUrl: 'https://abcdefgh.supabase.co',
        anonKey: 'anon',
        tokenGet: () async => null,
        client: server,
      ),
      database: db.raw,
      persistence: Persistence(db),
      state: state,
      kvGet: (k) async => kv[k],
      kvSet: (k, v) async => kv[k] = v,
    );
  });

  tearDown(() async {
    SyncEngine.reportError = null;
    await db.raw.close();
  });

  test('failed pushes back off; only force retries immediately', () async {
    expect(await engine.createSpace('The Taylor Family'), isTrue);
    expect(engine.status, SyncStatus.idle);
    expect(errorWheres, isEmpty, reason: 'no errors during a clean bootstrap');
    final before = txPosts();

    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(3, Currency.usd),
      memberId: 'm_david',
      method: Method.cash,
      note: 'Backoff test',
    );
    await engine.syncNow();
    expect(engine.status, SyncStatus.error);
    expect(txPosts(), before + 1, reason: 'one push attempt was made');
    expect(errorWheres, contains('sync'), reason: 'hook saw the failure');
    expect(await engine.pendingCount(), 1, reason: 'the op is kept');

    await engine.syncNow();
    expect(txPosts(), before + 1, reason: 'backing off — nothing sent');

    await engine.syncNow(force: true);
    expect(txPosts(), before + 2, reason: 'force bypasses the backoff');
    expect(await engine.pendingCount(), 1, reason: 'still failing, still kept');
  });

  test('a success resets the backoff', () async {
    expect(await engine.createSpace('The Taylor Family'), isTrue);
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(2, Currency.usd),
      memberId: 'm_david',
      method: Method.cash,
      note: 'Reset test',
    );
    await engine.syncNow(); // fails
    expect(engine.status, SyncStatus.error);

    // Server heals: pushes now succeed.
    server.handler = (request) async {
      if (request.method == 'GET') return _json([]);
      return _json(null);
    };
    await engine.syncNow(force: true);
    expect(engine.status, SyncStatus.idle);
    expect(await engine.pendingCount(), 0);

    // The backoff was reset — a normal sync runs immediately.
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(1, Currency.usd),
      memberId: 'm_david',
      method: Method.cash,
      note: 'Reset test 2',
    );
    final posts = txPosts();
    await engine.syncNow();
    expect(engine.status, SyncStatus.idle);
    expect(txPosts(), posts + 1, reason: 'no backoff after a clean sync');
  });

  test('poison batches park after maxAttempts; force retries them', () async {
    expect(await engine.createSpace('The Taylor Family'), isTrue);
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(5, Currency.usd),
      memberId: 'm_david',
      method: Method.cash,
      note: 'Parking test',
    );

    for (var i = 0; i < SyncEngine.maxAttempts; i++) {
      await engine.syncNow(force: true);
      expect(engine.status, SyncStatus.error);
    }
    expect(await engine.pendingCount(), 1, reason: 'parked, never dropped');

    await engine.syncNow();
    expect(engine.lastError, contains('parked'),
        reason: 'the parked op is clearly surfaced, not silently retried');
    final before = txPosts();

    await engine.syncNow(force: true);
    expect(txPosts(), before + 1, reason: '"Sync now" retries parked ops');
    expect(await engine.pendingCount(), 1);
  });
}
