import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../db/persistence.dart';
import '../models/models.dart' show InviteInfo;
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
    this.retryAuth,
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

  /// Forces a token refresh after a 401 and lets [syncNow] retry exactly
  /// once before surfacing "sign in". Null (tests) = no retry.
  final Future<bool> Function()? retryAuth;

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

  // ── parked changes (never silently dropped) ──────────────────────────────
  // A change that failed [maxAttempts] pushes is held back from auto-sync
  // but stays in the outbox. Sync & data lists them with per-item retry
  // and discard — discard is the ONLY way a row leaves besides success,
  // and the UI confirms it first.

  Future<List<OutboxOp>> parked() => _outbox.parked(maxAttempts);

  Future<int> parkedCount() => _outbox.countParked(maxAttempts);

  /// "Try again": clears the failure count so the next sync pushes it.
  Future<void> retryParked(int rowId) => _outbox.resetAttempts(rowId);

  /// Explicit user discard of a parked change (confirmed in the UI).
  Future<void> discardParked(int rowId) => _outbox.deleteRow(rowId);

  // ── reinstall reconciliation (migration 012) ─────────────────────────────

  /// A reinstall (or second phone) has no local kv — no space_id, so the
  /// app would show family setup and the member would have to re-enter a
  /// code or (worse) create a duplicate family. The auth token alone
  /// answers "am I still in a family?" via restore_my_space(); the match
  /// is adopted and full-synced. Never re-creates, never duplicates.
  Future<bool> restoreFamily() async {
    if (_spaceId != null) return true;
    try {
      final r = await client.rpc('restore_my_space', {});
      if (r is! Map || r['space_id'] == null) return false;
      await _adoptSpace(
        id: r['space_id'].toString(),
        code: r['invite_code']?.toString(),
        name: r['name']?.toString(),
      );
      await _fullSync();
      state.markOnboardingRestored();
      return true;
    } catch (e) {
      debugPrint('Mhuri restore error: $e');
      return false;
    }
  }

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
  Future<bool> createSpace(
    String name, {
    String household = 'couple_kids',
    String baseCurrency = 'USD',
    String? preferredName,
  }) async {
    try {
      _setStatus(SyncStatus.syncing);
      final taken = await client.rpc('family_name_taken', {'p_name': name});
      if (taken == true) {
        throw const SyncException(409, 'FAMILY_NAME_TAKEN');
      }
      final result = await client.rpc('create_space', {
        'p_name': name,
        'p_household': household,
        'p_base_currency': baseCurrency,
        'p_preferred_name': preferredName,
      });
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
      debugPrint('Mhuri create-space error: $e');
      _setStatus(SyncStatus.offline, 'Network error — try again.');
      return false;
    }
  }

  /// Inline availability check for the create-family form (005 RPC).
  Future<bool> familyNameTaken(String name) async {
    try {
      return await client.rpc('family_name_taken', {'p_name': name}) == true;
    } catch (_) {
      return false; // unreachable server → let create_space decide
    }
  }

  /// Stores the owner's role-access choices in the family settings. These
  /// settings drive the app experience; database RLS remains authoritative.
  Future<bool> saveRolePermissions(Map<String, bool> permissions) async {
    try {
      await client.rpc('set_role_permissions', {
        'p_permissions': permissions,
      });
      return true;
    } catch (e) {
      debugPrint('Mhuri role-permissions error: $e');
      return false;
    }
  }

  // ── invitations + ownership (migration 010) ──────────────────────────────

  /// Creates a role-bound invite (server: owner-only, max 5 open, 7-day
  /// expiry). Returns the code for the QR/share sheet.
  Future<Map<String, String?>> createInvite(String role,
      {String? email}) async {
    final r = await client.rpc('create_invite', {
      'p_role': role,
      'p_email': email,
    });
    if (r is! Map) {
      throw const SyncException(0, 'unexpected response from server');
    }
    return {'code': r['code']?.toString()};
  }

  /// Pending/accepted invites for the family (owner-read via RLS).
  Future<List<InviteInfo>> listInvites() async {
    final sid = _spaceId;
    if (sid == null) return [];
    final rows = await client.pullRows(
      'family_invite',
      orderCol: 'created_at',
      ascending: false,
      spaceId: sid,
      spaceCol: 'space_id',
      limit: 50,
    );
    DateTime? dt(Object? v) =>
        v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;
    return [
      for (final r in rows)
        InviteInfo(
          id: r['id'].toString(),
          code: (r['code'] ?? '').toString(),
          role: (r['role'] ?? 'adult').toString(),
          email: r['email']?.toString(),
          expiresAt: dt(r['expires_at']),
          acceptedBy: r['accepted_by']?.toString(),
          acceptedAt: dt(r['accepted_at']),
          revokedAt: dt(r['revoked_at']),
        ),
    ];
  }

  Future<void> revokeInvite(String inviteId) =>
      client.rpc('revoke_invite', {'p_id': inviteId});

  /// Hands the family to another active member: roles swap, the family's
  /// static code moves with it, audit row written (migration 010).
  Future<void> transferOwnership(String newOwnerUserId) =>
      client.rpc('transfer_ownership', {'p_new_owner': newOwnerUserId});

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
      final id =
          await client.rpc('join_space', {'p_code': code.trim().toUpperCase()});
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
    // Any list id from a previous family is void — the join path relearns it
    // from the shopping_list header pull; the create path sets it from the
    // RPC result right after this.
    await _kvSet('default_list_id', '');
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
      try {
        await _push();
        await _pull(sid);
      } on SyncException catch (e) {
        // Access token expired mid-session: force one refresh and retry the
        // pass exactly once. Still 401 → rethrown → needsSignIn below.
        if (!e.isAuthError || retryAuth == null) rethrow;
        final refreshed = await retryAuth!();
        if (!refreshed) rethrow;
        await _push();
        await _pull(sid);
      }
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
        await client
            .pushRows(adapter.table, [for (final o in entry.value) o.payload]);
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

  /// The owner's role switches (family_space.settings -> role_permissions)
  /// drive the same gates in the UI that RLS enforces on the server.
  Future<void> _pullFamilySettings() async {
    final sid = _spaceId;
    if (sid == null) return;
    try {
      final rows = await client.pullRows(
        'family_space',
        orderCol: 'created_at',
        eqFilters: {'id': 'eq.$sid'},
        limit: 1,
      );
      if (rows.isEmpty) return;
      final settings = rows.first['settings'];
      final perms = <String, bool>{};
      if (settings is Map) {
        final rp = settings['role_permissions'];
        if (rp is Map) {
          perms.addAll({
            for (final e in rp.entries) e.key.toString(): '${e.value}' == 'true',
          });
        }
      }
      await state.applyRolePermissions(perms);
    } catch (_) {
      // Non-fatal — defaults keep the UI consistent with the server defaults.
    }
  }

  Future<void> _fullSync() async {
    _cursor = null;
    await _push();
    await _pullSince(_spaceId!, null);
    await _pullEnvelopeLinks(); // budget attribution across devices
    await _pullRate(); // latest server FX snapshot (unless user override)
    await _pullMembers(); // family roster: real names for everyone
    await _pullFamilySettings(); // owner's role switches → UI gates
    lastSyncAt = DateTime.now();
    await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
    _setStatus(SyncStatus.idle);
    await state.refreshPending();
  }

  Future<void> _pullSince(String sid, String? since) async {
    var maxCursor = since;
    for (final entity in kPullOrder) {      final adapter = kSyncAdapters[entity]!;
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

  /// Joiners learn the family's default shopping list from the header pull
  /// (creators get the id straight from the create_space RPC). Persisted so
  /// every list_item push is stamped with the real list_id.
  Future<void> _captureDefaultList(List<Map<String, Object?>> rows) async {
    if (rows.isEmpty) return;
    final current = await _kvGet('default_list_id');
    if (current != null && current.isNotEmpty) return;
    for (final r in rows) {
      if (r['deleted_at'] != null) continue;
      if ((r['status'] as String? ?? 'active') != 'active') continue;
      final id = r['id']?.toString();
      if (id != null && id.isNotEmpty) {
        await _kvSet('default_list_id', id);
        return;
      }
    }
  }
}

/// Collision-resistant client id for rows without a natural key
/// (goal_tx contributions): time-ordered, unique per device.
String newClientId() => newUuid();

