import 'package:flutter/foundation.dart';

/// ── Observability seam (Phase 4 #19) ────────────────────────────────────────
/// Errors and sync-health events flow through ONE interface. Wiring a crash
/// backend later (Sentry / Crashlytics - SENTRY_DSN already reserved in
/// AppEnv) means implementing [MhuriReporter] and assigning [activeReporter]
/// in main() - no call-site changes anywhere else in the app.
///
/// HARD RULE (PRODUCT_SPEC 9.0): never log secrets or amounts. No tokens,
/// keys, emails, balances or transaction values ever reach a reporter -
/// [redactFields] strips sensitive-named fields defensively, and event
/// call sites must pass counts/durations/statuses only, never payloads.
abstract class MhuriReporter {
  void error(String where, Object e, StackTrace? st);
  void event(String name, Map<String, Object?> fields);
}

/// Fields whose names look sensitive are dropped before any backend sees
/// them. Values that ARE safe (counts, durations, status names) pass through.
const Set<String> _sensitiveKeys = {
  'token',
  'key',
  'secret',
  'password',
  'email',
  'amount',
  'minor',
  'balance',
  'total',
  'value',
  'code',
  'url',
  'payload',
  'note',
  'notes',
  'receipt',
  'receipt_uri',
  'family_name',
  'space_name',
  'member_name',
  'person_name',
  'message',
  'text',
  'content',
  'name',
  'reason',
};

const List<String> _sensitiveKeyTokens = [
  'token',
  'secret',
  'password',
  'email',
  'amount',
  'balance',
  'note',
  'receipt',
  'family_name',
  'space_name',
  'message',
  'payload',
];

bool _isSensitiveKey(String key) {
  final normalized = key.trim().toLowerCase();
  if (_sensitiveKeys.contains(normalized)) return true;
  for (final token in _sensitiveKeyTokens) {
    if (normalized.contains(token)) return true;
  }
  return false;
}

Map<String, Object?> redactFields(Map<String, Object?> fields) => {
      for (final e in fields.entries)
        if (!_isSensitiveKey(e.key)) e.key: e.value,
    };

/// Standardised 9.3 Experience Plan privacy-safe event names.
abstract final class MhuriAnalyticsEvents {
  static const String quickAddOpened = 'quick_add_opened';
  static const String quickAddCompleted = 'quick_add_completed';
  static const String transactionSaved = 'transaction_saved';
  static const String transactionCancelled = 'transaction_cancelled';
  static const String transactionUndoSelected = 'transaction_undo_selected';
  static const String onboardingStepStarted = 'onboarding_step_started';
  static const String onboardingStepCompleted = 'onboarding_step_completed';
  static const String onboardingStepAbandoned = 'onboarding_step_abandoned';
  static const String guidedFirstJourneyCompleted =
      'guided_first_journey_completed';
  static const String homeNextActionOpened = 'home_next_action_opened';
  static const String familyInviteOpened = 'family_invite_opened';
  static const String familyInviteAccepted = 'family_invite_accepted';
  static const String familyInviteFailed = 'family_invite_failed';
  static const String weeklySummaryViewed = 'weekly_summary_viewed';
  static const String weeklySummaryShared = 'weekly_summary_shared';
  static const String syncRecoveryOpened = 'sync_recovery_opened';
}

/// Captures redacted events in memory for baseline and experience tests.
class InMemoryReporter implements MhuriReporter {
  final List<({String name, Map<String, Object?> fields})> events = [];
  final List<({String where, Object error})> errors = [];

  @override
  void error(String where, Object e, StackTrace? st) {
    errors.add((where: where, error: e));
  }

  @override
  void event(String name, Map<String, Object?> fields) {
    events.add((name: name, fields: redactFields(fields)));
  }

  void clear() {
    events.clear();
    errors.clear();
  }
}

/// Default reporter: debugPrint only - exactly the pre-#19 behaviour, now
/// structured. Release crash reporting swaps this class, not the call sites.
class DebugReporter implements MhuriReporter {
  const DebugReporter();

  @override
  void error(String where, Object e, StackTrace? st) {
    debugPrint('Mhuri[$where]: $e');
    if (kDebugMode && st != null) debugPrint('  $st');
  }

  @override
  void event(String name, Map<String, Object?> fields) {
    debugPrint('Mhuri·$name ${redactFields(fields)}');
  }
}

/// The active reporter (set once in main()). Null until then = silent.
MhuriReporter? activeReporter;

/// One-off events from UI/engine code (account deletion requested, a parked
/// op retried or discarded). Fields are redacted defensively.
void mhuriEvent(String name, [Map<String, Object?> fields = const {}]) {
  activeReporter?.event(name, redactFields(fields));
}
