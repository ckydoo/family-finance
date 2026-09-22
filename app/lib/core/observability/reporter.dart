import 'package:flutter/foundation.dart';

/// ── Observability seam (Phase 4 #19) ────────────────────────────────────────
/// Errors and sync-health events flow through ONE interface. Wiring a crash
/// backend later (Sentry / Crashlytics — SENTRY_DSN already reserved in
/// AppEnv) means implementing [MhuriReporter] and assigning [activeReporter]
/// in main() — no call-site changes anywhere else in the app.
///
/// HARD RULE (PRODUCT_SPEC 9.0): never log secrets or amounts. No tokens,
/// keys, emails, balances or transaction values ever reach a reporter —
/// [redactFields] strips sensitive-named fields defensively, and event
/// call sites must pass counts/durations/statuses only, never payloads.
abstract class MhuriReporter {
  void error(String where, Object e, StackTrace? st);
  void event(String name, Map<String, Object?> fields);
}

/// Fields whose names look sensitive are dropped before any backend sees
/// them. Values that ARE safe (counts, durations, status names) pass through.
const Set<String> _sensitiveKeys = {
  'token', 'key', 'secret', 'password', 'email',
  'amount', 'balance', 'total', 'value', 'code', 'url', 'payload',
};

Map<String, Object?> redactFields(Map<String, Object?> fields) => {
      for (final e in fields.entries)
        if (!_sensitiveKeys.contains(e.key.toLowerCase())) e.key: e.value,
    };

/// Default reporter: debugPrint only — exactly the pre-#19 behaviour, now
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
