import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:mhuri_money/core/sync/receipt_storage_service.dart';
import 'package:mhuri_money/core/sync/supabase_sync_client.dart';
import 'package:mhuri_money/core/sync/sync_engine.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'fake_auth.dart';

const _kB = 1024;

Uint8List _jpegBytes() =>
    Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(4 * _kB, 0x7F)]);

/// Captures Storage uploads/downloads without touching the network.
class _FakeStorageServer extends http.BaseClient {
  final List<http.Request> requests = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest base) async {
    final request = base as http.Request;
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(Uint8List(0)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Minimal Sync v2 mock: accepts every op, serves the seeded space.
class _MockSyncServer extends http.BaseClient {
  int _seq = 100;
  final String spaceId;
  final List<Map<String, Object?>> pushedOps = [];

  _MockSyncServer(this.spaceId);

  int nextSeq() => ++_seq;

  void seed() {
    // The pull payload is built from live tables; for this test a space row
    // plus empty roster is enough.
  }

  Map<String, Object?> get _spaceRow => {
        'id': spaceId,
        'name': 'Receipt Family',
        'base_currency': 'USD',
        'month_start_day': 1,
        'timezone': 'Africa/Harare',
        'sync_seq': nextSeq(),
        'settings': {'onboarding_stage': 'complete'},
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final bodyText = request is http.Request ? request.body : '';

    if (path.endsWith('/rpc/push_sync_ops')) {
      final decoded = jsonDecode(bodyText) as Map<String, Object?>;
      final ops = (decoded['p_ops'] as List).cast<Map>();
      final out = <Map<String, Object?>>[];
      for (final op in ops) {
        final payload = (op['payload'] as Map?) ?? const {};
        pushedOps.add(Map<String, Object?>.from(payload));
        out.add({
          'op_id': op['op_id'],
          'status': 'applied',
          'outcome': 'applied',
          'sync_seq': nextSeq(),
          'row': Map<String, Object?>.from(payload),
        });
      }
      return _resp({'results': out}, 200);
    }

    if (path.endsWith('/rpc/pull_family_changes')) {
      return _resp({
        'protocol': 2,
        'signal_seq': _seq,
        'has_more': false,
        'cursors': const <String, int>{},
        'family_space': [_spaceRow],
        'roster': {
          'changed': false,
          'membership': const <Map<String, Object?>>[],
          'user_profile': const <Map<String, Object?>>[],
        },
        'rate_snapshot': const <Map<String, Object?>>[],
        'changes': const <String, List<Map<String, Object?>>>{},
      }, 200);
    }

    if (path.contains('/rest/v1/')) {
      return _resp(const [], 200);
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

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Receipt URL + extension helpers', () {
    test('normalizeAuthenticatedReceiptUrl rewrites to the authenticated path',
        () {
      const base = 'https://oltc.supabase.co';
      expect(
        normalizeAuthenticatedReceiptUrl(
          supabaseUrl: base,
          rawUrl: '$base/storage/v1/object/authenticated/receipts/sp/x.jpg',
        ),
        '$base/storage/v1/object/authenticated/receipts/sp/x.jpg',
      );
      // /public/ leaks must be rewritten (the bucket is private).
      expect(
        normalizeAuthenticatedReceiptUrl(
          supabaseUrl: base,
          rawUrl: '$base/storage/v1/object/public/receipts/sp/x.png',
        ),
        '$base/storage/v1/object/authenticated/receipts/sp/x.png',
      );
    });

    test('normalizeAuthenticatedReceiptUrl rejects foreign origins + paths', () {
      const base = 'https://oltc.supabase.co';
      expect(
        normalizeAuthenticatedReceiptUrl(
          supabaseUrl: base,
          rawUrl: 'https://evil.example/storage/v1/object/authenticated/receipts/sp/x.jpg',
        ),
        isNull,
      );
      expect(
        normalizeAuthenticatedReceiptUrl(
          supabaseUrl: base,
          rawUrl: '$base/storage/v1/object/authenticated/avatars/me.png',
        ),
        isNull,
      );
      expect(
        normalizeAuthenticatedReceiptUrl(supabaseUrl: base, rawUrl: null),
        isNull,
      );
    });

    test('receiptExtensionOf normalizes extensions', () {
      expect(receiptExtensionOf('photo.heic?v=2'), 'jpg');
      expect(receiptExtensionOf('/a/b/pic.PNG'), 'png');
      expect(receiptExtensionOf('/a/b/pic.webp'), 'webp');
      expect(receiptExtensionOf('/a/b/noext'), 'jpg');
    });

    test('isRemoteReceiptUri distinguishes device paths from URLs', () {
      expect(isRemoteReceiptUri('https://x.y/z.jpg'), isTrue);
      expect(isRemoteReceiptUri('/data/user/0/app/receipts/a.jpg'), isFalse);
      expect(isRemoteReceiptUri(null), isFalse);
      expect(isRemoteReceiptUri('  '), isFalse);
    });
  });

  group('ReceiptStorageService staging, upload & offline cache', () {
    late Directory tempDir;
    late Directory cacheDir;
    late _FakeStorageServer server;
    late ReceiptStorageService storage;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('mhuri_stage');
      cacheDir = await Directory.systemTemp.createTemp('mhuri_cache');
      server = _FakeStorageServer();
      storage = ReceiptStorageService(
        baseUrl: 'https://oltc.supabase.co',
        anonKey: 'anon-key',
        tokenGet: () async => 'valid-token',
        client: server,
        cacheDirectoryProvider: () async => cacheDir,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
      await cacheDir.delete(recursive: true);
    });

    test('stageLocalReceipt persists bytes under a staged, non-temp name',
        () async {
      final bytes = _jpegBytes();
      final staged = await ReceiptStorageService.stageLocalReceipt(
        bytes: bytes,
        fallbackPath: '/tmp/cache/pick_123.jpg',
        overrideDir: tempDir,
      );
      expect(staged, startsWith(tempDir.path));
      expect(File(staged).readAsBytesSync(), bytes);
      expect(staged, contains('staged_'));
      // Empty bytes fall back so nothing silently disappears.
      final fallback = await ReceiptStorageService.stageLocalReceipt(
        bytes: Uint8List(0),
        fallbackPath: '/tmp/cache/pick_123.jpg',
        overrideDir: tempDir,
      );
      expect(fallback, '/tmp/cache/pick_123.jpg');
    });

    test('upload writes shared object path with x-upsert and caches bytes',
        () async {
      final bytes = _jpegBytes();
      final url = await storage.upload(
        bytes: bytes,
        spaceId: 'sp-1',
        txId: 'tx-1',
        extension: 'jpg',
      );
      expect(
        url,
        'https://oltc.supabase.co/storage/v1/object/authenticated/receipts/'
        'sp-1/shared/tx-1.jpg',
      );
      expect(server.requests, hasLength(1));
      final req = server.requests.single;
      expect(
        req.url.path,
        '/storage/v1/object/receipts/sp-1/shared/tx-1.jpg',
      );
      expect(req.headers['x-upsert'], 'true');
      expect(req.headers['Authorization'], 'Bearer valid-token');
      // The uploader also primes the offline cache with the same bytes.
      final cached = await storage.loadBytes(url);
      expect(cached, bytes);
      // ...and never hit the network again for it.
      expect(server.requests, hasLength(1));
    });

    test('upload scopes private-account receipts under the owner folder',
        () async {
      await storage.upload(
        bytes: _jpegBytes(),
        spaceId: 'sp-1',
        txId: 'tx-2',
        extension: 'png',
        privateOwnerUserId: 'usr-9',
      );
      expect(
        server.requests.single.url.path,
        '/storage/v1/object/receipts/sp-1/private/usr-9/tx-2.png',
      );
      expect(
        server.requests.single.headers['Content-Type'],
        'image/png',
      );
    });

    test('upload refuses empty bytes and missing sessions', () async {
      await expectLater(
        storage.upload(
            bytes: Uint8List(0),
            spaceId: 'sp',
            txId: 'tx',
            extension: 'jpg'),
        throwsA(isA<ReceiptStorageException>()),
      );
      final noSession = ReceiptStorageService(
        baseUrl: 'https://oltc.supabase.co',
        anonKey: 'anon-key',
        tokenGet: () async => null,
        client: server,
        cacheDirectoryProvider: () async => cacheDir,
      );
      await expectLater(
        noSession.upload(
            bytes: _jpegBytes(),
            spaceId: 'sp',
            txId: 'tx',
            extension: 'jpg'),
        throwsA(isA<ReceiptStorageException>()),
      );
    });

    test('loadBytes serves local paths directly', () async {
      final bytes = _jpegBytes();
      final local = File('${tempDir.path}/local.jpg')..writeAsBytesSync(bytes);
      expect(await storage.loadBytes(local.path), bytes);
    });

    test('loadBytes explains receipts that only exist on another device',
        () async {
      await expectLater(
        storage.loadBytes('/gone/device/path.jpg'),
        throwsA(isA<ReceiptStorageException>()),
      );
    });
  });

  group('Offline receipt pull-merge preservation', () {
    test('a server row with a null receipt_uri keeps the staged local photo',
        () async {
      final state = AppState(env: const AppEnv());
      await state.ready();
      state.setRealUser(const Member(
        id: 'usr_a',
        name: 'Tendai',
        emoji: 'crown',
        role: Role.owner,
      ));
      const txId = '11111111-1111-1111-1111-111111111111';
      state.txs.add(Tx(
        id: txId,
        memberId: 'usr_a',
        type: TxType.expense,
        amount: const Money(2500, Currency.usd),
        method: Method.cash,
        note: 'Groceries',
        when: DateTime(2026, 11, 20),
        receiptUri: '/device/receipts/staged_1.jpg',
      ));

      final serverRow = <String, Object?>{
        'id': txId,
        'space_id': 'sp',
        'type': 'expense',
        'amount_minor': 2500,
        'currency': 'USD',
        'member_id': 'usr_a',
        'method': 'cash',
        'note': 'Groceries',
        'occurred_at': '2026-11-20T12:00:00.000Z',
        'receipt_uri': null, // e.g. merged from a device without the photo.
        '_has_envelope_link': false,
      };
      state.applyPulled('tx', [serverRow]);

      final merged = state.txs.firstWhere((t) => t.id == txId);
      // The staged photo must NOT be erased by the empty server value.
      expect(merged.receiptUri, '/device/receipts/staged_1.jpg');

      // A server value that DOES exist always wins (device B sees A's photo).
      state.applyPulled('tx', [
        {
          ...serverRow,
          'receipt_uri':
              'https://oltc.supabase.co/storage/v1/object/authenticated/receipts/sp/shared/$txId.jpg',
        }
      ]);
      final promoted = state.txs.firstWhere((t) => t.id == txId);
      expect(
        promoted.receiptUri,
        '$kAuthenticatedPrefix/sp/shared/$txId.jpg',
      );
    });
  });

  group('Sync engine uploads pending receipts before pushing', () {
    late Directory cacheDir;
    late Directory stageDir;
    late _MockSyncServer server;
    late _FakeStorageServer storageServer;
    late AppDatabase db;
    late AppState state;
    late SyncEngine engine;
    late String stagedPath;

    const spaceId = '11111111-1111-1111-1111-111111111111';

    setUp(() async {
      cacheDir = await Directory.systemTemp.createTemp('mhuri_ecache');
      stageDir = await Directory.systemTemp.createTemp('mhuri_estage');
      server = _MockSyncServer(spaceId);
      storageServer = _FakeStorageServer();

      final raw = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          singleInstance: false,
          version: 1,
          onCreate: (d, v) async => AppDatabase.createSchema(d),
        ),
      );
      db = AppDatabase.wrap(raw);
      final kv = <String, String>{
        'space_id': spaceId,
        'space_name': 'Receipt Family',
        'default_list_id': 'list_default',
      };
      const env = AppEnv(
        supabaseUrl: 'https://oltc.supabase.co',
        supabaseAnonKey: 'anon-key',
      );
      final fakeAuth = FakeAuthService();
      await fakeAuth.signIn('usr_a@mhuri.test', 'password123');
      final auth = AuthController(env: env, service: fakeAuth);
      await auth.restore();

      state = AppState(db: db, env: env, auth: auth);
      await state.ready();
      state.setRealUser(const Member(
        id: 'usr_a',
        name: 'Tendai',
        emoji: 'crown',
        role: Role.owner,
      ));

      stagedPath = await ReceiptStorageService.stageLocalReceipt(
        bytes: _jpegBytes(),
        fallbackPath: '/tmp/never.jpg',
        overrideDir: stageDir,
      );

      engine = SyncEngine(
        client: SupabaseSyncClient(
          baseUrl: env.supabaseUrl!,
          anonKey: env.supabaseAnonKey!,
          tokenGet: () async => 'token-usr_a',
          client: server,
        ),
        database: db.raw,
        persistence: Persistence(db),
        state: state,
        kvGet: (k) async => kv[k],
        kvSet: (k, v) async => kv[k] = v,
        autoSchedule: false,
        useBatchProtocol: true,
        enableRealtime: false,
        receiptStorage: ReceiptStorageService(
          baseUrl: env.supabaseUrl!,
          anonKey: env.supabaseAnonKey!,
          tokenGet: () async => 'token-usr_a',
          client: storageServer,
          cacheDirectoryProvider: () async => cacheDir,
        ),
      );
      state.attachSync(engine);
      await engine.start();
    });

    tearDown(() async {
      engine.dispose();
      await db.raw.close();
      await cacheDir.delete(recursive: true);
      await stageDir.delete(recursive: true);
    });

    test('offline staged receipt is uploaded and promoted in one sync',
        () async {
      final added = state.addTx(
        type: TxType.expense,
        amount: const Money(3000, Currency.usd),
        memberId: 'usr_a',
        method: Method.cash,
        note: 'Burial society',
        envelopeId: null,
        when: DateTime(2026, 11, 21),
        receiptUri: stagedPath,
      );
      expect(added, isTrue);
      final txId = state.txs.first.id;
      // Before sync the tx carries a device path that must never leave it.
      expect(isRemoteReceiptUri(state.txs.first.receiptUri), isFalse);

      await state.flushWrites();
      await engine.syncNow(force: true);
      await state.flushWrites();

      // The photo reached the private bucket under the shared scope.
      expect(storageServer.requests, hasLength(1));
      expect(
        storageServer.requests.single.url.path,
        '/storage/v1/object/receipts/$spaceId/shared/$txId.jpg',
      );
      expect(storageServer.requests.single.headers['x-upsert'], 'true');

      // The local row was promoted to the canonical authenticated URL.
      final promoted = state.txs.firstWhere((t) => t.id == txId);
      expect(
        promoted.receiptUri,
        'https://oltc.supabase.co/storage/v1/object/authenticated/'
        'receipts/$spaceId/shared/$txId.jpg',
      );

      // The server received the remote URL, never the device path.
      expect(server.pushedOps.where((op) => op['id'] == txId), isNotEmpty);
      final lastPush =
          server.pushedOps.lastWhere((op) => op['id'] == txId);
      expect(lastPush['receipt_uri'], promoted.receiptUri);

      // The outbox is fully drained: promotion did not strand a row.
      final outbox = Outbox(db.raw);
      expect(await outbox.countConflicts(), 0);
    });

    test('sync proceeds fine when there are no pending receipts', () async {
      final added = state.addTx(
        type: TxType.expense,
        amount: const Money(1500, Currency.usd),
        memberId: 'usr_a',
        method: Method.cash,
        note: 'No receipt',
        when: DateTime(2026, 11, 22),
      );
      expect(added, isTrue);
      await state.flushWrites();
      await engine.syncNow(force: true);
      await state.flushWrites();
      expect(storageServer.requests, isEmpty);
      expect(state.txs.first.receiptUri, isNull);
    });
  });
}

const kAuthenticatedPrefix =
    'https://oltc.supabase.co/storage/v1/object/authenticated/receipts';
