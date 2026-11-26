import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show ConflictAlgorithm, Database, Transaction;

import '../db/persistence.dart';
import '../models/models.dart' show FamilyChatMessage, Goal, InviteInfo, Role;
import '../money/money.dart';
import '../state/app_state.dart';
import '../utils/ids.dart';
import 'outbox.dart';
import '../observability/reporter.dart';
import '../billing/entitlement.dart';
import 'realtime_sync_signal.dart';
import 'receipt_storage_service.dart';
import 'supabase_sync_client.dart';
import 'sync_mappers.dart';

/// M3 sync engine: push outbox → pull changes → apply → advance cursor.
///
///  * offline-first: local writes never wait on the network;
///  * idempotent: pushes are merge-duplicates upserts - safe to replay;
///  * outbox rows store FINAL server-shaped JSON, so push sends them
///    verbatim (no lossy re-encoding; goal_tx ids are fixed at enqueue);
///  * conflicts: last-writer-wins (family scale - see ROADMAP);
///  * connectivity: pull-on-start, event-driven refresh from family pushes,
///    debounced sync after mutations, and a short fallback poll.
enum SyncStatus {
  idle,
  syncing,
  offline,
  needsSignIn,
  needsSetup,
  needsReview,
  error,
}

/// Result of resolving the signed-in account's family before routing.
/// [unavailable] is deliberately distinct from [notFound]: a network failure
/// must never send an existing member to the create-family flow.
enum FamilyRestoreResult { restored, notFound, unavailable }

@immutable
class FamilySpaceSummary {
  const FamilySpaceSummary({
    required this.id,
    required this.name,
    required this.role,
    this.inviteCode,
  });

  final String id;
  final String name;
  final String role;
  final String? inviteCode;

  factory FamilySpaceSummary.fromJson(Map<Object?, Object?> json) =>
      FamilySpaceSummary(
        id: '${json['space_id'] ?? json['id']}',
        name: '${json['name'] ?? 'Family'}',
        role: '${json['role'] ?? 'adult'}',
        inviteCode: json['invite_code']?.toString(),
      );
}

@immutable
class FamilyCreationStatus {
  const FamilyCreationStatus({
    required this.ownedSpaces,
    required this.hasPlus,
    required this.canCreate,
  });

  final int ownedSpaces;
  final bool hasPlus;
  final bool canCreate;

  factory FamilyCreationStatus.fromJson(Map<Object?, Object?> json) =>
      FamilyCreationStatus(
        ownedSpaces: int.tryParse('${json['owned_spaces'] ?? 0}') ?? 0,
        hasPlus: json['has_plus'] == true,
        canCreate: json['can_create'] == true,
      );
}

class SyncEngine {
  SyncEngine({
    required this.client,
    required Database database,
    required Persistence persistence,
    required this.state,
    required Future<String?> Function(String key) kvGet,
    required Future<void> Function(String key, String value) kvSet,
    this.retryAuth,
    this.autoSchedule = true,
    this.useBatchProtocol,
    this.receiptStorage,
    bool? enableRealtime,
    RealtimeSocketConnector? realtimeConnector,
  })  : _persistence = persistence,
        _database = database,
        _outbox = Outbox(database),
        _kvGet = kvGet,
        _kvSet = kvSet,
        _enableRealtime = enableRealtime ?? !client.hasCustomHttpClient {
    if (_enableRealtime && autoSchedule) {
      _realtime = RealtimeSyncSignal(
        baseUrl: client.baseUrl,
        anonKey: client.anonKey,
        tokenGet: client.currentToken,
        connector: realtimeConnector,
        onConnected: () {
          _restartForegroundTimer();
          if (_spaceId != null && _foregroundActive) {
            unawaited(syncNow());
          }
        },
        onSignal: (remoteSeq) {
          final sid = _spaceId;
          if (sid == null || !_foregroundActive) return;
          final known = _lastKnownSignalSeq[sid];
          if (remoteSeq != null && known != null && remoteSeq <= known) {
            return;
          }
          unawaited(syncNow());
        },
      );
    }
  }

  final SupabaseSyncClient client;
  final Persistence _persistence;
  final Database _database;
  final AppState state;
  final Future<String?> Function(String key) _kvGet;
  final Future<void> Function(String key, String value) _kvSet;
  final Outbox _outbox;
  final bool autoSchedule;

  /// Explicit Sync Protocol v2 override (`push_sync_ops` + `pull_family_changes`).
  /// When null, protocol v2 is auto-detected from space RPC metadata or
  /// `family_space.sync_seq` and cached per space in KV.
  final bool? useBatchProtocol;
  final bool _enableRealtime;
  RealtimeSyncSignal? _realtime;

  /// Forces a token refresh after a 401 and lets [syncNow] retry exactly
  /// once before surfacing "sign in". Null (tests) = no retry.
  final Future<bool> Function()? retryAuth;

  /// Optional private `receipts` Storage bridge (#1). Null (unit tests) =
  /// staged offline receipt photos stay device-local and are simply skipped.
  final ReceiptStorageService? receiptStorage;

  Timer? _timer;
  Timer? _debounce;
  Timer? _reconcileTimer;
  Future<void>? _activeSync;
  Future<void>? _activeChatRefresh;
  bool _reconciling = false;
  bool _foregroundActive = true;
  bool _started = false;

  final Set<String> _v2Spaces = <String>{};
  final Map<String, int> _lastKnownSignalSeq = <String, int>{};

  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncAt;

  String? _spaceId;
  String? inviteCode;
  String? spaceName;
  bool _spaceIdentityLoaded = false;
  bool _familySetupResolutionComplete = false;

  /// Reliability: exponential backoff after failed syncs (8s→30s), with
  /// every queued write retried indefinitely. [maxAttempts] is only the point
  /// at which a repeatedly rejected row is surfaced in Sync & data; it never
  /// stops automatic delivery.
  static const int maxAttempts = 8;
  static void Function(String where, Object error, StackTrace stack)?
      reportError;
  int _consecFail = 0;
  DateTime? _nextPushOkAt;

  String? get spaceId => _spaceId;
  bool get spaceIdentityLoaded => _spaceIdentityLoaded;
  bool get familySetupResolutionComplete => _familySetupResolutionComplete;
  bool get isRealtimeConnected => _realtime?.isConnected ?? false;

  bool _isSyncV2(String sid) =>
      useBatchProtocol ?? _v2Spaces.contains(sid);

  Future<void> _enableSyncV2ForSpace(String sid) async {
    if (sid.isEmpty || useBatchProtocol == false) return;
    if (_v2Spaces.add(sid)) {
      await _kvSet('sync_cursor_proto_v2_$sid', '1');
      _restartForegroundTimer();
    }
  }

  Future<void> _disableSyncV2ForSpace(String sid) async {
    if (_v2Spaces.remove(sid)) {
      await _kvSet('sync_cursor_proto_v2_$sid', '');
      _restartForegroundTimer();
    }
  }

  void _recordKnownSeq(String sid, int? seq) {
    if (seq == null || seq <= 0) return;
    final prev = _lastKnownSignalSeq[sid];
    if (prev == null || seq > prev) {
      _lastKnownSignalSeq[sid] = seq;
    }
  }

  Duration _pollInterval() {
    final sid = _spaceId;
    if (sid != null && _isSyncV2(sid)) {
      return isRealtimeConnected
          ? const Duration(seconds: 20)
          : const Duration(seconds: 8);
    }
    return const Duration(seconds: 5);
  }

  void _restartForegroundTimer() {
    _timer?.cancel();
    _timer = null;
    if (!autoSchedule || !_started || !_foregroundActive) return;
    _timer = Timer.periodic(_pollInterval(), (_) {
      if (_spaceId != null && _foregroundActive) syncNow();
    });
  }

  /// Pauses background polling and WebSocket activity while the app is
  /// backgrounded, and reconnects + catches up immediately on resume.
  void setForegroundActive(bool active) {
    if (_foregroundActive == active) return;
    _foregroundActive = active;
    _realtime?.configure(spaceId: _spaceId, active: active);
    _restartForegroundTimer();
    if (active && _spaceId != null) {
      unawaited(syncNow());
    }
  }

  void disconnectRealtime() {
    _realtime?.configure(spaceId: _spaceId, active: false);
  }

  // ── lifecycle ───────────────────────────────────────────────────────────

  Future<void> start() async {
    _started = true;
    _spaceIdentityLoaded = false;
    _familySetupResolutionComplete = false;
    state.syncIdentityChanged();
    _spaceId = await _kvGet('space_id');
    spaceName = await _kvGet('space_name');
    inviteCode = await _kvGet('invite_code');
    if (_spaceId != null && _spaceId!.isNotEmpty) {
      if (await _kvGet('sync_cursor_proto_v2_${_spaceId!}') == '1') {
        _v2Spaces.add(_spaceId!);
      }
    }
    _spaceIdentityLoaded = true;
    _familySetupResolutionComplete = _spaceId != null;
    state.syncIdentityChanged();

    if (!autoSchedule) return;

    _realtime?.configure(spaceId: _spaceId, active: _foregroundActive);

    // Pull-on-start once state hydration has finished.
    final bootSync = state.ready().then((_) async {
      if (_spaceId != null) {
        await _syncOrReconcile();
      } else {
        await state.refreshPending();
      }
    });
    state.db?.trackWrite(bootSync);

    _restartForegroundTimer();
    // Cursor sync is efficient, while a periodic full snapshot makes it
    // self-healing if OS backup/restore resurrects a cursor without all of
    // its corresponding rows. The versioned marker also forces one complete
    // reconciliation after this reliability fix ships.
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer.periodic(const Duration(hours: 6), (_) {
      if (_spaceId != null && _foregroundActive) _syncOrReconcile();
    });
  }

  static const _reconcileVersion = 2;
  static const _reconcileInterval = Duration(hours: 24);

  String get _reconcileKey =>
      'full_reconcile_v$_reconcileVersion' '_${_spaceId ?? ''}';

  Future<void> _syncOrReconcile() async {
    final raw = await _kvGet(_reconcileKey);
    final lastMs = int.tryParse(raw ?? '');
    final now = DateTime.now();
    final last =
        lastMs == null ? null : DateTime.fromMillisecondsSinceEpoch(lastMs);
    final due = last == null ||
        last.isAfter(now.add(const Duration(hours: 1))) ||
        now.difference(last) >= _reconcileInterval;
    if (due) {
      await reloadAllFamilyData(automatic: true);
    } else {
      await syncNow();
    }
  }

  /// One SQLite database is shared by installations, not by identities.
  /// Before a newly authenticated user can restore a family, remove the
  /// previous user's family rows, pending writes, identifiers and cursors.
  Future<void> ensureUserIsolation(String userId, {String? email}) async {
    final cachedUser = await _kvGet('cached_family_user_id');
    final hasFamily =
        (_spaceId ?? await _kvGet('space_id'))?.isNotEmpty == true;
    final localMember = await _kvGet('me_id');
    final belongsToAnotherUser =
        cachedUser != null && cachedUser.isNotEmpty && cachedUser != userId;
    final legacyMismatch = cachedUser == null &&
        hasFamily &&
        localMember != null &&
        localMember.isNotEmpty &&
        localMember != userId;
    if (belongsToAnotherUser || legacyMismatch) {
      _realtime?.configure(spaceId: null, active: false);
      _spaceIdentityLoaded = false;
      _familySetupResolutionComplete = false;
      state.syncIdentityChanged();
      final previousUser =
          cachedUser?.isNotEmpty == true ? cachedUser! : (localMember ?? '');
      final previousKv = await state.db?.activeFamilyKv() ?? const {};
      if (previousUser.isNotEmpty) {
        await state.db?.parkAccountData(previousUser);
      }
      _spaceId = null;
      spaceName = null;
      inviteCode = null;
      await state.db?.clearActiveAccountData();
      for (final key in previousKv.keys) {
        await _kvSet(key, '');
      }
      state.resetForAccount(userId, email: email);
      final restored = await state.db?.restoreAccountData(userId) ?? false;
      if (restored) {
        final restoredKv = await state.db?.activeFamilyKv() ?? const {};
        for (final entry in restoredKv.entries) {
          await _kvSet(entry.key, entry.value);
        }
        _spaceId = await _kvGet('space_id');
        spaceName = await _kvGet('space_name');
        inviteCode = await _kvGet('invite_code');
        if (_spaceId != null &&
            await _kvGet('sync_cursor_proto_v2_${_spaceId!}') == '1') {
          _v2Spaces.add(_spaceId!);
        }
        await state.refresh();
      }
      _realtime?.configure(spaceId: _spaceId, active: _foregroundActive);
      _spaceIdentityLoaded = true;
      _familySetupResolutionComplete = _spaceId != null;
      state.syncIdentityChanged();
    }
    await _kvSet('cached_family_user_id', userId);
  }

  void dispose() {
    _started = false;
    _timer?.cancel();
    _debounce?.cancel();
    _reconcileTimer?.cancel();
    _realtime?.dispose();
  }

  Future<int> pendingCount() => _outbox.count();

  // ── parked changes (never silently dropped) ──────────────────────────────
  // A change that failed [maxAttempts] pushes is surfaced in Sync & data but
  // remains part of every automatic retry. It is never silently dropped.

  Future<List<OutboxOp>> parked() => _outbox.parked(maxAttempts);

  Future<List<OutboxOp>> conflicts() => _outbox.conflicts();

  Future<int> conflictCount() => _outbox.countConflicts();

  Future<void> keepLocalConflict(int rowId) async {
    final conflict = (await _outbox.conflicts())
        .where((value) => value.rowId == rowId)
        .firstOrNull;
    final updatedAt = conflict?.serverPayload?['updated_at']?.toString();
    if (updatedAt == null || updatedAt.isEmpty) {
      throw const SyncException(
          409, 'The server version is missing. Reload family data first.');
    }
    await _outbox.rebaseConflict(rowId, updatedAt);
  }

  Future<void> acceptServerConflict(OutboxOp op) async {
    final server = op.serverPayload;
    if (server == null) return;
    await _persistence.applyServerRows(
      op.entity,
      [server],
      allowOverwriteDirty: true,
    );
    state.applyPulled(op.entity, [server]);
    await _outbox.deleteRow(op.rowId);
    await state.refreshPending();
    if (await _outbox.countConflicts() == 0) {
      _setStatus(SyncStatus.idle);
    }
  }

  Future<int> parkedCount() => _outbox.countParked(maxAttempts);

  /// "Try again": clears the failure count so the next sync pushes it.
  Future<void> retryParked(int rowId) {
    mhuriEvent('parked.retry', {'row': rowId});
    return _outbox.resetAttempts(rowId);
  }

  /// "Try again all": clears failure count for all parked changes so next sync pushes them.
  Future<void> retryAllParked() {
    mhuriEvent('parked.retry_all', {});
    return _outbox.resetAllAttempts();
  }

  /// Explicit user discard of a parked change (confirmed in the UI).
  Future<void> discardParked(int rowId) {
    mhuriEvent('parked.discard', {'row': rowId});
    return _outbox.deleteRow(rowId);
  }

  // ── reinstall reconciliation (migration 012) ─────────────────────────────

  /// A reinstall (or second phone) has no local kv - no space_id, so the
  /// app would show family setup and the member would have to re-enter a
  /// code or (worse) create a duplicate family. The auth token alone
  /// answers "am I still in a family?" via restore_my_space(); the match
  /// is adopted and full-synced. Never re-creates, never duplicates.
  Future<FamilyRestoreResult> restoreFamily() async {
    if (_spaceId != null) {
      _setFamilySetupResolutionComplete();
      return FamilyRestoreResult.restored;
    }
    _familySetupResolutionComplete = false;
    state.syncIdentityChanged();
    try {
      final r = await client.rpc('restore_my_space', {});
      if (r is! Map || r['space_id'] == null) {
        _setFamilySetupResolutionComplete();
        return FamilyRestoreResult.notFound;
      }
      final sid = r['space_id'].toString();
      if ((r['sync_protocol'] as num?)?.toInt() == 2) {
        await _enableSyncV2ForSpace(sid);
      }
      await _adoptSpace(
        id: sid,
        code: r['invite_code']?.toString(),
        name: r['name']?.toString(),
      );
      await _fullSync();
      // Established families created before staged onboarding have no stage
      // marker. Treat only that legacy/absent state as complete; a persisted
      // currencies/spending/ready stage must continue to resume.
      if (state.onboardingStage == 'create') {
        state.markOnboardingRestored();
      }
      _setFamilySetupResolutionComplete();
      return FamilyRestoreResult.restored;
    } catch (e) {
      debugPrint('Mhuri restore error: $e');
      return FamilyRestoreResult.unavailable;
    }
  }

  void _setFamilySetupResolutionComplete() {
    _familySetupResolutionComplete = true;
    state.syncIdentityChanged();
  }

  /// Every active family membership for the signed-in account.
  Future<List<FamilySpaceSummary>> listFamilySpaces() async {
    final result = await client.rpc('list_my_spaces', {});
    if (result is! List) return const [];
    final rows = result.whereType<Map>().toList(growable: false);
    for (final row in rows) {
      final sid = '${row['space_id'] ?? row['id'] ?? ''}';
      if (sid.isNotEmpty &&
          sid != 'null' &&
          (row['sync_protocol'] as num?)?.toInt() == 2) {
        await _enableSyncV2ForSpace(sid);
      }
    }
    return rows
        .map((row) => FamilySpaceSummary.fromJson(row))
        .where((space) => space.id.isNotEmpty && space.id != 'null')
        .toList(growable: false);
  }

  Future<FamilyCreationStatus> familyCreationStatus() async {
    final result = await client.rpc('family_creation_status', {});
    if (result is! Map) {
      throw const SyncException(0, 'unexpected response from server');
    }
    return FamilyCreationStatus.fromJson(result);
  }

  /// Changes the active family without ever mixing local rows. Pending writes
  /// must reach the old family first; only then is its local partition wiped
  /// and the selected family pulled from the server.
  Future<bool> switchFamilySpace(FamilySpaceSummary target) async {
    if (target.id == _spaceId) return true;
    try {
      await syncNow(force: true);
      if (await _outbox.count() != 0) {
        _setStatus(SyncStatus.offline,
            'Connect and sync pending changes before switching families.');
        return false;
      }
      _setStatus(SyncStatus.syncing);
      await _adoptSpace(
        id: target.id,
        code: target.inviteCode,
        name: target.name,
      );
      await _fullSync();
      return true;
    } on SyncException catch (e) {
      _setStatus(
          e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error, e.message);
      return false;
    } catch (_) {
      _setStatus(SyncStatus.offline,
          'Could not switch families. Check your connection and try again.');
      return false;
    }
  }

  /// Debounced auto-sync after mutations.
  void schedule() {
    if (!autoSchedule || _spaceId == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => syncNow());
  }

  /// Enqueue a domain object as final server-shaped JSON. Called by AppState
  /// on every live-mode mutation; nothing waits on the network here.
  /// [triggerSchedule] can be false when the caller is already inside a sync
  /// cycle (e.g. receipt promotion during [_push]) and a debounced re-sync
  /// would only add churn.
  Future<void> enqueue(String entity, Object domain,
      {Object? base, bool triggerSchedule = true}) async {
    final sid = _spaceId;
    if (sid == null) return;
    try {
      final adapter = kSyncAdapters[entity]!;
      final ctx = SyncCtx(
        spaceId: sid,
        actorId: state.realUser.id,
        defaultListId: await _kvGet('default_list_id'),
        newId: newClientId,
      );
      final payload = adapter.encode(domain, ctx);
      final encodedBase = base == null ? null : adapter.encode(base, ctx);
      final basePayload =
          await _stampBaseVersion(entity, payload, encodedBase: encodedBase);
      await _outbox.enqueue(entity, newClientId(), payload,
          basePayload: basePayload);
      state.refreshPending();
      if (triggerSchedule) schedule();
    } catch (e) {
      debugPrint('Mhuri outbox warning: $e');
      reportError?.call('outbox', e, StackTrace.current);
    }
  }

  /// Atomically queues related domain writes so an offline retry cannot send
  /// only one half of a multi-row financial operation.
  Future<void> _enqueueBatchImpl(
    List<(String, Object, Object?)> mutations, {
    Future<void> Function(Transaction txn)? persist,
  }) async {
    final sid = _spaceId;
    if (sid == null || mutations.isEmpty) return;
    try {
      final defaultListId = await _kvGet('default_list_id');
      final ctx = SyncCtx(
        spaceId: sid,
        actorId: state.realUser.id,
        defaultListId: defaultListId,
        newId: newClientId,
      );
      final operations = <({
        String entity,
        String opId,
        Map<String, Object?> payload,
        Map<String, Object?>? basePayload,
      })>[];
      for (final (entity, domain, base) in mutations) {
        final adapter = kSyncAdapters[entity]!;
        final payload = adapter.encode(domain, ctx);
        final encodedBase = base == null ? null : adapter.encode(base, ctx);
        final basePayload =
            await _stampBaseVersion(entity, payload, encodedBase: encodedBase);
        operations.add((
          entity: entity,
          opId: newClientId(),
          payload: payload,
          basePayload: basePayload,
        ));
      }
      await _outbox.enqueueBatch(operations, persist: persist);
      await state.refreshPending();
      schedule();
    } catch (e) {
      debugPrint('Mhuri outbox batch warning: $e');
      reportError?.call('outbox', e, StackTrace.current);
    }
  }

  /// Enqueue related mutations. Each entry is (entity, domain, base) where
  /// [base] is the row as it was before the edit (for server-authoritative
  /// merge). Pass null for new rows.
  Future<void> enqueueBatch(
    List<(String, Object, Object?)> mutations, {
    Future<void> Function(Transaction txn)? persist,
  }) =>
      _enqueueBatchImpl(mutations, persist: persist);

  Future<Map<String, Object?>?> _stampBaseVersion(
    String entity,
    Map<String, Object?> payload, {
    Map<String, Object?>? encodedBase,
  }) async {
    final id = payload['id']?.toString();
    if (id == null || id.isEmpty) {
      return encodedBase;
    }
    final versions = await _database.query(
      'sync_version',
      columns: ['server_updated_at', 'server_payload'],
      where: 'entity = ? AND row_id = ?',
      whereArgs: [entity, id],
      limit: 1,
    );
    if (versions.isNotEmpty) {
      if (_conflictEntities.contains(entity) || encodedBase != null) {
        payload['_base_updated_at'] =
            versions.first['server_updated_at']?.toString();
      }
      if (encodedBase != null) {
        final rawServer = versions.first['server_payload']?.toString();
        if (rawServer != null && rawServer.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawServer);
            if (decoded is Map) {
              return <String, Object?>{
                for (final entry in decoded.entries)
                  entry.key.toString(): entry.value,
                ...encodedBase,
              };
            }
          } catch (_) {}
        }
      }
      return encodedBase;
    }
    // A list item can be created safely without a base version (insert-only).
    // Existing legacy rows need a server version before they can be edited;
    // otherwise stale local state could masquerade as a new insert.
    if (entity == 'list_item' &&
        _conflictEntities.contains(entity) &&
        !_isSyncV2(_spaceId ?? '')) {
      final remoteRows = await client.pullRows(
        'list_item',
        orderCol: 'updated_at',
        eqFilters: {'id': 'eq.$id'},
        limit: 1,
      );
      final remote = remoteRows.firstOrNull;
      if (remote != null) {
        final serverVersion = remote['updated_at']?.toString();
        if (serverVersion != null && serverVersion.isNotEmpty) {
          payload['_base_updated_at'] = serverVersion;
          await _database.insert(
            'sync_version',
            {
              'entity': entity,
              'row_id': id,
              'server_updated_at': serverVersion,
              'server_payload': jsonEncode(remote),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          if (encodedBase != null) {
            return <String, Object?>{...remote, ...encodedBase};
          }
        }
      }
    }
    return encodedBase;
  }

  /// Chat is latency-sensitive and deliberately bypasses the offline outbox.
  /// The caller gets an immediate success/failure result and can expose retry.
  Future<bool> sendChatMessage(Object domain) async {
    final sid = _spaceId;
    if (sid == null) return false;
    final adapter = kSyncAdapters['family_chat_message']!;
    final payload = adapter.encode(
      domain,
      SyncCtx(
        spaceId: sid,
        actorId: state.realUser.id,
        // Chat rows never use a shopping-list id. Avoid an unrelated SQLite
        // read on the latency-sensitive send path.
        defaultListId: null,
        newId: newClientId,
      ),
    );
    try {
      await client.pushRows(adapter.table, [payload]);
      return true;
    } on SyncException catch (error) {
      debugPrint(
          'Mhuri chat send rejected (${error.statusCode}): ${error.message}');
      reportError?.call('chat:send', error, StackTrace.current);
      if (error.statusCode == 401 && retryAuth != null && await retryAuth!()) {
        try {
          await client.pushRows(adapter.table, [payload]);
          return true;
        } catch (retryError, retryStack) {
          debugPrint('Mhuri chat send retry failed: $retryError');
          reportError?.call('chat:send_retry', retryError, retryStack);
          return false;
        }
      }
      return false;
    } catch (error, stack) {
      debugPrint('Mhuri chat send failed: $error');
      reportError?.call('chat:send', error, stack);
      return false;
    }
  }

  /// Pull only new chat rows while the conversation is visible.
  ///
  /// The normal sync intentionally covers the entire family data graph and
  /// can take several requests. Chat must not wait behind that work. This
  /// small cursor-based pull is idempotent and safely overlaps normal sync.
  Future<void> refreshChat() {
    final active = _activeChatRefresh;
    if (active != null) return active;
    final run = _refreshChatNow();
    _activeChatRefresh = run;
    return run.whenComplete(() {
      if (identical(_activeChatRefresh, run)) _activeChatRefresh = null;
    });
  }

  Future<void> _refreshChatNow() async {
    final sid = _spaceId;
    if (sid == null) return;
    const entity = 'family_chat_message';
    const key = 'sync_cursor_family_chat_message';
    final adapter = kSyncAdapters[entity]!;
    final stored = await _kvGet(key);
    final since = stored == null || stored.isEmpty
        ? null
        : (DateTime.tryParse(stored)
                ?.subtract(const Duration(milliseconds: 1))
                .toUtc()
                .toIso8601String() ??
            stored);
    try {
      final rows = await client.pullRows(
        adapter.table,
        orderCol: 'updated_at',
        sinceIso: since,
        spaceId: sid,
        spaceCol: 'space_id',
        limit: 200,
      );
      if (rows.isEmpty) return;
      final dirtyIds = await _outbox.dirtyRowIdsForEntity(entity);
      await _persistence.applyServerRows(entity, rows, dirtyIds: dirtyIds);
      final cleanRows = dirtyIds.isEmpty
          ? rows
          : [
              for (final row in rows)
                if (!dirtyIds.contains('${row['id'] ?? ''}')) row,
            ];
      if (cleanRows.isNotEmpty) {
        state.applyPulled(entity, cleanRows);
      }
      String? maxCursor = since;
      for (final row in rows) {
        final updatedAt = row['updated_at'];
        if (updatedAt is String &&
            (maxCursor == null || updatedAt.compareTo(maxCursor) > 0)) {
          maxCursor = updatedAt;
        }
      }
      if (maxCursor != null) await _kvSet(key, maxCursor);
    } catch (error, stack) {
      // The regular sync and Firebase wake-up remain fallbacks. A transient
      // foreground refresh failure must not turn the whole app red/offline.
      reportError?.call('chat:refresh', error, stack);
    }
  }

  void _setStatus(SyncStatus s, [String? error]) {
    if (status == s && lastError == error) return;
    status = s;
    lastError = error;
    state.syncStatusChanged();
  }

  void _registerFailure(String message, SyncStatus s) {
    _consecFail++;
    _nextPushOkAt = DateTime.now().add(_backoffFor(_consecFail));
    _setStatus(s, message);
  }

  /// 8s, 16s, 30s … capped at 30 seconds.
  Duration _backoffFor(int n) {
    final secs = 8 * (1 << (n > 6 ? 6 : n - 1));
    return Duration(seconds: secs > 30 ? 30 : secs);
  }

  // ── family bootstrap (create / join) ────────────────────────────────────

  Future<bool> _flushBeforeChangingSpace() async {
    if (_spaceId == null) return true;
    await syncNow(force: true);
    if (await _outbox.count() == 0) return true;
    _setStatus(SyncStatus.offline,
        'Connect and sync pending changes before changing families.');
    return false;
  }

  /// Creates a family space. Wipes this device's synced tables first so the
  /// device-local rows never leak into the family's server data.
  Future<bool> createSpace(
    String name, {
    String household = 'couple_kids',
    String baseCurrency = 'USD',
    String? preferredName,
    bool additional = false,
  }) async {
    try {
      if (!await _flushBeforeChangingSpace()) return false;
      _setStatus(SyncStatus.syncing);
      final taken = await client.rpc('family_name_taken', {'p_name': name});
      if (taken == true) {
        throw const SyncException(409, 'FAMILY_NAME_TAKEN');
      }
      final result = await client
          .rpc(additional ? 'create_additional_space' : 'create_space', {
        'p_name': name,
        'p_household': household,
        'p_base_currency': baseCurrency,
        'p_preferred_name': preferredName,
      });
      if (result is! Map) {
        throw const SyncException(0, 'unexpected response from server');
      }
      final sid = result['id'].toString();
      if ((result['sync_protocol'] as num?)?.toInt() == 2) {
        await _enableSyncV2ForSpace(sid);
      }
      await _adoptSpace(
        id: sid,
        code: result['invite_code']?.toString(),
        name: name,
      );
      final defaultListId = result['default_list_id']?.toString();
      if (defaultListId != null && defaultListId.isNotEmpty) {
        await _kvSet('default_list_id', defaultListId);
      }
      await _fullSync();
      return true;
    } on SyncException catch (e) {
      if (e.message.contains('FAMILY_NAME_TAKEN')) {
        _setStatus(SyncStatus.error,
            'FAMILY_NAME_TAKEN: That family name is already taken - try another.');
      } else if (e.message.contains('FAMILY_LIMIT_REACHED')) {
        _setStatus(SyncStatus.error,
            'FAMILY_LIMIT_REACHED: Free includes one created family space. Mhuri Plus unlocks additional family spaces.');
      } else {
        _setStatus(
          e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
          e.message,
        );
      }
      return false;
    } catch (e) {
      debugPrint('Mhuri create-space error: $e');
      _setStatus(SyncStatus.offline, 'Network error - try again.');
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
        'p_space_id': _spaceId,
      });
      return true;
    } catch (e) {
      debugPrint('Mhuri role-permissions error: $e');
      return false;
    }
  }

  Future<bool> saveFamilyMonthStart(int day) =>
      saveFamilyCycleSettings(day: day, timezone: state.householdTimezone);

  /// Persists payday start day + household timezone on `family_space` in one
  /// round trip (migration 083 `set_family_cycle_settings`), so a Harare
  /// family with members in London or New York all roll over together.
  Future<bool> saveFamilyCycleSettings({
    required int day,
    String? timezone,
  }) async {
    final sid = _spaceId;
    if (sid == null || day < 1 || day > 31) return false;
    try {
      await client.rpc('set_family_cycle_settings', {
        'p_space_id': sid,
        'p_day': day,
        'p_timezone': (timezone == null || timezone.trim().isEmpty)
            ? null
            : timezone.trim(),
      });
      return true;
    } on SyncException catch (e) {
      _setStatus(
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
        e.message,
      );
      return false;
    } catch (_) {
      _setStatus(SyncStatus.offline,
          'Could not update the family budget cycle. Try again.');
      return false;
    }
  }

  /// Persists household primary/secondary currency and optional custom FX rate
  /// on `family_space` so every member device sees identical totals.
  Future<bool> saveFamilyCurrencySettings({
    required Currency primary,
    required Currency? secondary,
    double? customRate,
  }) async {
    final sid = _spaceId;
    if (sid == null) return false;
    try {
      await client.rpc('set_family_currency_settings', {
        'p_space_id': sid,
        'p_primary': primary.code,
        'p_secondary': secondary?.code,
        'p_custom_rate': secondary == null ? null : customRate,
      });
      return true;
    } on SyncException catch (e) {
      _setStatus(
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
        e.message,
      );
      return false;
    } catch (_) {
      _setStatus(SyncStatus.offline,
          'Could not sync family currency settings right now.');
      return false;
    }
  }

  Future<bool> saveFamilySetup({
    required Currency primary,
    required Currency? secondary,
    required int monthStart,
    required List<Map<String, String>> templates,
    required String stage,
  }) async {
    final previousStage = state.onboardingStage;
    try {
      _setStatus(SyncStatus.syncing);
      await client.rpc('save_family_setup', {
        'p_primary': primary.code,
        'p_secondary': secondary?.code,
        'p_month_start': monthStart,
        'p_templates': templates,
        'p_stage': stage,
      });
      state.setPrimaryCurrency(primary);
      state.setSecondaryCurrency(secondary);
      state.setMonthStartDay(monthStart);
      await state.applyFamilySetupSettings(
        stage: stage,
        templates: templates,
      );
    } catch (e) {
      debugPrint('Mhuri family-setup error: $e');
      _setStatus(SyncStatus.error,
          'We could not save your setup. Your previous steps are still safe.');
      return false;
    }

    // The RPC is the setup commit. Persist its settings locally and let the
    // normal debounced sync refresh any server-created/archived envelopes in
    // the background. Currency and completion-only saves need no immediate
    // data refresh; template changes do.
    if (_activeSync == null) _setStatus(SyncStatus.idle);
    if (stage == 'ready' || (stage == 'complete' && previousStage != 'ready')) {
      schedule();
    }
    return true;
  }

  Future<Map<String, String>?> pendingFamilyInvite() async {
    try {
      final value = await client.rpc('my_pending_family_invite', {});
      if (value is! Map) return null;
      return {for (final e in value.entries) e.key.toString(): '${e.value}'};
    } catch (_) {
      return null;
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
      'p_space_id': _spaceId,
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

  /// Owner/parent-assisted account setup. This deliberately goes through an
  /// Edge Function: creating another auth user from the client SDK would
  /// replace the current owner's session, and an admin key must never live in
  /// the app bundle.
  Future<void> createFamilyMember({
    required String name,
    required String email,
    required String temporaryPassword,
    required String role,
  }) async {
    await client.invokeFunction('create-family-member', {
      'name': name,
      'email': email,
      'temporary_password': temporaryPassword,
      'role': role,
      'space_id': _spaceId,
    });
    // The Edge Function writes membership/profile rows directly, so there is
    // no local outbox mutation to trigger a roster refresh. Pull the roster
    // before reporting success so the new member appears immediately.
    await _pullMembers();
  }

  /// Returns the signed-in member's personal savings jar, provisioning it on
  /// the server when necessary. The privileged function is required because
  /// teens may contribute to goals but cannot create arbitrary family goals.
  Future<Goal?> ensurePersonalSavingsGoal() async {
    final existing = state.teenJarGoal;
    if (existing != null) return existing;
    final response = await client.invokeFunction('ensure-savings-jar', {
      'member_id': state.user.id,
    });
    if (response is! Map || response['goal'] is! Map) {
      throw const SyncException(0, 'GOAL_CREATE_FAILED');
    }
    final raw = Map<String, Object?>.from(response['goal'] as Map);
    await _persistence.applyServerRows('goal', [raw]);
    state.applyPulled('goal', [raw]);
    final id = raw['id']?.toString();
    return id == null ? null : state.goal(id);
  }

  /// Fetches the server-authoritative entitlement for the active family.
  /// The client never derives Plus from a local purchase callback.
  Future<FamilyEntitlement> fetchFamilyEntitlement(
      {String? purchaseToken, String? productId}) async {
    final familyId = _spaceId;
    if (familyId == null || familyId.isEmpty) {
      throw const SyncException(0, 'FAMILY_REQUIRED');
    }
    final response = await client.invokeFunction(
      'verify-family-entitlement',
      {
        'family_id': familyId,
        if (purchaseToken != null) 'purchase_token': purchaseToken,
        if (productId != null) 'product_id': productId,
      },
    );
    if (response is! Map) {
      throw const SyncException(0, 'INVALID_ENTITLEMENT_RESPONSE');
    }
    final entitlement = FamilyEntitlement.fromJson(
      Map<String, Object?>.from(response),
    );
    if (entitlement.familyId != familyId) {
      throw const SyncException(0, 'ENTITLEMENT_FAMILY_MISMATCH');
    }
    return entitlement;
  }

  /// Sends a bounded, read-only question to Ask Mhuri. The server remains the
  /// authority for family access, financial context, and AI usage limits.
  Future<Map<String, Object?>> askMhuri(
    String question, {
    List<Map<String, Object?>> history = const [],
  }) async {
    final familyId = _spaceId;
    if (familyId == null || familyId.isEmpty) {
      throw const SyncException(0, 'FAMILY_REQUIRED');
    }
    final response = await client.invokeFunction(
      'ask-mhuri',
      {
        'family_id': familyId,
        'question': question,
        if (history.isNotEmpty) 'history': history,
      },
      // The Edge Function has a 110-second server budget for gathering the
      // family summary and waiting for the AI provider. Let it finish before the app
      // reports a misleading connectivity error.
      timeout: const Duration(seconds: 120),
      timeoutMessage: 'AI_REQUEST_TIMEOUT',
    );
    if (response is! Map) {
      throw const SyncException(0, 'INVALID_AI_RESPONSE');
    }
    return Map<String, Object?>.from(response);
  }

  Future<List<Map<String, Object?>>> fetchFamilyChatPolls() async {
    final familyId = _spaceId;
    if (familyId == null) throw const SyncException(0, 'FAMILY_REQUIRED');
    final result = await client.rpc('get_family_chat_polls', {
      'p_space_id': familyId,
    });
    if (result is! List) return const [];
    return [
      for (final row in result)
        if (row is Map) Map<String, Object?>.from(row),
    ];
  }

  Future<void> createFamilyChatPoll({
    required String question,
    required List<String> options,
    bool allowMultiple = false,
    DateTime? closesAt,
  }) async {
    _requireChatPlus('family_polls_pins');
    final familyId = _spaceId;
    if (familyId == null) throw const SyncException(0, 'FAMILY_REQUIRED');
    await client.rpc('create_family_chat_poll', {
      'p_space_id': familyId,
      'p_question': question,
      'p_options': options,
      'p_allow_multiple': allowMultiple,
      'p_closes_at': closesAt?.toUtc().toIso8601String(),
    });
  }

  Future<void> voteFamilyChatPoll(
      String pollId, List<int> optionIndexes) async {
    _requireChatPlus('family_polls_pins');
    await client.rpc('vote_family_chat_poll', {
      'p_poll_id': pollId,
      'p_option_indexes': optionIndexes,
    });
  }

  Future<void> closeFamilyChatPoll(String pollId) async {
    _requireChatPlus('family_polls_pins');
    await client.rpc('close_family_chat_poll', {'p_poll_id': pollId});
  }

  Future<void> setFamilyChatPin(String messageId,
      {required bool pinned}) async {
    if (pinned) _requireChatPlus('family_polls_pins');
    final familyId = _spaceId;
    if (familyId == null) throw const SyncException(0, 'FAMILY_REQUIRED');
    await client.rpc('set_family_chat_pin', {
      'p_space_id': familyId,
      'p_message_id': messageId,
      'p_pinned': pinned,
    });
  }

  Future<List<Map<String, Object?>>> fetchFamilyChatPins() async {
    final familyId = _spaceId;
    if (familyId == null) return const [];
    return client.pullRows(
      'family_chat_pin',
      orderCol: 'created_at',
      spaceId: familyId,
      spaceCol: 'space_id',
      ascending: false,
      limit: 20,
    );
  }

  Future<List<FamilyChatMessage>> searchFamilyChatMessages({
    String? text,
    String? senderId,
    DateTime? from,
    DateTime? before,
    String kind = 'any',
    int limit = 50,
    int offset = 0,
  }) async {
    _requireChatPlus('advanced_chat_search');
    final familyId = _spaceId;
    if (familyId == null) throw const SyncException(0, 'FAMILY_REQUIRED');
    final result = await client.rpc('search_family_chat_messages', {
      'p_space_id': familyId,
      'p_text': text,
      'p_sender_id': senderId,
      'p_after': from?.toUtc().toIso8601String(),
      'p_before': before?.toUtc().toIso8601String(),
      'p_kind': kind,
      'p_limit': limit.clamp(1, 500),
      'p_offset': offset < 0 ? 0 : offset,
    });
    if (result is! List) return const [];
    final adapter = kSyncAdapters['family_chat_message']!;
    return [
      for (final raw in result)
        if (raw is Map)
          adapter.decode(Map<String, Object?>.from(raw)) as FamilyChatMessage,
    ];
  }

  void _requireChatPlus(String feature) {
    if (!state.canWritePlusFeature(feature)) {
      throw const SyncException(403, 'PLUS_WRITE_REQUIRES_VERIFICATION');
    }
  }

  /// Hands the family to another active member: roles swap, the family's
  /// static code moves with it, audit row written (migration 010).
  Future<void> transferOwnership(String newOwnerUserId) =>
      client.rpc('transfer_ownership', {
        'p_new_owner': newOwnerUserId,
        'p_space_id': _spaceId,
      });

  Future<String> updateFamilyName(String name) async {
    final result = await client.rpc('update_family_name', {
      'p_name': name,
      'p_space_id': _spaceId,
    });
    final updated = result?.toString() ?? name.trim();
    spaceName = updated;
    await _kvSet('space_name', updated);
    state.adoptSpaceName(updated);
    return updated;
  }

  Future<void> changeMemberRole(String memberId, String role) async {
    await client.rpc('change_member_role', {
      'p_member': memberId,
      'p_role': role,
      'p_space_id': _spaceId,
    });
    await _pullMembers();
  }

  Future<void> removeFamilyMember(String memberId) async {
    await client.rpc('remove_family_member', {
      'p_member': memberId,
      'p_space_id': _spaceId,
    });
    await _pullMembers();
  }

  /// Pushes the signed-in member's profile columns (avatar_url, name).
  Future<void> updateMyProfile(Map<String, Object?> values) async {
    // Auth tokens and identity moved to encrypted storage; the sync KV store
    // no longer reliably contains auth_user_id. Prefer the live session.
    final uid = state.auth?.session?.userId ?? await _kvGet('auth_user_id');
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
      _setStatus(SyncStatus.offline, 'Network error - try again.');
    }
  }

  Future<void> updateChildProfile(
    String memberId,
    Map<String, Object?> values,
  ) async {
    if (memberId.isEmpty || values.isEmpty) return;
    try {
      _setStatus(SyncStatus.syncing);
      await client.rpc('update_child_profile', {
        'p_member': memberId,
        'p_name': values['name'],
        'p_avatar': values['avatar'],
        'p_avatar_url': values['avatar_url'],
        'p_update_name': values.containsKey('name'),
        'p_update_avatar': values.containsKey('avatar'),
        'p_update_avatar_url': values.containsKey('avatar_url'),
      });
      _setStatus(SyncStatus.idle);
    } on SyncException catch (e) {
      _setStatus(
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
        e.message,
      );
    } catch (_) {
      _setStatus(SyncStatus.offline, 'Network error - try again.');
    }
  }

  Future<bool> joinSpace(String code, {String? preferredName}) async {
    final normalized = code.trim().toUpperCase();
    // Role-bound invitations use six characters after MHRI- and are
    // single-use. Four-character codes are the legacy reusable family code.
    // Keep the latter working for already printed/shared codes while routing
    // every new invitation through join_invite.
    final roleBound = RegExp(r'^MHRI-[A-Z0-9]{6}$').hasMatch(normalized);
    try {
      if (!await _flushBeforeChangingSpace()) return false;
      _setStatus(SyncStatus.syncing);
      final id = await client.rpc(
        roleBound ? 'join_invite' : 'join_space',
        {'p_code': normalized},
      );
      if (id == null) {
        throw const SyncException(0, 'unexpected response from server');
      }
      final cleanName = preferredName?.trim();
      final uid = state.auth?.session?.userId ?? await _kvGet('auth_user_id');
      if (cleanName != null && cleanName.isNotEmpty && uid != null) {
        // The join RPC initially falls back to the email prefix. Persist the
        // chosen name before pulling the roster so that fallback can never
        // overwrite what the user entered in onboarding.
        try {
          await client.patchRow('user_profile', uid, {'name': cleanName});
        } catch (_) {
          // Joining has already succeeded and an invite may now be consumed.
          // Never report the whole join as failed because this best-effort
          // early profile write failed; setMyName retries it after adoption.
        }
      }
      await _adoptSpace(
        id: id.toString(),
        // A single-use invite is not the family's permanent owner code and
        // must never be persisted or displayed as one.
        code: roleBound ? null : normalized,
        name: null,
      );
      await _fullSync();
      return true;
    } on SyncException catch (e) {
      if (e.message.contains('INVALID_CODE')) {
        _setStatus(
          SyncStatus.error,
          'That invite code was not found - check it and try again.',
        );
      } else if (e.message.contains('ALREADY_IN_FAMILY')) {
        _setStatus(
          SyncStatus.error,
          'This account already belongs to a family.',
        );
      } else {
        _setStatus(
          e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
          e.message,
        );
      }
      return false;
    } catch (e) {
      _setStatus(SyncStatus.offline, 'Network error - try again.');
      return false;
    }
  }

  Future<void> _adoptSpace({
    required String id,
    required String? code,
    required String? name,
  }) async {
    _spaceId = id;
    final activeUser = state.auth?.session?.userId;
    if (activeUser != null && activeUser.isNotEmpty) {
      await _kvSet('cached_family_user_id', activeUser);
    }
    if (code != null) {
      inviteCode = code;
      await _kvSet('invite_code', code);
    }
    if (name != null) {
      spaceName = name;
      await _kvSet('space_name', name);
    }
    await _kvSet('space_id', id);
    if (await _kvGet('sync_cursor_proto_v2_$id') == '1') {
      _v2Spaces.add(id);
    }
    // Any list id from a previous family is void - the join path relearns it
    // from the shopping_list header pull; the create path sets it from the
    // RPC result right after this.
    await _kvSet('default_list_id', '');
    await _kvSet('sync_cursor', ''); // retire the unsafe shared cursor
    await _kvSet('sync_cursor_v2_$id', '');
    for (final entity in kPullOrder) {
      await _kvSet('sync_cursor_$entity', '');
    }

    // Fresh family start on this device: clear synced tables + outbox.
    await _persistence.wipeSynced();
    await _outbox.clear();
    state.onSpaceAdopted(spaceName: name);
    _realtime?.configure(spaceId: id, active: _foregroundActive);

    // Join path: the RPC returns only the id - fetch the family's real name
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
          if (rows.first['sync_seq'] != null) {
            await _enableSyncV2ForSpace(id);
          }
          final fetched = (rows.first['name'] ?? '').toString();
          if (fetched.isNotEmpty) {
            spaceName = fetched;
            await _kvSet('space_name', fetched);
            state.adoptSpaceName(fetched);
          }
        }
      } catch (_) {
        // Offline/name unavailable - placeholder stays; next full sync retries.
      }
    }
  }

  // ── the sync loop ───────────────────────────────────────────────────────

  Future<void> syncNow({bool force = false}) {
    if (_reconciling) return Future<void>.value();
    final active = _activeSync;
    if (active != null) return active;
    final run = _runSync(force: force);
    _activeSync = run;
    return run.whenComplete(() {
      if (identical(_activeSync, run)) _activeSync = null;
    });
  }

  /// Repairs a device whose incremental pull cursor is ahead of data it never
  /// received (for example after Android restores app storage on reinstall).
  /// Pending local writes are pushed first and are never discarded.
  Future<bool> reloadAllFamilyData({bool automatic = false}) async {
    if (_reconciling) return false;
    final active = _activeSync;
    if (active != null) await active;
    if (_spaceId == null) {
      _setStatus(SyncStatus.needsSetup, 'No family is selected.');
      return false;
    }

    if (await _outbox.count() > 0) {
      await syncNow(force: true);
      if (await _outbox.count() > 0) {
        _setStatus(
          SyncStatus.error,
          'Some changes on this device have not reached the family yet. '
          'Resolve them before reloading all data.',
        );
        return false;
      }
    }

    _reconciling = true;
    _setStatus(SyncStatus.syncing);
    try {
      await _fullSync();
      await _kvSet(_reconcileKey, '${DateTime.now().millisecondsSinceEpoch}');
      return true;
    } on SyncException catch (e) {
      _registerFailure(
        e.message,
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
      );
      reportError?.call('sync:full_reload', e, StackTrace.current);
      return false;
    } catch (e, st) {
      _registerFailure(
          'Network error - could not reload family data.', SyncStatus.offline);
      reportError?.call('sync:full_reload', e, st);
      return false;
    } finally {
      _reconciling = false;
      await state.refreshPending();
    }
  }

  Future<void> _runSync({required bool force}) async {
    final sid = _spaceId;
    if (sid == null) {
      _setStatus(SyncStatus.needsSetup);
      return;
    }
    if (!force &&
        _nextPushOkAt != null &&
        DateTime.now().isBefore(_nextPushOkAt!)) {
      return; // backing off - the periodic poll will try again
    }
    _setStatus(SyncStatus.syncing);
    // Phase 4 #19: correlation id + duration for the sync-health events.
    final run = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final sw = Stopwatch()..start();
    try {
      try {
        await _backfillLocalFamilyTasks(sid);
        if (!_isSyncV2(sid)) {
          await _detectConflicts();
        }
        await _push();
        await _pull(sid);
      } on SyncException catch (e) {
        // Access token expired mid-session: force one refresh and retry the
        // pass exactly once. Still 401 → rethrown → needsSignIn below.
        if (!e.isAuthError || retryAuth == null) {
          rethrow;
        }
        final refreshed = await retryAuth!();
        if (!refreshed) {
          rethrow;
        }
        if (!_isSyncV2(sid)) {
          await _detectConflicts();
        }
        await _push();
        await _pull(sid);
      }
      lastSyncAt = DateTime.now();
      await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
      _consecFail = 0;
      _nextPushOkAt = null;
      _setStatus(await _outbox.countConflicts() > 0
          ? SyncStatus.needsReview
          : SyncStatus.idle);
      mhuriEvent('sync.ok', {'run': run, 'ms': sw.elapsedMilliseconds});
    } on SyncException catch (e) {
      _registerFailure(
        e.message,
        e.isAuthError ? SyncStatus.needsSignIn : SyncStatus.error,
      );
      reportError?.call('sync', e, StackTrace.current);
      mhuriEvent('sync.fail', {'run': run, 'kind': 'server'});
    } catch (e, st) {
      _registerFailure('Network error - will retry.', SyncStatus.offline);
      debugPrint('Mhuri sync offline: $e');
      reportError?.call('sync', e, st);
      mhuriEvent('sync.fail', {'run': run, 'kind': 'offline'});
    } finally {
      await state.refreshPending();
    }
  }

  static const _conflictEntities = {
    'account',
    'tx',
    'envelope',
    'goal',
    'recurring',
    'list_item',
    'budget_cycle_plan',
    'family_debt',
    'contribution_campaign',
    'family_task',
    'family_reward',
    'financial_commitment',
  };

  static bool _isMissingRpcError(SyncException e, String fnName) =>
      (e.statusCode == 404 || e.statusCode == 400) &&
      (e.message.contains(fnName) ||
          e.message.contains('PGRST202') ||
          e.message.contains('Could not find the function'));

  /// Family tasks pre-dated their server table. Publish only local rows that
  /// are genuinely absent from the server. Re-publishing an existing row can
  /// replace a newer state with a stale device snapshot because the backfill
  /// operation itself has a fresh outbox timestamp.
  Future<void> _backfillLocalFamilyTasks(String sid) async {
    if (!state.canManageFamilyTasks || state.familyTasks.isEmpty) return;
    final key = 'family_tasks_backfilled_v2_$sid';
    if (await _kvGet(key) == '1') return;

    final remoteRows = await client.pullRows(
      'family_task',
      orderCol: 'updated_at',
      spaceId: sid,
      spaceCol: 'space_id',
      limit: 500,
    );
    final remoteIds = {
      for (final row in remoteRows)
        if (row['id'] != null) row['id'].toString(),
    };
    for (final task in state.familyTasks.where(
      (task) => !remoteIds.contains(task.id),
    )) {
      await enqueue('family_task', task);
    }
    await _kvSet(key, '1');
  }

  Future<void> _detectConflicts() async {
    final pending = (await _outbox.take(200))
        .where(
          (op) =>
              _conflictEntities.contains(op.entity) && op.basePayload == null,
        )
        .toList();
    if (pending.isEmpty) return;
    final grouped = <String, List<OutboxOp>>{};
    for (final op in pending) {
      if (op.payload['id'] == null) continue;
      grouped.putIfAbsent(op.entity, () => []).add(op);
    }
    for (final entry in grouped.entries) {
      final adapter = kSyncAdapters[entry.key]!;
      final ids = entry.value.map((op) => op.payload['id']).toSet().join(',');
      final rows = await client.pullRows(adapter.table,
          orderCol: 'updated_at', eqFilters: {'id': 'in.($ids)'}, limit: 200);
      final byId = {for (final row in rows) '${row['id']}': row};
      for (final op in entry.value) {
        final remote = byId['${op.payload['id']}'];
        if (remote == null || _samePayload(op.payload, remote)) continue;
        final serverVersion = remote['updated_at']?.toString();
        final baseVersion = op.payload['_base_updated_at']?.toString();
        // Never trust a device clock to order writes. Legacy/unbased mutations
        // without a basePayload cannot run 3-way merge and fail closed.
        if (serverVersion == null ||
            baseVersion == null ||
            serverVersion != baseVersion) {
          await _outbox.markConflict(
              op.rowId, 'This record changed on another device.', remote);
        }
      }
    }
  }

  bool _samePayload(Map<String, Object?> local, Map<String, Object?> remote) {
    for (final entry in local.entries) {
      if (entry.key == 'updated_at' ||
          entry.key == '_base_updated_at' ||
          entry.key == '_has_envelope_link' ||
          entry.key == '_envelope_id') {
        continue;
      }
      if ('${entry.value ?? ''}' != '${remote[entry.key] ?? ''}') return false;
    }
    return true;
  }

  /// Collapses multiple queued mutations targeting the same `(entity, id)`
  /// while preserving the initial op's CAS base (`_base_updated_at` and
  /// `basePayload`) and ordering independent entities by topological FK order.
  static List<_CollapsedPushUnit> _buildPushUnits(List<OutboxOp> ops) {
    // 1. Group explicit atomic batches (`groupId != null`) so their ops remain
    //    contiguous for server savepoints, ordered internally by FK topology.
    final byGroup = <String, List<OutboxOp>>{};
    final standalone = <OutboxOp>[];
    for (final op in ops) {
      final gid = op.groupId;
      if (gid != null && gid.isNotEmpty) {
        byGroup.putIfAbsent(gid, () => <OutboxOp>[]).add(op);
      } else {
        standalone.add(op);
      }
    }

    // 2. Collapse standalone ops by `(entity, id)` in queue order.
    final collapsedStandalone = <_CollapsedPushUnit>[];
    final byEntityAndId = <String, List<OutboxOp>>{};
    final withoutId = <OutboxOp>[];
    for (final op in standalone) {
      final rowId = op.payload['id']?.toString();
      if (rowId == null || rowId.isEmpty) {
        withoutId.add(op);
      } else {
        byEntityAndId.putIfAbsent('${op.entity}::$rowId', () => []).add(op);
      }
    }
    for (final op in withoutId) {
      collapsedStandalone.add(_CollapsedPushUnit.fromOps([op]));
    }
    for (final groupOps in byEntityAndId.values) {
      collapsedStandalone.add(_CollapsedPushUnit.fromOps(groupOps));
    }

    // 3. Build ordered bundles so FK parents always precede FK children while
    //    multi-row `groupId` savepoints stay contiguous.
    final bundles = <({int rank, int firstRowId, List<_CollapsedPushUnit> units})>[
      for (final unit in collapsedStandalone)
        (
          rank: pushOrderIndex(unit.entity),
          firstRowId: unit.outboxRowIds.first,
          units: [unit],
        ),
    ];
    for (final entry in byGroup.entries) {
      final sortedGroupOps = List.of(entry.value)
        ..sort((a, b) {
          final cmp =
              pushOrderIndex(a.entity).compareTo(pushOrderIndex(b.entity));
          return cmp != 0 ? cmp : a.rowId.compareTo(b.rowId);
        });
      // Collapse duplicate `(entity, id)` within the same group if any.
      final unitsInGroup = <_CollapsedPushUnit>[];
      final seenInGroup = <String, List<OutboxOp>>{};
      for (final op in sortedGroupOps) {
        final id = op.payload['id']?.toString();
        if (id == null || id.isEmpty) {
          unitsInGroup.add(_CollapsedPushUnit.fromOps([op]));
        } else {
          seenInGroup.putIfAbsent('${op.entity}::$id', () => []).add(op);
        }
      }
      for (final gOps in seenInGroup.values) {
        unitsInGroup.add(_CollapsedPushUnit.fromOps(gOps));
      }
      unitsInGroup.sort((a, b) {
        final cmp =
            pushOrderIndex(a.entity).compareTo(pushOrderIndex(b.entity));
        return cmp != 0
            ? cmp
            : a.outboxRowIds.first.compareTo(b.outboxRowIds.first);
      });
      final minRank = unitsInGroup
          .map((u) => pushOrderIndex(u.entity))
          .reduce((a, b) => a < b ? a : b);
      bundles.add((
        rank: minRank,
        firstRowId: sortedGroupOps.first.rowId,
        units: unitsInGroup,
      ));
    }

    bundles.sort((a, b) {
      final cmp = a.rank.compareTo(b.rank);
      return cmp != 0 ? cmp : a.firstRowId.compareTo(b.firstRowId);
    });

    return [
      for (final bundle in bundles) ...bundle.units,
    ];
  }

  Future<void> _push() async {
    final sid = _spaceId;
    // Promote staged offline receipt photos BEFORE the row push, so the same
    // sync cycle sends the canonical remote URL instead of a device path (#1).
    if (sid != null) {
      await _syncPendingReceipts(sid);
    }
    if (sid != null && _isSyncV2(sid)) {
      await _pushV2(sid);
      return;
    }
    await _pushLegacy();
  }

  /// Uploads every transaction's staged local receipt photo to the private
  /// `receipts` bucket and swaps the local file path for the canonical
  /// authenticated URL (idempotent - already-promoted rows are skipped).
  /// Failures keep the local path so the next push retries automatically.
  Future<void> _syncPendingReceipts(String sid) async {
    final storage = receiptStorage;
    if (storage == null) return;
    try {
      for (final tx in [...state.txs]) {
        final uri = tx.receiptUri;
        if (uri == null || isRemoteReceiptUri(uri)) continue;
        final file = File(uri);
        if (!await file.exists()) continue;
        final Uint8List bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (e) {
          debugPrint('Mhuri receipt read warning: $e');
          continue;
        }
        if (bytes.isEmpty) continue;
        try {
          final remoteUrl = await storage.upload(
            bytes: bytes,
            spaceId: sid,
            txId: tx.id,
            extension: receiptExtensionOf(uri),
            // Private-account receipts are owner-scoped objects
            // (<space>/private/<owner>/<tx>.<ext>); family transactions
            // share one household object per transaction.
            privateOwnerUserId:
                tx.accountId != null ? state.realUser.id : null,
          );
          await state.promoteTxReceiptUri(
            tx.id,
            remoteUrl,
            scheduleSync: false,
          );
        } catch (e) {
          debugPrint('Mhuri receipt upload warning: $e');
          reportError?.call('receipt_upload', e, StackTrace.current);
        }
      }
    } catch (e) {
      debugPrint('Mhuri receipt sync warning: $e');
    }
  }

  Future<void> _pushV2(String sid) async {
    while (true) {
      final taken = await _outbox.take(200);
      if (taken.isEmpty) return;

      final units = _buildPushUnits(taken);
      final rpcOps = <Map<String, Object?>>[];
      for (final unit in units) {
        final adapter = kSyncAdapters[unit.entity];
        if (adapter == null) continue;
        final cleanPayload = Map<String, Object?>.of(unit.payload)
          ..remove('_base_updated_at');
        rpcOps.add({
          'op_id': unit.opId,
          if (unit.groupId != null) 'group_id': unit.groupId,
          'space_id': sid,
          'table': adapter.table,
          'id': cleanPayload['id'],
          if (unit.baseUpdatedAt != null) 'base_updated_at': unit.baseUpdatedAt,
          if (unit.basePayload != null) 'base': unit.basePayload,
          'payload': cleanPayload,
        });
      }

      List<Map<String, Object?>> results;
      try {
        results = await client.pushSyncOps(rpcOps);
      } on SyncException catch (e) {
        if (_isMissingRpcError(e, 'push_sync_ops')) {
          await _disableSyncV2ForSpace(sid);
          await _detectConflicts();
          await _pushLegacy();
          return;
        }
        if (!e.isAuthError) {
          await _outbox.bumpAttempts([for (final op in taken) op.rowId]);
        }
        rethrow;
      }

      final byOpId = <String, Map<String, Object?>>{
        for (final r in results)
          if (r['op_id'] != null) r['op_id'].toString(): r,
      };

      final doneRowIds = <int>[];
      final retryRowIds = <int>[];
      final sentChatIds = <String>[];
      final batchRemap = <String, String>{};

      for (final unit in units) {
        final res = byOpId[unit.opId];
        if (res == null) {
          retryRowIds.addAll(unit.outboxRowIds);
          continue;
        }
        final seq = (res['sync_seq'] as num?)?.toInt();
        _recordKnownSeq(sid, seq);

        final resStatus = res['status']?.toString();
        final outcome = res['outcome']?.toString();
        var serverRow = res['row'] is Map
            ? Map<String, Object?>.from(res['row'] as Map)
            : null;
        if (serverRow != null && batchRemap.isNotEmpty) {
          serverRow = _remapBatchRowIds(serverRow, batchRemap);
        }
        final fallbackServerRow = res['server_row'] is Map
            ? Map<String, Object?>.from(res['server_row'] as Map)
            : null;

        if (resStatus == 'applied') {
          doneRowIds.addAll(unit.outboxRowIds);
          final replacedId = res['replaced_id']?.toString();
          if (outcome == 'adopted_existing' &&
              replacedId != null &&
              replacedId.isNotEmpty &&
              serverRow != null) {
            final canonicalId = serverRow['id']?.toString() ?? '';
            if (canonicalId.isNotEmpty && canonicalId != replacedId) {
              batchRemap[replacedId] = canonicalId;
            }
            await _handleAdoptedExisting(
              unit.entity,
              replacedId,
              canonicalId,
              serverRow,
            );
          } else if (serverRow != null) {
            await _persistence.applyServerRows(
              unit.entity,
              [serverRow],
              allowOverwriteDirty: true,
            );
            state.applyPulled(unit.entity, [serverRow]);
          }
          if (unit.entity == 'family_chat_message') {
            final chatId =
                (serverRow?['id'] ?? unit.payload['id'])?.toString() ?? '';
            if (chatId.isNotEmpty) sentChatIds.add(chatId);
          }
        } else if (resStatus == 'rejected' && res['permanent'] == true) {
          // Permanent server guard or RLS rejection: converge locally on the
          // authoritative server row when available and remove the poisoned op
          // so it never blocks subsequent family changes.
          reportError?.call(
            'push:${unit.entity}',
            SyncException(409, '${res['error'] ?? 'rejected'}'),
            StackTrace.current,
          );
          if (fallbackServerRow != null) {
            await _persistence.applyServerRows(
              unit.entity,
              [fallbackServerRow],
              allowOverwriteDirty: true,
            );
            state.applyPulled(unit.entity, [fallbackServerRow]);
          }
          doneRowIds.addAll(unit.outboxRowIds);
        } else {
          retryRowIds.addAll(unit.outboxRowIds);
        }
      }

      if (sentChatIds.isNotEmpty) {
        state.markChatMessagesSent(sentChatIds);
      }
      if (doneRowIds.isNotEmpty) {
        await _outbox.deleteRows(doneRowIds);
      }
      if (retryRowIds.isNotEmpty) {
        await _outbox.bumpAttempts(retryRowIds);
        throw const SyncException(0, 'some changes have not been pushed yet');
      }
      if (taken.length < 200) return;
    }
  }

  static const List<String> _remappableRowFields = [
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

  Map<String, Object?> _remapBatchRowIds(
    Map<String, Object?> row,
    Map<String, String> idRemap,
  ) {
    final out = Map<String, Object?>.from(row);
    for (final field in _remappableRowFields) {
      final v = out[field];
      if (v is String && idRemap.containsKey(v)) {
        out[field] = idRemap[v];
      }
    }
    final alloc = out['allocations'];
    if (alloc is Map) {
      final mapped = <String, Object?>{};
      for (final e in alloc.entries) {
        final k = e.key.toString();
        final nk = idRemap[k] ?? k;
        final prev = mapped[nk];
        if (prev is num && e.value is num) {
          mapped[nk] = prev + (e.value as num);
        } else {
          mapped[nk] = e.value;
        }
      }
      out['allocations'] = mapped;
    }
    return out;
  }

  Future<void> _handleAdoptedExisting(
    String entity,
    String oldId,
    String newId,
    Map<String, Object?> serverRow,
  ) async {
    await _persistence.remapEntityId(
      entity: entity,
      oldId: oldId,
      newId: newId,
      serverRow: serverRow,
    );
    await _outbox.rewriteEntityIdReferences(entity, oldId, newId);
    state.remapEntityId(entity, oldId, newId, serverRow);
  }

  /// Legacy PostgREST push path used when Sync Protocol v2 RPCs are absent
  /// (for example lightweight HTTP unit-test fakes).
  Future<void> _pushLegacy() async {
    final taken = await _outbox.take(200);
    if (taken.isEmpty) return;
    final ops = taken;
    final units = _buildPushUnits(ops);

    // Group ordered units by contiguous entity runs so topological FK order
    // (`envelope -> recurring -> tx -> list_item`) is preserved!
    final runs = <({String entity, List<_CollapsedPushUnit> units})>[];
    for (final unit in units) {
      if (runs.isNotEmpty && runs.last.entity == unit.entity) {
        runs.last.units.add(unit);
      } else {
        runs.add((entity: unit.entity, units: [unit]));
      }
    }

    var allOk = true;
    final doneRowIds = <int>[];
    final conflictedRowIds = <int>[];
    for (final run in runs) {
      final entityKey = run.entity;
      final adapter = kSyncAdapters[entityKey]!;
      final entryDoneRowIds = <int>[];
      final txEnvIntents = <String, ({bool hasLink, String? envId, String? base})>{};
      var rows = <Map<String, Object?>>[];
      try {
        if (_conflictEntities.contains(entityKey)) {
          for (final unit in run.units) {
            final base = unit.baseUpdatedAt;
            final hasEnvLink = unit.payload['_has_envelope_link'] == true;
            final envId = unit.payload['_envelope_id'] as String?;
            final row = Map<String, Object?>.of(unit.payload)
              ..remove('_base_updated_at')
              ..remove('_has_envelope_link')
              ..remove('_envelope_id');
            if (entityKey == 'tx' && row['id'] != null) {
              txEnvIntents['${row['id']}'] = (
                hasLink: hasEnvLink,
                envId: envId,
                base: base,
              );
            }
            if (entityKey == 'list_item' && base == null) {
              final remoteRows = await client.pullRows(
                adapter.table,
                orderCol: 'updated_at',
                eqFilters: {'id': 'eq.${row['id']}'},
                limit: 1,
              );
              final remote = remoteRows.firstOrNull;
              if (remote == null) {
                final inserted = await client.pushRowCompareAndSwap(
                  adapter.table,
                  row,
                );
                if (inserted) {
                  rows.add(row);
                  entryDoneRowIds.addAll(unit.outboxRowIds);
                }
                continue;
              }
              if (_samePayload(row, remote)) {
                rows.add(remote);
                entryDoneRowIds.addAll(unit.outboxRowIds);
                continue;
              }
              for (final rowId in unit.outboxRowIds) {
                await _outbox.markConflict(rowId,
                    'This shopping item changed on another device.', remote);
                conflictedRowIds.add(rowId);
              }
              continue;
            }
            final applied = await client.pushRowCompareAndSwap(
              adapter.table,
              row,
              baseUpdatedAt: base,
            );
            if (applied) {
              rows.add(row);
              entryDoneRowIds.addAll(unit.outboxRowIds);
              continue;
            }
            final baseUpdatedAt = base;
            final basePayload = unit.basePayload == null
                ? null
                : (Map<String, Object?>.of(unit.basePayload!)
                  ..remove('_base_updated_at')
                  ..remove('_has_envelope_link')
                  ..remove('_envelope_id'));
            if (basePayload != null &&
                basePayload.isNotEmpty &&
                baseUpdatedAt != null) {
              try {
                final merged = await client.mergeRow(
                  adapter.table,
                  row['id']!.toString(),
                  baseUpdatedAt,
                  basePayload,
                  row,
                );
                await _persistence.applyServerRows(
                  entityKey,
                  [merged],
                  allowOverwriteDirty: true,
                );
                state.applyPulled(entityKey, [merged]);
                rows.add(merged);
                entryDoneRowIds.addAll(unit.outboxRowIds);
                continue;
              } on SyncException catch (mergeErr) {
                debugPrint('Mhuri merge rejected [$entityKey]: $mergeErr');
                reportError?.call(
                    'merge:$entityKey', mergeErr, StackTrace.current);
              }
            }
            final remoteRows = await client.pullRows(
              adapter.table,
              orderCol: 'updated_at',
              eqFilters: {'id': 'eq.${row['id']}'},
              limit: 1,
            );
            final remote = remoteRows.firstOrNull;
            if (remote != null && _samePayload(row, remote)) {
              rows.add(remote);
              entryDoneRowIds.addAll(unit.outboxRowIds);
              continue;
            }
            for (final rowId in unit.outboxRowIds) {
              await _outbox.markConflict(rowId,
                  'This record changed on another device.', remote ?? const {});
              conflictedRowIds.add(rowId);
            }
          }
        } else {
          rows = [
            for (final unit in run.units)
              Map<String, Object?>.of(unit.payload)
                ..remove('_base_updated_at')
                ..remove('_has_envelope_link')
                ..remove('_envelope_id')
          ];
          await client.pushRows(adapter.table, rows);
          for (final unit in run.units) {
            entryDoneRowIds.addAll(unit.outboxRowIds);
          }
        }
        if (entityKey == 'family_chat_message') {
          state.markChatMessagesSent(rows.map((row) => row['id'].toString()));
        }
        if (entityKey == 'tx') {
          final byId = {for (final t in state.txs) t.id: t};
          final links = <Map<String, Object?>>[];
          final unlinkTxIds = <String>[];
          for (final row in rows) {
            final txId = row['id']?.toString();
            if (txId == null) continue;
            final intent = txEnvIntents[txId];
            final memTx = byId[txId];
            final effectiveEnvId = intent != null && intent.hasLink
                ? intent.envId
                : (memTx?.accountId == null ? memTx?.envelopeId : null);
            if (effectiveEnvId != null && effectiveEnvId.isNotEmpty) {
              if (intent?.base != null) {
                unlinkTxIds.add(txId);
              }
              links.add({
                'envelope_id': effectiveEnvId,
                'transaction_id': txId,
                'allocated_minor':
                    row['amount_minor'] ?? memTx?.amount.minor ?? 0,
                'currency':
                    row['currency'] ?? memTx?.amount.currency.code ?? 'USD',
              });
            } else if (intent != null &&
                intent.hasLink &&
                intent.base != null) {
              unlinkTxIds.add(txId);
            }
          }
          for (final txId in unlinkTxIds) {
            try {
              await client.deleteRows(
                'envelope_tx',
                {'transaction_id': 'eq.$txId'},
              );
            } catch (_) {}
          }
          if (links.isNotEmpty) {
            await client.pushRows(
              'envelope_tx',
              links,
              onConflict: 'envelope_id,transaction_id',
            );
          }
        }
        doneRowIds.addAll(entryDoneRowIds);
      } on SyncException catch (e) {
        if (e.isAuthError) rethrow;
        debugPrint('Mhuri push failed [$entityKey → ${adapter.table}, '
            '${run.units.length} unit(s)]: $e');
        reportError?.call('push:$entityKey', e, StackTrace.current);
        allOk = false;
        if (e.message.contains('STALE_SHOPPING')) {
          for (final unit in run.units) {
            final rowId = unit.payload['id']?.toString();
            if (rowId == null) continue;
            try {
              final remoteRows = await client.pullRows(
                adapter.table,
                orderCol: 'updated_at',
                eqFilters: {'id': 'eq.$rowId'},
                limit: 1,
              );
              final remote = remoteRows.firstOrNull;
              for (final outboxId in unit.outboxRowIds) {
                await _outbox.markConflict(
                  outboxId,
                  'The family list rejected this change as a stale shopping '
                  'regression. Review the server version before retrying.',
                  remote ?? {},
                );
                conflictedRowIds.add(outboxId);
              }
            } catch (_) {
              for (final outboxId in unit.outboxRowIds) {
                await _outbox.markConflict(
                  outboxId,
                  'The family list rejected this change as a stale shopping '
                  'regression.',
                  {},
                );
                conflictedRowIds.add(outboxId);
              }
            }
          }
        }
      }
    }

    if (doneRowIds.isNotEmpty) await _outbox.deleteRows(doneRowIds);
    if (!allOk) {
      await _outbox.bumpAttempts([
        for (final op in ops)
          if (!conflictedRowIds.contains(op.rowId) &&
              !doneRowIds.contains(op.rowId))
            op.rowId,
      ]);
      throw const SyncException(0, 'some changes have not been pushed yet');
    }
  }

  Future<void> _pull(String sid) async {
    if (_isSyncV2(sid)) {
      final handled = await _pullV2(sid, full: false);
      if (handled) return;
    }
    SyncException? pullError;
    try {
      await _pullSince(sid, full: false);
    } on SyncException catch (e) {
      pullError = e;
    }
    // Budget attribution must not depend on every unrelated module pulling
    // successfully. Always attempt it before surfacing a partial-sync error.
    await _pullEnvelopeLinks();
    // Membership is not part of the cursor-based entity pull. Refresh it on
    // normal syncs so members added on this or another device become visible.
    await _pullMembers();
    // Budget-cycle/currency settings are family-wide and can change on any
    // admin device. Refresh them during every normal sync, not only adoption.
    await _pullFamilySettings();
    if (pullError != null) throw pullError;
  }

  Future<bool> _pullV2(String sid, {required bool full}) async {
    final cursorKey = 'sync_cursor_v2_$sid';
    final cursors = <String, int>{};
    if (!full) {
      final raw = await _kvGet(cursorKey);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              final v = entry.value;
              if (v is num) {
                cursors[entry.key.toString()] = v.toInt();
              } else if (v != null) {
                final parsed = int.tryParse(v.toString());
                if (parsed != null) cursors[entry.key.toString()] = parsed;
              }
            }
          }
        } catch (_) {}
      }
    }

    if (full) {
      await _persistence.clearAccounts();
      state.clearAccountsForServerSnapshot(notify: false);
    }

    final dirtyByEntity = await _outbox.dirtyIdsByEntity();
    var anyEntityMutated = full;
    var pages = 0;

    while (pages < 50) {
      pages++;
      Map<String, Object?> response;
      try {
        response =
            await client.pullFamilyChanges(sid, cursors, pageLimit: 500);
      } on SyncException catch (e) {
        if (_isMissingRpcError(e, 'pull_family_changes')) {
          await _disableSyncV2ForSpace(sid);
          return false;
        }
        rethrow;
      }

      _recordKnownSeq(
        sid,
        ((response['signal_seq'] ?? response['server_max_seq']) as num?)
            ?.toInt(),
      );

      final changes = response['changes'];
      if (changes is Map) {
        for (final entity in kPullOrder) {
          final rawRows = changes[entity];
          if (rawRows is! List || rawRows.isEmpty) continue;
          final rows = [
            for (final item in rawRows)
              if (item is Map) Map<String, Object?>.from(item),
          ];
          if (rows.isEmpty) continue;
          final dirtyIds = dirtyByEntity[entity] ?? const <String>{};
          await _persistence.applyServerRows(
            entity,
            rows,
            dirtyIds: dirtyIds,
          );
          final cleanRows = dirtyIds.isEmpty
              ? rows
              : [
                  for (final r in rows)
                    if (!dirtyIds.contains('${r['id'] ?? ''}')) r,
                ];
          if (cleanRows.isNotEmpty) {
            state.applyPulled(entity, cleanRows, notify: false);
            if (entity == 'shopping_list') {
              await _captureDefaultList(cleanRows);
            }
            anyEntityMutated = true;
          }
        }
      }

      final spacePayload = response['family_space'] ?? response['space'];
      if (spacePayload is List && spacePayload.isNotEmpty) {
        final firstSpace = spacePayload.first;
        if (firstSpace is Map) {
          await _applyFamilySpaceRow(Map<String, Object?>.from(firstSpace));
        }
      } else if (spacePayload is Map) {
        await _applyFamilySpaceRow(Map<String, Object?>.from(spacePayload));
      }

      final roster = response['roster'];
      if (roster is Map && roster['changed'] != false) {
        final rawMemberships = roster['membership'] ?? roster['memberships'];
        final rawProfiles = roster['user_profile'] ?? roster['profiles'];
        if (rawMemberships is List) {
          final memberships = [
            for (final m in rawMemberships)
              if (m is Map) Map<String, Object?>.from(m),
          ];
          final profiles = [
            if (rawProfiles is List)
              for (final p in rawProfiles)
                if (p is Map) Map<String, Object?>.from(p),
          ];
          if (memberships.isNotEmpty) {
            final list = membersFromServer(
              membershipRows: memberships,
              profileRows: profiles,
              meId: state.user.id,
            );
            await state.setFamilyMembers(list);
          }
        }
      }

      final rateRows = response['rate_snapshot'];
      if (rateRows is List && rateRows.isNotEmpty) {
        final firstRate = rateRows.first;
        if (firstRate is Map) {
          final rateVal = (firstRate['usd_zwg'] as num?)?.toDouble();
          if (rateVal != null && rateVal > 0) {
            await state.applyServerRate(rateVal);
          }
        }
      }

      final nextCursors = response['cursors'];
      if (nextCursors is Map) {
        for (final entry in nextCursors.entries) {
          final val = entry.value;
          if (val is num) {
            cursors[entry.key.toString()] = val.toInt();
          } else if (val != null) {
            final parsed = int.tryParse(val.toString());
            if (parsed != null) cursors[entry.key.toString()] = parsed;
          }
        }
        await _kvSet(cursorKey, jsonEncode(cursors));
      }

      if (response['has_more'] != true) break;
    }

    if (anyEntityMutated) {
      state.publishPulledMerge();
    }
    return true;
  }

  /// Pulls the envelope_tx junction and mirrors it into local tx.envelopeId,
  /// so budget attribution follows the family across devices.
  Future<void> _pullEnvelopeLinks({bool notify = true}) async {
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
    final dirtyTxIds = await _outbox.dirtyRowIdsForEntity('tx');
    await state.applyEnvelopeLinks(
      links,
      notify: notify,
      clearMissing: rows.length < 2000,
      dirtyTxIds: dirtyTxIds,
    );
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
      // Rate stays as-is offline - never blocks sync status.
    }
  }

  /// Pulls the family roster (membership + user_profile) so every family
  /// member's data can display with a real name. Best effort - identity
  /// already works from the local bootstrap; this enriches it.
  Future<void> _pullMembers() async {
    try {
      final sid = _spaceId;
      if (sid == null) return;
      final membership = await client.pullRows(
        'membership',
        orderCol: 'user_id',
        eqFilters: {
          'space_id': 'eq.$sid',
          'invite_status': 'eq.active',
        },
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
      // RLS/network hiccup - local identity remains; retried next full sync.
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
      if (rows.first['sync_seq'] != null) {
        await _enableSyncV2ForSpace(sid);
      }
      await _applyFamilySpaceRow(rows.first);
    } catch (_) {
      // Non-fatal - defaults keep the UI consistent with the server defaults.
    }
  }

  Future<void> _applyFamilySpaceRow(Map<String, Object?> spaceRow) async {
    final name = spaceRow['name']?.toString();
    if (name != null && name.trim().isNotEmpty) {
      spaceName = name.trim();
      await _kvSet('space_name', spaceName!);
      state.adoptSpaceName(spaceName!);
    }
    final settings = spaceRow['settings'];
    final perms = <String, bool>{};
    if (settings is Map) {
      final rp = settings['role_permissions'];
      if (rp is Map) {
        perms.addAll({
          for (final e in rp.entries) e.key.toString(): '${e.value}' == 'true',
        });
      }
      final rawStage = settings['onboarding_stage']?.toString();
      final rawTemplates = settings['onboarding_templates'];
      final templates = rawTemplates is List
          ? rawTemplates
              .whereType<Map>()
              .map((item) => <String, String>{
                    for (final entry in item.entries)
                      entry.key.toString(): entry.value.toString(),
                  })
              .toList(growable: false)
          : null;
      // Existing families pre-date this marker and are established.
      final familyStage =
          rawStage == null || rawStage.isEmpty ? 'complete' : rawStage;
      // Setup is a family-admin responsibility. Invited adults, teens,
      // children and viewers must enter the shared experience directly,
      // even if the creator has not finished every optional setup step.
      final stage = state.user.role == Role.owner ? familyStage : 'complete';
      final rawCustomRate = settings['custom_rate'];
      final customRate = rawCustomRate is num
          ? rawCustomRate.toDouble()
          : double.tryParse('${rawCustomRate ?? ''}');
      await state.applyFamilySetupSettings(
        stage: stage,
        primary: settings['primary_currency']?.toString() ??
            spaceRow['base_currency']?.toString(),
        secondary: settings['secondary_currency']?.toString(),
        customRate: customRate,
        rateMode: settings['rate_mode']?.toString(),
        // The typed family_space column is authoritative. Older setup
        // versions also stored this in JSON and could leave the two values
        // out of sync, causing totals to jump after the settings pull.
        monthStart: int.tryParse(
            '${spaceRow['month_start_day'] ?? settings['month_start_day'] ?? ''}'),
        // Same precedence for the household timezone (spec #2): typed column
        // first, JSON settings fallback for spaces synced before 083.
        timezone: (spaceRow['timezone'] ?? settings['timezone'])?.toString(),
        templates: templates,
      );
    }
    if (settings is! Map) {
      await state.applyFamilySetupSettings(
        stage: 'complete',
        primary: spaceRow['base_currency']?.toString(),
        monthStart: int.tryParse('${spaceRow['month_start_day'] ?? ''}'),
        timezone: spaceRow['timezone']?.toString(),
      );
    }
    await state.applyRolePermissions(perms);
  }

  Future<void> _fullSync() async {
    final sid = _spaceId!;
    await _kvSet('sync_cursor', '');
    await _kvSet('sync_cursor_v2_$sid', '');
    for (final entity in kPullOrder) {
      await _kvSet('sync_cursor_$entity', '');
    }
    await _push();
    if (_isSyncV2(sid)) {
      final handled = await _pullV2(sid, full: true);
      if (handled) {
        lastSyncAt = DateTime.now();
        await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
        _setStatus(await _outbox.countConflicts() > 0
            ? SyncStatus.needsReview
            : SyncStatus.idle);
        await state.refreshPending();
        return;
      }
    }
    SyncException? pullError;
    try {
      await _pullSince(sid, full: true);
    } on SyncException catch (e) {
      pullError = e;
    }
    await _pullEnvelopeLinks(); // budget attribution across devices
    await _pullRate(); // latest server FX snapshot (unless user override)
    await _pullMembers(); // family roster: real names for everyone
    await _pullFamilySettings(); // owner's role switches → UI gates
    if (pullError != null) throw pullError;
    lastSyncAt = DateTime.now();
    await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
    _setStatus(await _outbox.countConflicts() > 0
        ? SyncStatus.needsReview
        : SyncStatus.idle);
    await state.refreshPending();
  }

  Future<void> _pullSince(String sid, {required bool full}) async {
    SyncException? firstError;
    final dirtyByEntity = await _outbox.dirtyIdsByEntity();
    for (final entity in kPullOrder) {
      final adapter = kSyncAdapters[entity]!;
      final key = 'sync_cursor_$entity';
      final stored = full ? null : await _kvGet(key);
      // `gt` can skip sibling rows committed with the same updated_at value.
      // Re-read a tiny overlap; merges are idempotent by row id.
      var since = stored == null || stored.isEmpty
          ? null
          : (DateTime.tryParse(stored)
                  ?.subtract(const Duration(milliseconds: 1))
                  .toUtc()
                  .toIso8601String() ??
              stored);
      try {
        var orderCol = adapter.orderCol;
        final dirtyIds = dirtyByEntity[entity] ?? const <String>{};
        var clearedAccounts = false;
        var page = 0;

        while (page < 20) {
          page++;
          List<Map<String, Object?>> rows;
          try {
            rows = await client.pullRows(
              adapter.table,
              orderCol: orderCol,
              sinceIso: since,
              spaceId: adapter.spaceScoped ? sid : null,
              spaceCol: adapter.spaceScoped ? 'space_id' : null,
              limit: 500,
            );
          } on SyncException catch (e) {
            if (orderCol == 'updated_at' &&
                e.statusCode == 400 &&
                e.message.contains('.updated_at does not exist')) {
              orderCol = 'created_at';
              rows = await client.pullRows(
                adapter.table,
                orderCol: orderCol,
                sinceIso: since,
                spaceId: adapter.spaceScoped ? sid : null,
                spaceCol: adapter.spaceScoped ? 'space_id' : null,
                limit: 500,
              );
            } else {
              rethrow;
            }
          }
          if (full && entity == 'account' && !clearedAccounts) {
            clearedAccounts = true;
            await _persistence.clearAccounts();
            state.clearAccountsForServerSnapshot(notify: rows.isEmpty);
          }
          if (rows.isEmpty) break;
          var maxCursor = since;
          for (final row in rows) {
            final ua = row[orderCol] ?? row['updated_at'] ?? row['created_at'];
            if (ua is String &&
                (maxCursor == null || ua.compareTo(maxCursor) > 0)) {
              maxCursor = ua;
            }
          }
          await _persistence.applyServerRows(entity, rows, dirtyIds: dirtyIds);
          final cleanRows = dirtyIds.isEmpty
              ? rows
              : [
                  for (final r in rows)
                    if (!dirtyIds.contains('${r['id'] ?? ''}')) r,
                ];
          if (cleanRows.isNotEmpty) {
            if (entity == 'tx') {
              state.applyPulled(entity, cleanRows, notify: false);
              try {
                await _pullEnvelopeLinks(notify: false);
              } finally {
                state.publishPulledMerge();
              }
            } else {
              state.applyPulled(entity, cleanRows);
            }
            if (entity == 'shopping_list') {
              await _captureDefaultList(cleanRows);
            }
          }
          if (maxCursor != null && maxCursor != since) {
            await _kvSet(key, maxCursor);
            since = maxCursor;
          } else {
            if (maxCursor != null) await _kvSet(key, maxCursor);
            break;
          }
          if (rows.length < 500) break;
        }
      } catch (e, st) {
        // A broken optional module must not prevent budgets or lists loading.
        // Its cursor stays unchanged, so missed rows retry next sync.
        reportError?.call('pull:$entity', e, st);
        firstError ??= e is SyncException
            ? e
            : SyncException(0, 'Could not refresh $entity data.');
      }
    }
    if (firstError != null) throw firstError;
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

class _CollapsedPushUnit {
  const _CollapsedPushUnit({
    required this.entity,
    required this.opId,
    required this.groupId,
    required this.outboxRowIds,
    required this.payload,
    required this.baseUpdatedAt,
    required this.basePayload,
  });

  final String entity;
  final String opId;
  final String? groupId;
  final List<int> outboxRowIds;
  final Map<String, Object?> payload;
  final String? baseUpdatedAt;
  final Map<String, Object?>? basePayload;

  factory _CollapsedPushUnit.fromOps(List<OutboxOp> ops) {
    final first = ops.first;
    final last = ops.last;
    final initialBaseUpdatedAt = first.payload['_base_updated_at']?.toString();
    final hasInitialBase =
        initialBaseUpdatedAt != null && initialBaseUpdatedAt.isNotEmpty;
    final mergedPayload = <String, Object?>{};
    for (final op in ops) {
      mergedPayload.addAll(op.payload);
    }
    if (hasInitialBase) {
      mergedPayload['_base_updated_at'] = initialBaseUpdatedAt;
    } else {
      mergedPayload.remove('_base_updated_at');
    }
    return _CollapsedPushUnit(
      entity: first.entity,
      opId: last.opId,
      groupId: first.groupId,
      outboxRowIds: [for (final op in ops) op.rowId],
      payload: mergedPayload,
      baseUpdatedAt: hasInitialBase ? initialBaseUpdatedAt : null,
      basePayload: hasInitialBase ? first.basePayload : null,
    );
  }
}

/// Collision-resistant client id for rows without a natural key
/// (goal_tx contributions): time-ordered, unique per device.
String newClientId() => newUuid();
