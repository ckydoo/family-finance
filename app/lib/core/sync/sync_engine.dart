import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../db/persistence.dart';
import '../models/models.dart' show FamilyChatMessage, Goal, InviteInfo, Role;
import '../money/money.dart';
import '../state/app_state.dart';
import '../utils/ids.dart';
import 'outbox.dart';
import '../observability/reporter.dart';
import '../billing/entitlement.dart';
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
  final bool autoSchedule;

  /// Forces a token refresh after a 401 and lets [syncNow] retry exactly
  /// once before surfacing "sign in". Null (tests) = no retry.
  final Future<bool> Function()? retryAuth;

  Timer? _timer;
  Timer? _debounce;
  Timer? _reconcileTimer;
  Future<void>? _activeSync;
  Future<void>? _activeChatRefresh;
  bool _reconciling = false;

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
  /// stops automatic delivery. A
  /// pluggable error-report hook (wire Sentry/Crashlytics here in live
  /// mode; optional SENTRY_DSN env stays post-8).
  static const int maxAttempts = 8;
  static void Function(String where, Object error, StackTrace stack)?
      reportError;
  int _consecFail = 0;
  DateTime? _nextPushOkAt;

  String? get spaceId => _spaceId;
  bool get spaceIdentityLoaded => _spaceIdentityLoaded;
  bool get familySetupResolutionComplete => _familySetupResolutionComplete;

  // ── lifecycle ───────────────────────────────────────────────────────────

  Future<void> start() async {
    _spaceIdentityLoaded = false;
    _familySetupResolutionComplete = false;
    state.syncIdentityChanged();
    _spaceId = await _kvGet('space_id');
    spaceName = await _kvGet('space_name');
    inviteCode = await _kvGet('invite_code');
    _spaceIdentityLoaded = true;
    _familySetupResolutionComplete = _spaceId != null;
    state.syncIdentityChanged();

    if (!autoSchedule) return;

    // Pull-on-start once state hydration has finished.
    state.ready().then((_) async {
      if (_spaceId != null) {
        await _syncOrReconcile();
      } else {
        await state.refreshPending();
      }
    });

    // Family pushes normally trigger an immediate pull. This fallback keeps
    // devices current when notifications are disabled or delivery is delayed.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_spaceId != null) syncNow();
    });
    // Cursor sync is efficient, while a periodic full snapshot makes it
    // self-healing if OS backup/restore resurrects a cursor without all of
    // its corresponding rows. The versioned marker also forces one complete
    // reconciliation after this reliability fix ships.
    _reconcileTimer = Timer.periodic(const Duration(hours: 6), (_) {
      if (_spaceId != null) _syncOrReconcile();
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
        await state.refresh();
      }
      _spaceIdentityLoaded = true;
      _familySetupResolutionComplete = _spaceId != null;
      state.syncIdentityChanged();
    }
    await _kvSet('cached_family_user_id', userId);
  }

  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
    _reconcileTimer?.cancel();
  }

  Future<int> pendingCount() => _outbox.count();

  // ── parked changes (never silently dropped) ──────────────────────────────
  // A change that failed [maxAttempts] pushes is surfaced in Sync & data but
  // remains part of every automatic retry. It is never silently dropped.

  Future<List<OutboxOp>> parked() => _outbox.parked(maxAttempts);

  Future<List<OutboxOp>> conflicts() => _outbox.conflicts();

  Future<int> conflictCount() => _outbox.countConflicts();

  Future<void> keepLocalConflict(int rowId) => _outbox.clearConflict(rowId);

  Future<void> acceptServerConflict(OutboxOp op) async {
    final server = op.serverPayload;
    if (server == null) return;
    await _persistence.applyServerRows(op.entity, [server]);
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
      await _adoptSpace(
        id: r['space_id'].toString(),
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
    return result
        .whereType<Map>()
        .map((row) => FamilySpaceSummary.fromJson(row))
        .where((space) => space.id.isNotEmpty && space.id != 'null')
        .toList(growable: false);
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
  Future<void> enqueue(String entity, Object domain) async {
    final sid = _spaceId;
    if (sid == null) return;
    try {
      final adapter = kSyncAdapters[entity]!;
      final payload = adapter.encode(
        domain,
        SyncCtx(
          spaceId: sid,
          actorId: state.realUser.id,
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
      await _persistence.applyServerRows(entity, rows);
      state.applyPulled(entity, rows);
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
  }) async {
    try {
      if (!await _flushBeforeChangingSpace()) return false;
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
            'FAMILY_NAME_TAKEN: That family name is already taken - try another.');
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

  Future<bool> saveFamilyMonthStart(int day) async {
    final sid = _spaceId;
    if (sid == null || day < 1 || day > 31) return false;
    try {
      await client.rpc('set_family_month_start', {
        'p_space_id': sid,
        'p_day': day,
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

  Future<bool> saveFamilySetup({
    required Currency primary,
    required Currency? secondary,
    required int monthStart,
    required List<Map<String, String>> templates,
    required String stage,
  }) async {
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

    // The RPC above is the setup commit. A refresh failure after that point
    // must not send the wizard backwards or encourage a duplicate retry. The
    // locally persisted setup is enough to continue; normal sync will refresh
    // the server-created envelopes when connectivity recovers.
    try {
      await _fullSync();
    } catch (e) {
      debugPrint('Mhuri post-setup refresh error: $e');
      _setStatus(
          SyncStatus.offline, 'Setup saved. We will refresh it shortly.');
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

  Future<void> voteFamilyChatPoll(String pollId, List<int> optionIndexes) async {
    await client.rpc('vote_family_chat_poll', {
      'p_poll_id': pollId,
      'p_option_indexes': optionIndexes,
    });
  }

  Future<void> closeFamilyChatPoll(String pollId) async {
    await client.rpc('close_family_chat_poll', {'p_poll_id': pollId});
  }

  Future<void> setFamilyChatPin(String messageId, {required bool pinned}) async {
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
    int limit = 250,
  }) async {
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
      'p_offset': 0,
    });
    if (result is! List) return const [];
    final adapter = kSyncAdapters['family_chat_message']!;
    return [
      for (final raw in result)
        if (raw is Map)
          adapter.decode(Map<String, Object?>.from(raw)) as FamilyChatMessage,
    ];
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
    // Any list id from a previous family is void - the join path relearns it
    // from the shopping_list header pull; the create path sets it from the
    // RPC result right after this.
    await _kvSet('default_list_id', '');
    await _kvSet('sync_cursor', ''); // retire the unsafe shared cursor
    for (final entity in kPullOrder) {
      await _kvSet('sync_cursor_$entity', '');
    }

    // Fresh family start on this device: clear synced tables + outbox.
    await _persistence.wipeSynced();
    await _outbox.clear();
    state.onSpaceAdopted(spaceName: name);

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
        await _detectConflicts();
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
        await _detectConflicts();
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
  };

  /// Family tasks pre-dated their server table. On the first sync after this
  /// upgrade, publish this family's existing local tasks exactly once so they
  /// do not disappear for the people who already created them.
  Future<void> _backfillLocalFamilyTasks(String sid) async {
    if (!state.canManageFamilyTasks || state.familyTasks.isEmpty) return;
    final key = 'family_tasks_backfilled_v1_$sid';
    if (await _kvGet(key) == '1') return;
    for (final task in state.familyTasks) {
      await enqueue('family_task', task);
    }
    await _kvSet(key, '1');
  }

  Future<void> _detectConflicts() async {
    final pending = (await _outbox.take(200))
        .where((op) => _conflictEntities.contains(op.entity))
        .toList();
    final grouped = <String, List<OutboxOp>>{};
    for (final op in pending) {
      if (op.payload['id'] == null) continue;
      grouped.putIfAbsent(op.entity, () => []).add(op);
    }
    for (final entry in grouped.entries) {
      final adapter = kSyncAdapters[entry.key]!;
      final ids = entry.value.map((op) => op.payload['id']).join(',');
      final rows = await client.pullRows(adapter.table,
          orderCol: 'updated_at', eqFilters: {'id': 'in.($ids)'}, limit: 200);
      final byId = {for (final row in rows) '${row['id']}': row};
      for (final op in entry.value) {
        final remote = byId['${op.payload['id']}'];
        if (remote == null || _samePayload(op.payload, remote)) continue;
        final updated = DateTime.tryParse('${remote['updated_at']}');
        if (updated == null) continue;
        final queued =
            DateTime.fromMillisecondsSinceEpoch(op.createdMs).toUtc();
        // The server row changing even a millisecond after this operation was
        // queued means another device won the race while this device was
        // offline. Do not add a grace window here: fast reconnects are the
        // exact case where silent last-write-wins data loss is most likely.
        if (updated.toUtc().isAfter(queued)) {
          await _outbox.markConflict(
              op.rowId, 'This record changed on another device.', remote);
        }
      }
    }
  }

  bool _samePayload(Map<String, Object?> local, Map<String, Object?> remote) {
    for (final entry in local.entries) {
      if (entry.key == 'updated_at') continue;
      if ('${entry.value ?? ''}' != '${remote[entry.key] ?? ''}') return false;
    }
    return true;
  }

  /// One row per `id`, merged in queue order (later fields win). Rows
  /// without an id are passed through untouched.
  static List<Map<String, Object?>> _collapseById(
      List<Map<String, Object?>> payloads) {
    final merged = <String, Map<String, Object?>>{};
    final out = <Map<String, Object?>>[];
    for (final p in payloads) {
      final id = p['id'];
      if (id == null) {
        out.add(p);
        continue;
      }
      final existing = merged['$id'];
      if (existing == null) {
        final copy = Map<String, Object?>.of(p);
        merged['$id'] = copy;
        out.add(copy);
      } else {
        existing.addAll(p);
      }
    }
    return out;
  }

  /// Ordered, grouped, verbatim push. A failed entity batch stays in the
  /// outbox (attempts++) and retries on the next sync.
  Future<void> _push() async {
    final taken = await _outbox.take(200);
    if (taken.isEmpty) return;
    // Attempts are diagnostic only. Long-failing rows remain eligible so
    // they upload automatically when Supabase or connectivity recovers.
    final ops = taken;

    final byEntity = <String, List<OutboxOp>>{};
    for (final op in ops) {
      byEntity.putIfAbsent(op.entity, () => []).add(op);
    }

    var allOk = true;
    final doneRowIds = <int>[];
    for (final entry in byEntity.entries) {
      final adapter = kSyncAdapters[entry.key]!;
      // Several edits to the same record (e.g. a list item moved to the
      // cart, then checked out) queue several ops. One upsert statement may
      // not touch a row twice - Postgres rejects the whole batch with
      // "ON CONFLICT DO UPDATE command cannot affect row a second time" - so
      // collapse them in queue order, later fields winning.
      final rows = _collapseById([for (final o in entry.value) o.payload]);
      try {
        await client.pushRows(adapter.table, rows);
        if (entry.key == 'family_chat_message') {
          state.markChatMessagesSent(rows.map((row) => row['id'].toString()));
        }
        // Sprint B: budget attribution rides with transaction pushes - the
        // server models it as the envelope_tx junction (no envelope_id col).
        if (entry.key == 'tx') {
          final byId = {for (final t in state.txs) t.id: t};
          final links = <Map<String, Object?>>[
            for (final row in rows)
              if (byId[row['id']]?.envelopeId case final envId?
                  when envId.isNotEmpty)
                {
                  'envelope_id': envId,
                  'transaction_id': row['id'],
                  'allocated_minor': byId[row['id']]!.amount.minor,
                  'currency': byId[row['id']]!.amount.currency.code,
                },
          ];
          if (links.isNotEmpty) {
            await client.pushRows(
              'envelope_tx',
              links,
              onConflict: 'envelope_id,transaction_id',
            );
          }
        }
        // A transaction is complete only after its envelope attribution is
        // durable too. Both idempotent writes retry together on failure.
        doneRowIds.addAll(entry.value.map((o) => o.rowId));
      } on SyncException catch (e) {
        if (e.isAuthError) rethrow;
        debugPrint('Mhuri push failed [${entry.key} → ${adapter.table}, '
            '${entry.value.length} op(s)]: $e');
        reportError?.call('push:${entry.key}', e, StackTrace.current);
        allOk = false;
      }
    }

    if (doneRowIds.isNotEmpty) await _outbox.deleteRows(doneRowIds);
    if (!allOk) {
      await _outbox.bumpAttempts([for (final op in ops) op.rowId]);
      throw const SyncException(0, 'some changes have not been pushed yet');
    }
  }

  Future<void> _pull(String sid) async {
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

  /// Full resync (right after adopting a space): forget the cursor, pull all.
  /// Pulls the envelope_tx junction and mirrors it into local tx.envelopeId,
  /// so budget attribution follows the family across devices. Full-refresh
  /// semantics: the server is the truth for links (upserts are idempotent,
  /// conflicts are rare single-field edits).
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
    await state.applyEnvelopeLinks(links, notify: notify);
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
      final name = rows.first['name']?.toString();
      if (name != null && name.trim().isNotEmpty) {
        spaceName = name.trim();
        await _kvSet('space_name', spaceName!);
        state.adoptSpaceName(spaceName!);
      }
      final settings = rows.first['settings'];
      final perms = <String, bool>{};
      if (settings is Map) {
        final rp = settings['role_permissions'];
        if (rp is Map) {
          perms.addAll({
            for (final e in rp.entries)
              e.key.toString(): '${e.value}' == 'true',
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
        await state.applyFamilySetupSettings(
          stage: stage,
          primary: settings['primary_currency']?.toString() ??
              rows.first['base_currency']?.toString(),
          secondary: settings['secondary_currency']?.toString(),
          // The typed family_space column is authoritative. Older setup
          // versions also stored this in JSON and could leave the two values
          // out of sync, causing totals to jump after the settings pull.
          monthStart: int.tryParse(
              '${rows.first['month_start_day'] ?? settings['month_start_day'] ?? ''}'),
          templates: templates,
        );
      }
      if (settings is! Map) {
        await state.applyFamilySetupSettings(stage: 'complete');
      }
      await state.applyRolePermissions(perms);
    } catch (_) {
      // Non-fatal - defaults keep the UI consistent with the server defaults.
    }
  }

  Future<void> _fullSync() async {
    await _kvSet('sync_cursor', '');
    for (final entity in kPullOrder) {
      await _kvSet('sync_cursor_$entity', '');
    }
    await _push();
    SyncException? pullError;
    try {
      await _pullSince(_spaceId!, full: true);
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
    _setStatus(SyncStatus.idle);
    await state.refreshPending();
  }

  Future<void> _pullSince(String sid, {required bool full}) async {
    SyncException? firstError;
    for (final entity in kPullOrder) {
      final adapter = kSyncAdapters[entity]!;
      final key = 'sync_cursor_$entity';
      final stored = full ? null : await _kvGet(key);
      // `gt` can skip sibling rows committed with the same updated_at value.
      // Re-read a tiny overlap; merges are idempotent by row id.
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
          spaceId: adapter.spaceScoped ? sid : null,
          spaceCol: adapter.spaceScoped ? 'space_id' : null,
        );
        if (full && entity == 'account') {
          // Accounts used to be device-local. A successful full pull is the
          // authoritative snapshot, including an empty result.
          await _persistence.clearAccounts();
          state.clearAccountsForServerSnapshot(notify: rows.isEmpty);
        }
        if (rows.isEmpty) continue;
        var maxCursor = since;
        for (final row in rows) {
          final ua = row['updated_at'];
          if (ua is String &&
              (maxCursor == null || ua.compareTo(maxCursor) > 0)) {
            maxCursor = ua;
          }
        }
        await _persistence.applyServerRows(entity, rows);
        if (entity == 'tx') {
          // A transaction and its budget attribution are stored in separate
          // server tables. Keep this merge invisible until both have landed,
          // otherwise the home screen briefly renders an unallocated expense.
          state.applyPulled(entity, rows, notify: false);
          try {
            await _pullEnvelopeLinks(notify: false);
          } finally {
            state.publishPulledMerge();
          }
        } else {
          state.applyPulled(entity, rows);
        }
        if (entity == 'shopping_list') await _captureDefaultList(rows);
        if (maxCursor != null) await _kvSet(key, maxCursor);
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

/// Collision-resistant client id for rows without a natural key
/// (goal_tx contributions): time-ordered, unique per device.
String newClientId() => newUuid();
