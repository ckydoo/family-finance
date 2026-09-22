import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../db/persistence.dart';
import '../state/app_state.dart';
import '../utils/ids.dart';
import 'outbox.dart';
import 'supabase_sync_client.dart';
import 'sync_mappers.dart';

/// M3 sync engine: push outbox → pull changes → apply → advance cursor.
///
///  * offline-first: local writes never wait on the network;
///  * idempotent: pushes are merge-duplicates upserts — safe to replay;
///  * outbox rows store FINAL server-shaped JSON, so push sends them
///    verbatim (no lossy re-encoding; goal_tx ids are fixed at enqueue);
///  * conflicts: last-writer-wins (family scale — see ROADMAP);
///  * connectivity: pull-on-start, debounced sync after mutations, 45s poll
///    while open. (Supabase realtime websocket = M5.)
enum SyncStatus { idle, syncing, offline, needsSignIn, needsSetup, error }

class SyncEngine {
  SyncEngine({
    required this.client,
    required Database database,
    required Persistence persistence,
    required this.state,
    required Future<String?> Function(String key) kvGet,
    required Future<void> Function(String key, String value) kvSet,
  })  : _persistence = persistence,
        _outbox = Outbox(database),
        _kvGet = kvGet,
        _kvSet = kvSet;

  final SupabaseSyncClient client;
  final Persistence _persistence;
  final AppState state;
  final Future<String?> Function(String key) _kvGet;
  final Future<void> Function(String key, String value) _kvSet;
  final Outbox _outbox;

  Timer? _timer;
  Timer? _debounce;
  bool _busy = false;
  String? _cursor; // max updated_at pulled so far (ISO)

  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncAt;

  String? _spaceId;
  String? inviteCode;
  String? spaceName;

  /// M7 reliability: exponential backoff after failed syncs (8s→15min),
  /// poison batches parked after [maxAttempts] failed pushes (retry with
  /// `syncNow(force: true)` — the Members "Sync now" button), and a
  /// pluggable error-report hook (wire Sentry/Crashlytics here in live
  /// mode; optional SENTRY_DSN env stays post-8).
  static const int maxAttempts = 8;
  static void Function(String where, Object error, StackTrace stack)?
      reportError;
  int _consecFail = 0;
  DateTime? _nextPushOkAt;

  String? get spaceId => _spaceId;

  // ── lifecycle ───────────────────────────────────────────────────────────

  Future<void> start() async {
    _cursor = await _kvGet('sync_cursor');
    _spaceId = await _kvGet('space_id');
    spaceName = await _kvGet('space_name');
    inviteCode = await _kvGet('invite_code');

    // Pull-on-start once state hydration has finished.
    state.ready().then((_) {
      if (_spaceId != null) {
        syncNow();
      } else {
        state.refreshPending();
      }
    });

    _timer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_spaceId != null) syncNow();
    });
  }

  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
  }

  Future<int> pendingCount() => _outbox.count();

  /// Debounced auto-sync after mutations.
  void schedule() {
    if (_spaceId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => syncNow());
  }

  /// Enqueue a domain object as final server-shaped JSON. Called by AppState
  /// on every live-mode mutation; nothing waits on the network here.
  Future<void> enqueue(String entity, Object domain) async {
    final sid = _spaceId;
    if (sid == null) return;
    try {
      final adapter = kSyncAdapters[entity]!;
      final payload = adapter.encode(
        domain,
        SyncCtx(
          spaceId: sid,
          defaultListId: await _kvGet('default_list_id'),
          newId: newClientId,
        ),
      );
      await _outbox.enqueue(entity, newClientId(), payload);
      state.refreshPending();
      schedule();
    } catch (e) {
      debugPrint('Mhuri outbox warning: $e');
      reportError?.call('outbox', e, StackTrace.current);
    }
  }

  void _setStatus(SyncStatus s, [String? error]) {
    status = s;
    lastError = error;
    state.syncStatusChanged();
  }

  void _registerFailure(String message, SyncStatus s) {
    _consecFail++;
    _nextPushOkAt = DateTime.now().add(_backoffFor(_consecFail));
    _setStatus(s, message);
  }

  /// 8s, 16s, 32s … capped at 15 minutes.
  Duration _backoffFor(int n) {
    final secs = 8 * (1 << (n > 6 ? 6 : n - 1));
    return Duration(seconds: secs > 900 ? 900 : secs);
  }

  // ── family bootstrap (create / join) ────────────────────────────────────

  /// Creates a family space. Wipes this device's synced tables first so the
  /// device-local rows never leak into the family's server data.
  Future<bool> createSpace(String name,
      {String household = 'couple_kids'}) async {
    try {
      _setStatus(SyncStatus.syncing);
      if (await client
          .rpc('family_name_taken', {'p_name': name}) as bool) {
        throw const SyncException(409, 'FAMILY_NAME_TAKEN');
      }
      final result = await client
          .rpc('create_space', {'p_name': name, 'p_household': household});
      if (result is! Map) {
        throw const SyncException(0, 'unexpected response from server');
      }
      await _adoptSpace(
        id: result['id'].toString(),
        code: result['invite_code']?.toString(),
        name: name,
      );
      await _fullSync();
      return true;
    } on SyncException catch (e) {
      if (e.message.contains('FAMILY_NAME_TAKEN')) {
        _setStatus(SyncStatus.error,
            'FAMILY_NAME_TAKEN: That family name is already taken — try another.');
      } else {
        _setStatus(
          e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
          e.message,
        );
      }
      return false;
    } catch (e) {
      _setStatus(SyncStatus.offline, 'Network error — try again.');
      return false;
    }
  }

  /// Inline availability check for the create-family form (005 RPC).
  Future<bool> familyNameTaken(String name) async {
    try {
      return await client.rpc('family_name_taken', {'p_name': name}) as bool;
    } catch (_) {
      return false; // unreachable server → let create_space decide
    }
  }

  /// Pushes the signed-in member's profile columns (avatar_url, name).
  Future<void> updateMyProfile(Map<String, Object?> values) async {
    final uid = await _kvGet.call('auth_user_id');
    if (uid == null || uid.isEmpty || values.isEmpty) return;
    try {
      _setStatus(SyncStatus.syncing);
      await client.patchRow('user_profile', uid, values);
      _setStatus(SyncStatus.idle);
    } on SyncException catch (e) {
      _setStatus(
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
        e.message,
      );
    } catch (_) {
      _setStatus(SyncStatus.offline, 'Network error — try again.');
    }
  }

  Future<bool> joinSpace(String code) async {
    try {
      _setStatus(SyncStatus.syncing);
      final id = await client
          .rpc('join_space', {'p_code': code.trim().toUpperCase()});
      if (id == null) {
        throw const SyncException(0, 'unexpected response from server');
      }
      await _adoptSpace(
        id: id.toString(),
        code: code.trim().toUpperCase(),
        name: null,
      );
      await _fullSync();
      return true;
    } on SyncException catch (e) {
      if (e.message.contains('INVALID_CODE')) {
        _setStatus(
          SyncStatus.error,
          'That invite code was not found — check it and try again.',
        );
      } else {
        _setStatus(
          e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
          e.message,
        );
      }
      return false;
    } catch (e) {
      _setStatus(SyncStatus.offline, 'Network error — try again.');
      return false;
    }
  }

  Future<void> _adoptSpace({
    required String id,
    required String? code,
    required String? name,
  }) async {
    _spaceId = id;
    if (code != null) {
      inviteCode = code;
      await _kvSet('invite_code', code);
    }
    if (name != null) {
      spaceName = name;
      await _kvSet('space_name', name);
    }
    await _kvSet('space_id', id);
    _cursor = null;

    // Fresh family start on this device: clear synced tables + outbox.
    await _persistence.wipeSynced();
    await _outbox.clear();
    state.onSpaceAdopted(spaceName: name);

    // Join path: the RPC returns only the id — fetch the family's real name
    // (best effort; the UI falls back to the placeholder until this lands).
    if (name == null) {
      try {
        final rows = await client.pullRows(
          'family_space',
          orderCol: 'created_at',
          eqFilters: {'id': 'eq.$id'},
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final fetched = (rows.first['name'] ?? '').toString();
          if (fetched.isNotEmpty) {
            spaceName = fetched;
            await _kvSet('space_name', fetched);
            state.adoptSpaceName(fetched);
          }
        }
      } catch (_) {
        // Offline/name unavailable — placeholder stays; next full sync retries.
      }
    }
  }

  // ── the sync loop ───────────────────────────────────────────────────────

  Future<void> syncNow({bool force = false}) async {
    if (_busy) return;
    final sid = _spaceId;
    if (sid == null) {
      _setStatus(SyncStatus.needsSetup);
      return;
    }
    if (!force &&
        _nextPushOkAt != null &&
        DateTime.now().isBefore(_nextPushOkAt!)) {
      return; // backing off — the periodic poll will try again
    }
    _busy = true;
    _setStatus(SyncStatus.syncing);
    try {
      await _push();
      await _pull(sid);
      lastSyncAt = DateTime.now();
      await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
      _consecFail = 0;
      _nextPushOkAt = null;
      _setStatus(SyncStatus.idle);
    } on SyncException catch (e) {
      _registerFailure(
        e.message,
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
      );
      reportError?.call('sync', e, StackTrace.current);
    } catch (e, st) {
      _registerFailure('Network error — will retry.', SyncStatus.offline);
      debugPrint('Mhuri sync offline: $e');
      reportError?.call('sync', e, st);
    } finally {
      _busy = false;
      await state.refreshPending();
    }
  }

  /// Ordered, grouped, verbatim push. A failed entity batch stays in the
  /// outbox (attempts++) and retries on the next sync.
  Future<void> _push({bool force = false}) async {
    final taken = await _outbox.take(200);
    if (taken.isEmpty) return;
    final cutoff = force ? 1 << 30 : SyncEngine.maxAttempts;
    final ops = [
      for (final op in taken)
        if (op.attempts < cutoff) op,
    ];
    final parked = taken.length - ops.length;
    if (parked > 0) {
      reportError?.call(
        'push',
        'parked $parked op(s) after $maxAttempts+ failed attempts',
        StackTrace.current,
      );
    }
    if (ops.isEmpty) {
      throw SyncException(
        0,
        '$parked change(s) are parked — use "Sync now" to retry them.',
      );
    }

    final byEntity = <String, List<OutboxOp>>{};
    for (final op in ops) {
      byEntity.putIfAbsent(op.entity, () => []).add(op);
    }

    var allOk = true;
    final doneRowIds = <int>[];
    for (final entry in byEntity.entries) {
      final adapter = kSyncAdapters[entry.key]!;
      try {
        await client.pushRows(adapter.table, [for (final o in entry.value) o.payload]);
        doneRowIds.addAll(entry.value.map((o) => o.rowId));
        // Sprint B: budget attribution rides with transaction pushes — the
        // server models it as the envelope_tx junction (no envelope_id col).
        if (entry.key == 'tx') {
          final byId = {for (final t in state.txs) t.id: t};
          final links = <Map<String, Object?>>[
            for (final o in entry.value)
              if (byId[o.payload['id']]?.envelopeId case final envId?
                  when envId.isNotEmpty)
                {
                  'envelope_id': envId,
                  'transaction_id': o.payload['id'],
                  'allocated_minor': byId[o.payload['id']]!.amount.minor,
                  'currency': byId[o.payload['id']]!.amount.currency.name,
                },
          ];
          if (links.isNotEmpty) {
            await client.pushRows('envelope_tx', links);
          }
        }
      } on SyncException {
        allOk = false;
      }
    }

    if (doneRowIds.isNotEmpty) await _outbox.deleteRows(doneRowIds);
    if (!allOk) {
      await _outbox.bumpAttempts([for (final op in ops) op.rowId]);
      throw const SyncException(0, 'some changes have not been pushed yet');
    }
  }

  Future<void> _pull(String sid) => _pullSince(sid, _cursor);

  /// Full resync (right after adopting a space): forget the cursor, pull all.
  /// Pulls the envelope_tx junction and mirrors it into local tx.envelopeId,
  /// so budget attribution follows the family across devices. Full-refresh
  /// semantics: the server is the truth for links (upserts are idempotent,
  /// conflicts are rare single-field edits).
  Future<void> _pullEnvelopeLinks() async {
    try {
      final envIds = state.envelopes.map((e) => e.id).toList();
      if (envIds.isEmpty) return;
      final rows = await client.pullRows(
        'envelope_tx',
        orderCol: 'envelope_id',
        eqFilters: {'envelope_id': 'in.(${envIds.join(',')})'},
        limit: 2000,
      );
      final links = <String, String>{
        for (final r in rows)
          r['transaction_id'].toString(): r['envelope_id'].toString(),
      };
      await state.applyEnvelopeLinks(links);
    } catch (_) {
      // Non-fatal: attribution stays device-local until the next sync.
    }
  }

  /// Latest rbz snapshot wins unless the user set a custom rate. Falls back
  /// to the persisted server rate on next boot.
  Future<void> _pullRate() async {
    try {
      final rows = await client.pullRows(
        'rate_snapshot',
        orderCol: 'captured_at',
        ascending: false,
        limit: 1,
      );
      if (rows.isEmpty) return;
      final v = (rows.first['usd_zwg'] as num?)?.toDouble();
      if (v == null || v <= 0) return;
      await state.applyServerRate(v);
    } catch (_) {
      // Rate stays as-is offline — never blocks sync status.
    }
  }

  /// Pulls the family roster (membership + user_profile) so every family
  /// member's data can display with a real name. Best effort — identity
  /// already works from the local bootstrap; this enriches it.
  Future<void> _pullMembers() async {
    try {
      final sid = _spaceId;
      if (sid == null) return;
      final membership = await client.pullRows(
        'membership',
        orderCol: 'user_id',
        eqFilters: {'space_id': 'eq.$sid'},
      );
      if (membership.isEmpty) return;
      final ids = [
        for (final r in membership) r['user_id'].toString(),
      ];
      final profiles = await client.pullRows(
        'user_profile',
        orderCol: 'id',
        eqFilters: {'id': 'in.(${ids.join(',')})'},
      );
      final list = membersFromServer(
        membershipRows: membership,
        profileRows: profiles,
        meId: state.user.id,
      );
      await state.setFamilyMembers(list);
    } catch (_) {
      // RLS/network hiccup — local identity remains; retried next full sync.
    }
  }

  Future<void> _fullSync() async {
    _cursor = null;
    await _push();
    await _pullSince(_spaceId!, null);
    await _pullEnvelopeLinks(); // budget attribution across devices
    await _pullRate(); // latest server FX snapshot (unless user override)
    await _pullMembers(); // family roster: real names for everyone
    lastSyncAt = DateTime.now();
    await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
    _setStatus(SyncStatus.idle);
    await state.refreshPending();
  }

  Future<void> _pullSince(String sid, String? since) async {
    var maxCursor = since;
    for (final entity in kPullOrder) {
      final adapter = kSyncAdapters[entity]!;
      final rows = await client.pullRows(
        adapter.table,
        orderCol: 'updated_at',
        sinceIso: since,
        spaceId: adapter.spaceScoped ? sid : null,
        spaceCol: adapter.spaceScoped ? 'space_id' : null,
      );
      if (rows.isEmpty) continue;
      for (final row in rows) {
        final ua = row['updated_at'];
        if (ua is String &&
            (maxCursor == null || ua.compareTo(maxCursor) > 0)) {
          maxCursor = ua;
        }
      }
      await _persistence.applyServerRows(entity, rows);
      state.applyPulled(entity, rows);
    }
    if (maxCursor != null && maxCursor != since) {
      _cursor = maxCursor;
      await _kvSet('sync_cursor', maxCursor);
    }
  }
}

/// Collision-resistant client id for rows without a natural key
/// (goal_tx contributions): time-ordered, unique per device.
String newClientId() => newUuid();
