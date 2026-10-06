import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../db/persistence.dart';
import '../models/models.dart' show Goal, InviteInfo, Role;
import '../money/money.dart';
import '../state/app_state.dart';
import '../utils/ids.dart';
import 'outbox.dart';
import '../observability/reporter.dart';
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
enum SyncStatus { idle, syncing, offline, needsSignIn, needsSetup, error }

/// Result of resolving the signed-in account's family before routing.
/// [unavailable] is deliberately distinct from [notFound]: a network failure
/// must never send an existing member to the create-family flow.
enum FamilyRestoreResult { restored, notFound, unavailable }

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
  bool _busy = false;

  SyncStatus status = SyncStatus.idle;
  String? lastError;
  DateTime? lastSyncAt;

  String? _spaceId;
  String? inviteCode;
  String? spaceName;

  /// M7 reliability: exponential backoff after failed syncs (8s→15min),
  /// poison batches parked after [maxAttempts] failed pushes (retry with
  /// `syncNow(force: true)` - the Members "Sync now" button), and a
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
    _spaceId = await _kvGet('space_id');
    spaceName = await _kvGet('space_name');
    inviteCode = await _kvGet('invite_code');

    if (!autoSchedule) return;

    // Pull-on-start once state hydration has finished.
    state.ready().then((_) {
      if (_spaceId != null) {
        syncNow();
      } else {
        state.refreshPending();
      }
    });

    // Family pushes normally trigger an immediate pull. This fallback keeps
    // devices current when notifications are disabled or delivery is delayed.
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_spaceId != null) syncNow();
    });
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
    }
    await _kvSet('cached_family_user_id', userId);
  }

  void dispose() {
    _timer?.cancel();
    _debounce?.cancel();
  }

  Future<int> pendingCount() => _outbox.count();

  // ── parked changes (never silently dropped) ──────────────────────────────
  // A change that failed [maxAttempts] pushes is held back from auto-sync
  // but stays in the outbox. Sync & data lists them with per-item retry
  // and discard - discard is the ONLY way a row leaves besides success,
  // and the UI confirms it first.

  Future<List<OutboxOp>> parked() => _outbox.parked(maxAttempts);

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
    if (_spaceId != null) return FamilyRestoreResult.restored;
    try {
      final r = await client.rpc('restore_my_space', {});
      if (r is! Map || r['space_id'] == null) {
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
      return FamilyRestoreResult.restored;
    } catch (e) {
      debugPrint('Mhuri restore error: $e');
      return FamilyRestoreResult.unavailable;
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
      });
      return true;
    } catch (e) {
      debugPrint('Mhuri role-permissions error: $e');
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

  /// Hands the family to another active member: roles swap, the family's
  /// static code moves with it, audit row written (migration 010).
  Future<void> transferOwnership(String newOwnerUserId) =>
      client.rpc('transfer_ownership', {'p_new_owner': newOwnerUserId});

  Future<String> updateFamilyName(String name) async {
    final result = await client.rpc('update_family_name', {'p_name': name});
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
    });
    await _pullMembers();
  }

  Future<void> removeFamilyMember(String memberId) async {
    await client.rpc('remove_family_member', {'p_member': memberId});
    await _pullMembers();
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
      _setStatus(SyncStatus.offline, 'Network error - try again.');
    }
  }

  Future<bool> joinSpace(String code) async {
    final normalized = code.trim().toUpperCase();
    // Role-bound invitations use six characters after MHRI- and are
    // single-use. Four-character codes are the legacy reusable family code.
    // Keep the latter working for already printed/shared codes while routing
    // every new invitation through join_invite.
    final roleBound = RegExp(r'^MHRI-[A-Z0-9]{6}$').hasMatch(normalized);
    try {
      _setStatus(SyncStatus.syncing);
      final id = await client.rpc(
        roleBound ? 'join_invite' : 'join_space',
        {'p_code': normalized},
      );
      if (id == null) {
        throw const SyncException(0, 'unexpected response from server');
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

  Future<void> syncNow({bool force = false}) async {
    if (_busy) return;
    final sid = _spaceId;
    if (sid == null) {
      _setStatus(SyncStatus.needsSetup);
      return;
    }
    final hasOnlyParked = !force &&
        await _outbox.count() > 0 &&
        await _outbox.countParked(maxAttempts) == await _outbox.count();
    if (!force &&
        !hasOnlyParked &&
        _nextPushOkAt != null &&
        DateTime.now().isBefore(_nextPushOkAt!)) {
      return; // backing off - the periodic poll will try again
    }
    _busy = true;
    _setStatus(SyncStatus.syncing);
    // Phase 4 #19: correlation id + duration for the sync-health events.
    final run = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final sw = Stopwatch()..start();
    try {
      try {
        await _push(force: force);
        await _pull(sid);
      } on SyncException catch (e) {
        // Access token expired mid-session: force one refresh and retry the
        // pass exactly once. Still 401 → rethrown → needsSignIn below.
        if (!e.isAuthError || retryAuth == null) {
          if (e.isAuthError) {
            state.auth?.handleForcedLogout(reason: e.message);
          }
          rethrow;
        }
        final refreshed = await retryAuth!();
        if (!refreshed) {
          state.auth?.handleForcedLogout(reason: e.message);
          rethrow;
        }
        await _push(force: force);
        await _pull(sid);
      }
      lastSyncAt = DateTime.now();
      await _kvSet('last_sync_ms', '${lastSyncAt!.millisecondsSinceEpoch}');
      _consecFail = 0;
      _nextPushOkAt = null;
      _setStatus(SyncStatus.idle);
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
        '$parked change(s) are parked - use "Sync now" to retry them.',
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
        // Sprint B: budget attribution rides with transaction pushes - the
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
                  'currency': byId[o.payload['id']]!.amount.currency.code,
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
    if (pullError != null) throw pullError;
  }

  /// Full resync (right after adopting a space): forget the cursor, pull all.
  /// Pulls the envelope_tx junction and mirrors it into local tx.envelopeId,
  /// so budget attribution follows the family across devices. Full-refresh
  /// semantics: the server is the truth for links (upserts are idempotent,
  /// conflicts are rare single-field edits).
  Future<void> _pullEnvelopeLinks() async {
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
          monthStart: int.tryParse('${settings['month_start_day'] ?? ''}'),
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
        state.applyPulled(entity, rows);
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
