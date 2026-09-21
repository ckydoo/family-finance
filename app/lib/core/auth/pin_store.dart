import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'supabase_auth_service.dart' show KvGetter, KvSetter;

/// Hashed PIN storage (M2).
///
///  * `pin_<memberId>` — a kid/teen profile PIN (parent sets it; M4 uses it
///    when handing a shared device to a specific child).
///  * `pin_parent` — the PIN required to leave Kids Mode.
///
/// PINs are stored as salted SHA-256, never plaintext. A 4–6 digit PIN is a
/// *gating* control (stops a child tapping through), not bank-grade security —
/// the honest note is in the README.
class PinStore {
  PinStore({KvGetter? kvGet, KvSetter? kvSet})
      : _get = kvGet,
        _set = kvSet;

  final KvGetter? _get;
  final KvSetter? _set;

  /// In-memory fallback for demo mode without a database and for tests.
  final Map<String, String> _memory = {};

  static const parentKey = 'pin_parent';

  String _hash(String memberId, String pin) =>
      sha256.convert(utf8.encode('mhuri:$memberId:$pin')).toString();

  String _storageKey(String memberId) => 'pin_$memberId';

  Future<void> setPin(String memberId, String pin) async {
    final set = _set;
    final key = _storageKey(memberId);
    final hashed = _hash(memberId, pin);
    if (set != null) {
      await set(key, hashed);
    } else {
      _memory[key] = hashed;
    }
  }

  Future<void> clearPin(String memberId) async {
    final set = _set;
    final key = _storageKey(memberId);
    if (set != null) {
      await set(key, '');
    } else {
      _memory.remove(key);
    }
  }

  Future<bool> hasPin(String memberId) async {
    final stored = await _read(memberId);
    return stored != null && stored.isNotEmpty;
  }

  /// Verifies a PIN. If no PIN was ever set:
  ///  * for the parent key, the demo default `1234` is accepted (so today's
  ///    demo flow keeps working until the parent sets a real PIN);
  ///  * for kid profiles, no PIN means the profile simply opens (nothing to
  ///    protect yet — parents opt in by setting one).
  Future<bool> verifyPin(String memberId, String pin) async {
    final candidate = pin.trim();
    if (candidate.isEmpty) return false;
    final stored = await _read(memberId);
    if (stored == null || stored.isEmpty) {
      return memberId == parentKey && candidate == '1234';
    }
    return stored == _hash(memberId, candidate);
  }

  Future<String?> _read(String memberId) async {
    final key = _storageKey(memberId);
    final get = _get;
    if (get != null) {
      return get(key);
    }
    return _memory[key];
  }
}
