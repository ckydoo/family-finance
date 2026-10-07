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

  test('assisted member creation uses authenticated Edge Function', () async {
    late http.BaseRequest captured;
    final server = FakeServer((request) async {
      captured = request;
      return _json({'created': true, 'user_id': 'member-2'}, 201);
    });
    final client = SupabaseSyncClient(
      baseUrl: 'https://abcdefgh.supabase.co',
      anonKey: 'anon-key',
      tokenGet: () async => 'owner-access-token',
      client: server,
    );

    final result = await client.invokeFunction('create-family-member', {
      'name': 'Tariro',
      'email': 'tariro@example.com',
      'temporary_password': 'Secure12345',
      'role': 'teen',
    });

    expect(captured.method, 'POST');
    expect(captured.url.path, '/functions/v1/create-family-member');
    expect(captured.headers['authorization'], 'Bearer owner-access-token');
    expect(captured.headers['apikey'], 'anon-key');
    expect(result['created'], isTrue);
  });

  test('pull percent-encodes positive timezone offsets in sync cursors',
      () async {
    late Uri requested;
    final server = FakeServer((request) async {
      requested = request.url;
      return _json([]);
    });
    final client = SupabaseSyncClient(
      baseUrl: 'https://abcdefgh.supabase.co',
      anonKey: 'anon-key',
      tokenGet: () async => 'test-token',
      client: server,
    );

    await client.pullRows(
      'envelope',
      orderCol: 'updated_at',
      sinceIso: '2026-09-29T18:55:05.868805+00:00',
    );

    expect(requested.query, contains('%2B00%3A00'));
    expect(
      requested.queryParameters['updated_at'],
      'gt.2026-09-29T18:55:05.868805+00:00',
    );
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

    test('membersFromServer carries avatar_url into the member', () {
      final roster = membersFromServer(
        membershipRows: [
          {'space_id': 'sp', 'user_id': 'u1', 'role': 'owner'},
        ],
        profileRows: [
          {
            'id': 'u1',
            'name': 'Tendi',
            'email': 'tendi@mhuri.app',
            'avatar_url':
                'https://abcdefgh.supabase.co/storage/v1/object/public/avatars/u1/avatar.jpg',
          },
        ],
        meId: 'u1',
      );
      expect(roster.single.avatarUrl, contains('/avatars/u1/'));
    });

    test('failed family setup save does not advance local onboarding',
        () async {
      server.handler = (request) async {
        if (request.url.path.startsWith('/rest/v1/rpc/save_family_setup')) {
          return _json({'message': 'temporarily unavailable'}, 503);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };

      final saved = await engine.saveFamilySetup(
        primary: Currency.usd,
        secondary: Currency.zwg,
        monthStart: 1,
        templates: const [
          {'key': 'groceries', 'name': 'Groceries', 'icon': 'cart'},
        ],
        stage: 'ready',
      );

      expect(saved, isFalse);
      expect(state.onboardingStage, 'create');
      expect(state.onboardingComplete, isFalse);
      expect(state.onboardingTemplates, isEmpty);
    });

    test('successful family setup is not failed by the follow-up refresh',
        () async {
      server.handler = (request) async {
        if (request.url.path.startsWith('/rest/v1/rpc/save_family_setup')) {
          return _json({'space_id': 'sp_new', 'stage': 'ready'});
        }
        // The follow-up refresh cannot complete after the setup commit.
        return _json({'message': 'temporarily unavailable'}, 503);
      };

      final saved = await engine.saveFamilySetup(
        primary: Currency.usd,
        secondary: Currency.zwg,
        monthStart: 1,
        templates: const [
          {'key': 'groceries', 'name': 'Groceries', 'icon': 'cart'},
        ],
        stage: 'ready',
      );

      expect(saved, isTrue);
      expect(state.onboardingStage, 'ready');
      expect(state.onboardingTemplates.single['key'], 'groceries');
    });

    test('switching accounts parks and restores each family including outbox',
        () async {
      kv
        ..['space_id'] = 'family-a'
        ..['space_name'] = 'Family A'
        ..['invite_code'] = 'MHRI-AAAA'
        ..['default_list_id'] = 'list-a'
        ..['cached_family_user_id'] = 'user-a'
        ..['me_id'] = 'user-a'
        ..['members_v1'] = '[{"id":"user-a","name":"A","role":"owner"}]'
        ..['sync_cursor_envelope'] = '2026-09-01T00:00:00Z';
      for (final entry in kv.entries) {
        await db.kvSet(entry.key, entry.value);
      }
      final familyAEnvelope = Envelope(
        id: 'family-a-budget',
        name: 'Private Family A budget',
        emoji: 'money',
        limit: Money.fromMajor(100, Currency.usd),
      );
      state.envelopes.add(familyAEnvelope);
      await Persistence(db).saveEnvelope(familyAEnvelope);
      await Outbox(db.raw).enqueue('envelope', 'old-op', {
        'id': familyAEnvelope.id,
        'space_id': 'family-a',
      });
      await engine.ensureUserIsolation('user-b', email: 'b@example.com');

      expect(engine.spaceId, isNull);
      expect(state.envelopes, isEmpty);
      expect(state.user.id, 'user-b');
      expect(state.onboardingComplete, isFalse);
      expect(kv['space_id'], isEmpty);
      expect(kv['space_name'], isEmpty);
      expect(kv['default_list_id'], isEmpty);
      expect(kv['sync_cursor_envelope'], isEmpty);
      expect(kv['cached_family_user_id'], 'user-b');
      expect(await db.raw.query('envelope'), isEmpty);
      expect(await Outbox(db.raw).count(), 0);

      kv
        ..['space_id'] = 'family-b'
        ..['space_name'] = 'Family B'
        ..['invite_code'] = 'MHRI-BBBB'
        ..['me_id'] = 'user-b'
        ..['members_v1'] = '[{"id":"user-b","name":"B","role":"owner"}]';
      for (final key in const [
        'space_id',
        'space_name',
        'invite_code',
        'me_id',
        'members_v1',
      ]) {
        await db.kvSet(key, kv[key]!);
      }
      final familyBEnvelope = Envelope(
        id: 'family-b-budget',
        name: 'Private Family B budget',
        emoji: 'money',
        limit: Money.fromMajor(50, Currency.usd),
      );
      state.envelopes.add(familyBEnvelope);
      await Persistence(db).saveEnvelope(familyBEnvelope);
      await Outbox(db.raw).enqueue('envelope', 'b-op', {
        'id': familyBEnvelope.id,
        'space_id': 'family-b',
      });

      await engine.ensureUserIsolation('user-a', email: 'a@example.com');

      expect(engine.spaceId, 'family-a');
      expect(state.user.id, 'user-a');
      expect(state.envelopes.map((e) => e.id), ['family-a-budget']);
      final restoredOutbox = await db.raw.query('outbox');
      expect(restoredOutbox, hasLength(1));
      expect(restoredOutbox.single['op_id'], 'old-op');
      expect(restoredOutbox.single['payload'], contains('family-a'));
      expect(restoredOutbox.single['payload'], isNot(contains('family-b')));
      expect(kv['sync_cursor_envelope'], '2026-09-01T00:00:00Z');
    });

    test('assisted account creation refreshes the visible family roster',
        () async {
      final meId = state.user.id;
      server.handler = (request) async {
        final path = request.url.path;
        if (request.method == 'POST' &&
            path == '/functions/v1/create-family-member') {
          return _json({'created': true, 'user_id': 'member-myla'}, 201);
        }
        if (request.method == 'GET' && path == '/rest/v1/membership') {
          return _json([
            {'space_id': 'sp1', 'user_id': meId, 'role': 'owner'},
            {'space_id': 'sp1', 'user_id': 'member-myla', 'role': 'teen'},
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/user_profile') {
          return _json([
            {'id': meId, 'name': 'Owner', 'email': 'owner@example.com'},
            {'id': 'member-myla', 'name': 'Myla', 'email': 'myla@example.com'},
          ]);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      kv['space_id'] = 'sp1';
      await engine.start();

      await engine.createFamilyMember(
        name: 'Myla',
        email: 'myla@example.com',
        temporaryPassword: 'Temporary123',
        role: 'teen',
      );

      expect(state.members.any((m) => m.id == 'member-myla'), isTrue);
      expect(
          state.members.singleWhere((m) => m.id == 'member-myla').name, 'Myla');
      expect(state.members.singleWhere((m) => m.id == 'member-myla').role,
          Role.teen);
    });

    test('missing personal savings jar is provisioned and applied locally',
        () async {
      late Map<String, dynamic> sent;
      final memberId = state.user.id;
      server.handler = (request) async {
        if (request.method == 'POST' &&
            request.url.path == '/functions/v1/ensure-savings-jar') {
          sent = jsonDecode((request as http.Request).body)
              as Map<String, dynamic>;
          return _json({
            'goal': {
              'id': memberId,
              'space_id': 'sp1',
              'name': 'My savings',
              'icon': 'goal',
              'target_minor': 10000,
              'target_currency': 'USD',
              'owner_member_id': memberId,
              'is_kid_jar': false,
              'status': 'active',
            }
          }, 201);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };

      final jar = await engine.ensurePersonalSavingsGoal();

      expect(sent['member_id'], memberId);
      expect(jar, isNotNull);
      expect(jar!.ownerMemberId, memberId);
      expect(state.teenJarGoal?.id, memberId);
    });

    test('createSpace refuses a taken family name with a clear error',
        () async {
      server = FakeServer((request) async {
        if (request.url.path.startsWith('/rest/v1/rpc/family_name_taken')) {
          return _json(true);
        }
        return _json(null, 201);
      });
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
      final ok = await engine.createSpace('Chikangaiso');
      expect(ok, isFalse);
      expect(engine.lastError, contains('FAMILY_NAME_TAKEN'));
    });

    test('patchRow PATCHes user_profile by id', () async {
      server = FakeServer((request) async {
        if (request.method == 'PATCH' &&
            request.url.path == '/rest/v1/user_profile') {
          expect(request.url.query, contains('id=eq.u-9'));
          return _json(null, 204);
        }
        return _json(null, 400);
      });
      final client = SupabaseSyncClient(
        baseUrl: 'https://abcdefgh.supabase.co',
        anonKey: 'anon-key',
        tokenGet: () async => 'test-token',
        client: server,
      );
      await client
          .patchRow('user_profile', 'u-9', {'avatar_url': 'https://x/a.jpg'});
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
      // start) - adoption wipes it so the family's server data takes over.
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

      // local rows wiped - family starts clean
      expect(state.envelopes.any((e) => e.id == 'e1'), isFalse);

      // the pulled family envelope arrived and is live in memory
      final rent = state.envelope('env9');
      expect(rent, isNotNull);
      expect(rent!.name, 'Rent');
      expect(kv['sync_cursor_envelope'], '2026-09-21T10:00:00+00:00');
    });

    test('mutation → outbox → verbatim push → outbox drains', () async {
      kv['space_id'] = 'sp1';
      await engine.start();
      await state.ready();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      server.sent.clear();

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
      expect(kv['sync_cursor_envelope'], '2026-09-21T10:00:00+00:00');
    });

    test('one failed module does not block budgets, links, or list amounts',
        () async {
      final now = DateTime.now().toUtc().toIso8601String();
      server.handler = (request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/rest/v1/envelope') {
          return _json([
            {
              'id': 'env-grocery',
              'space_id': 'sp1',
              'name': 'Groceries',
              'icon': 'cart',
              'limit_minor': 30000,
              'limit_currency': 'USD',
              'rollover': 'reset',
              'sharing': 'shared',
              'updated_at': now,
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/transaction') {
          return _json([
            {
              'id': 'tx-grocery',
              'space_id': 'sp1',
              'member_id': 'test-user-1',
              'type': 'expense',
              'amount_minor': 2500,
              'currency': 'USD',
              'method': 'cash',
              'note': 'Market',
              'occurred_at': now,
              'updated_at': now,
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/goal_tx') {
          return _json({'message': 'temporary goal failure'}, 500);
        }
        if (request.method == 'GET' && path == '/rest/v1/list_item') {
          return _json([
            {
              'id': 'item-rice',
              'list_id': 'list-1',
              'name': 'Rice',
              'qty': 2,
              'est_price_minor': 400,
              'currency': 'USD',
              'added_by': 'test-user-1',
              'state': 'tobuy',
              'checked_out': false,
              'updated_at': now,
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/envelope_tx') {
          return _json([
            {
              'envelope_id': 'env-grocery',
              'transaction_id': 'tx-grocery',
              'allocated_minor': 2500,
              'currency': 'USD',
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

      final groceries = state.envelope('env-grocery')!;
      expect(state.spentOn(groceries).minor, 2500);
      expect(state.estFor(Currency.usd).minor, 800);
      expect(kv['sync_cursor_list_item'], now);
      expect(kv['sync_cursor_goal_tx'], isNull,
          reason: 'the failed table must retry from its previous cursor');
    });

    test('transaction remains queued when envelope attribution push fails',
        () async {
      server.handler = (request) async {
        if (request.method == 'POST' &&
            request.url.path == '/rest/v1/envelope_tx') {
          return _json({'message': 'link unavailable'}, 503);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      kv['space_id'] = 'sp1';
      await engine.start();
      state.envelopes.add(Envelope(
        id: 'env-grocery',
        name: 'Groceries',
        emoji: 'cart',
        limit: Money.fromMajor(300, Currency.usd),
      ));
      state.addTx(
        type: TxType.expense,
        amount: Money.fromMajor(10, Currency.usd),
        memberId: state.user.id,
        method: Method.cash,
        note: 'Food',
        envelopeId: 'env-grocery',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      await engine.syncNow();

      expect(await engine.pendingCount(), greaterThan(0),
          reason: 'the tx and its budget link must retry together');
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

    test('remote transaction tombstone removes duplicate locally', () async {
      final duplicate = Tx(
        id: 'tx-duplicate',
        envelopeId: 'env9',
        memberId: 'test-user-1',
        type: TxType.expense,
        amount: Money.fromMajor(43.80, Currency.usd),
        method: Method.bankCard,
        note: 'Groceries run',
        when: DateTime.now(),
      );
      state.txs.add(duplicate);
      await Persistence(db).saveTx(duplicate);

      final row = <String, Object?>{
        'id': duplicate.id,
        'space_id': 'sp1',
        'member_id': duplicate.memberId,
        'type': 'expense',
        'amount_minor': duplicate.amount.minor,
        'currency': 'USD',
        'method': 'bank_card',
        'note': duplicate.note,
        'occurred_at': duplicate.when.toUtc().toIso8601String(),
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await Persistence(db).applyServerRows('tx', [row]);
      state.applyPulled('tx', [row]);

      expect(state.txs.any((t) => t.id == duplicate.id), isFalse);
      final stored = await db.raw.query(
        'tx',
        where: 'id = ?',
        whereArgs: [duplicate.id],
      );
      expect(stored, isEmpty);
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

    test('six-character invite uses secure single-use join RPC', () async {
      server.handler = (request) async {
        final path = request.url.path;
        if (path == '/rest/v1/rpc/join_invite') {
          final body = jsonDecode((request as http.Request).body)
              as Map<String, dynamic>;
          expect(body['p_code'], 'MHRI-ABC123');
          return _json('sp_secure');
        }
        if (request.method == 'GET' && path == '/rest/v1/family_space') {
          return _json([
            {'id': 'sp_secure', 'name': 'Moyo Family'}
          ]);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };

      final ok = await engine.joinSpace(' mhri-abc123 ');

      expect(ok, isTrue);
      expect(kv['space_id'], 'sp_secure');
      expect(kv['space_name'], 'Moyo Family');
      expect(kv.containsKey('invite_code'), isFalse,
          reason: 'single-use codes must never become the family code');
      expect(
        server.sent.any((r) => r.url.path == '/rest/v1/rpc/join_space'),
        isFalse,
      );
    });

    test('restoreFamily distinguishes no family from an unavailable check',
        () async {
      server.handler = (request) async {
        if (request.url.path == '/rest/v1/rpc/restore_my_space') {
          return _json(null);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };
      expect(await engine.restoreFamily(), FamilyRestoreResult.notFound);

      server.handler = (request) async {
        if (request.url.path == '/rest/v1/rpc/restore_my_space') {
          return _json({'message': 'temporarily unavailable'}, 503);
        }
        return _json([]);
      };
      expect(await engine.restoreFamily(), FamilyRestoreResult.unavailable);
      expect(state.onboardingComplete, isFalse);
    });

    test('restoreFamily adopts an existing membership before routing',
        () async {
      server.handler = (request) async {
        final path = request.url.path;
        if (path == '/rest/v1/rpc/restore_my_space') {
          return _json({
            'space_id': 'sp_restored',
            'invite_code': null,
            'name': 'Moyo Family',
          });
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };

      expect(await engine.restoreFamily(), FamilyRestoreResult.restored);
      expect(kv['space_id'], 'sp_restored');
      expect(kv['space_name'], 'Moyo Family');
      expect(state.onboardingComplete, isTrue);
    });

    test('invited adult bypasses the creator family-setup wizard', () async {
      server.handler = (request) async {
        final path = request.url.path;
        if (path == '/rest/v1/rpc/restore_my_space') {
          return _json({
            'space_id': 'sp-invited',
            'invite_code': null,
            'name': 'Shared Family',
          });
        }
        if (request.method == 'GET' && path == '/rest/v1/membership') {
          return _json([
            {
              'space_id': 'sp-invited',
              'user_id': state.user.id,
              'role': 'adult',
              'invite_status': 'active',
            }
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/user_profile') {
          return _json([
            {
              'id': state.user.id,
              'name': 'Tariro',
              'email': 'tariro@example.com'
            },
          ]);
        }
        if (request.method == 'GET' && path == '/rest/v1/family_space') {
          return _json([
            {
              'id': 'sp-invited',
              'name': 'Shared Family',
              'base_currency': 'USD',
              'created_at': '2026-09-28T10:00:00Z',
              'settings': {
                'onboarding_stage': 'spending',
                'primary_currency': 'USD',
              },
            }
          ]);
        }
        if (request.method == 'GET') return _json([]);
        return _json(null, 201);
      };

      expect(await engine.restoreFamily(), FamilyRestoreResult.restored);
      expect(state.user.role, Role.adult);
      expect(state.onboardingComplete, isTrue);
      expect(state.onboardingStage, 'complete');
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
      expect(state.circle.nextCollector, 'Sekuru');
      expect(kv['sync_cursor_chore'], '2026-09-21T09:00:00+00:00');
      expect(kv['sync_cursor_recurring'], '2026-09-21T09:05:00+00:00');
      expect(kv['sync_cursor_mukando'], '2026-09-21T09:10:00+00:00');
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

      // claim the PULLED chore (uuid id, as server rows always are)
      const kid = Member(
        id: 'm_sync_kid',
        name: 'Sync kid',
        emoji: 'child',
        role: Role.kid,
      );
      final owner = state.realUser;
      state.members.add(kid);
      state.switchUser(kid);
      state.setRealUser(kid);
      state.claimChore(
        state.chores.firstWhere((c) => c.id.startsWith('c7b1a2f3')),
      );
      state.switchUser(owner);
      state.setRealUser(owner);
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
              reason: 'pushed id for ${r.url.path} must be uuid');
        }
      }
    });

    test('lists every family membership for the family switcher', () async {
      server.handler = (request) async {
        if (request.url.path == '/rest/v1/rpc/list_my_spaces') {
          return _json([
            {
              'space_id': 'space-home',
              'name': 'Home',
              'role': 'owner',
              'invite_code': 'MHRI-HOME',
            },
            {
              'space_id': 'space-extended',
              'name': 'Extended Family',
              'role': 'adult',
              'invite_code': null,
            },
          ]);
        }
        return _json([]);
      };

      final spaces = await engine.listFamilySpaces();

      expect(spaces.map((space) => space.id), ['space-home', 'space-extended']);
      expect(spaces.first.name, 'Home');
      expect(spaces.last.role, 'adult');
    });
  });
}
