import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/widgets/app_icons.dart';

/// M8 polish — icon coverage: every semantic icon KEY used by the seed data
/// (envelopes, goals, accounts, members, recurring) must resolve to a
/// Material icon, so the UI never falls back to the neutral label icon.
void main() {
  test('every seed icon key maps to a Material icon', () {
    const seedKeys = [
      // members
      'man', 'woman', 'boy', 'baby', 'student', 'grandma',
      // accounts
      'bank', 'cash', 'wallet',
      // envelopes & recurring
      'cart', 'school', 'fuel', 'power', 'airtime', 'stars', 'lifebuoy',
      'giving', 'home', 'water',
      // goals
      'beach', 'bike', 'laptop',
      // defaults used by persistence/sync/sheets
      'money', 'receipt', 'autorenew', 'goal', 'person',
    ];
    final missing = [for (final k in seedKeys) if (iconForKey(k) == null) k];
    expect(missing, isEmpty, reason: 'unmapped icon keys: $missing');
  });

  test('unknown keys resolve to null → callers draw the neutral icon', () {
    expect(iconForKey('unicorn'), isNull);
    expect(iconForKey(null), isNull);
    expect(iconForKey('cart'), Icons.shopping_cart);
    expect(iconForKey('school'), Icons.school);
  });
}
