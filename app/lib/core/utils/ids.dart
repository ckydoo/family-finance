import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;

/// UUID helpers for client-minted row ids.
///
/// Every server id column is `uuid` (gen_random_uuid() on the server side),
/// so anything pushed from a device must already be a well-formed uuid —
/// sequential ids like `tx0` would fail the cast on real Postgres.

/// Random RFC-4122 v4 uuid — use for every NEW client-created row.
String newUuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40; // version 4
  b[8] = (b[8] & 0x3f) | 0x80; // RFC 4122 variant
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Deterministic uuid from a seed — same seed on every device yields the
/// same row id (used for singleton rows like the family savings circle).
String uuidFromSeed(String seed) {
  final h = crypto.md5.convert(utf8.encode(seed)).toString();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
