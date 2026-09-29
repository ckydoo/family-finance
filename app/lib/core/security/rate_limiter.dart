/// In-memory rate limiter with sliding window and lockout support.
class RateLimiter {
  RateLimiter({
    this.maxAttempts = 5,
    this.window = const Duration(minutes: 1),
    this.lockoutDuration = const Duration(minutes: 1),
  });

  final int maxAttempts;
  final Duration window;
  final Duration lockoutDuration;

  final Map<String, List<DateTime>> _attempts = {};
  final Map<String, DateTime> _lockouts = {};

  bool isAllowed(String key, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final lockedUntil = _lockouts[key];
    if (lockedUntil != null && current.isBefore(lockedUntil)) {
      return false;
    }
    _cleanOldAttempts(key, current);
    return (_attempts[key]?.length ?? 0) < maxAttempts;
  }

  /// Records an attempt. Returns true if the attempt was allowed,
  /// or false if it was already locked out or this attempt triggered a lockout.
  bool recordAttempt(String key, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (!isAllowed(key, now: current)) {
      return false;
    }

    final list = _attempts.putIfAbsent(key, () => []);
    list.add(current);
    if (list.length >= maxAttempts) {
      _lockouts[key] = current.add(lockoutDuration);
      return false;
    }
    return true;
  }

  Duration? timeUntilReset(String key, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final lockedUntil = _lockouts[key];
    if (lockedUntil != null && current.isBefore(lockedUntil)) {
      return lockedUntil.difference(current);
    }
    _cleanOldAttempts(key, current);
    final list = _attempts[key];
    if (list == null || list.isEmpty) return null;
    final oldest = list.first;
    final diff = window - current.difference(oldest);
    return diff.isNegative ? null : diff;
  }

  void reset(String key) {
    _attempts.remove(key);
    _lockouts.remove(key);
  }

  void _cleanOldAttempts(String key, DateTime current) {
    final list = _attempts[key];
    if (list == null) return;
    list.removeWhere((t) => current.difference(t) > window);
    if (list.isEmpty) {
      _attempts.remove(key);
    }
  }
}
