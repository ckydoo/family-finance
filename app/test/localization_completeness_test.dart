import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 8 - Localization Completeness', () {
    final enFile = File('lib/l10n/app_en.arb');
    final enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
    final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();

    test('en.arb defines a healthy set of localized strings', () {
      expect(enKeys.length, greaterThan(150));
    });

    const targetLangs = ['es', 'fr', 'nd', 'pt', 'sn'];

    for (final lang in targetLangs) {
      test('app_$lang.arb contains translations for all keys defined in app_en.arb', () {
        final f = File('lib/l10n/app_$lang.arb');
        expect(f.existsSync(), isTrue, reason: 'app_$lang.arb must exist');

        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final keys = json.keys.where((k) => !k.startsWith('@')).toSet();
        final missing = enKeys.difference(keys);

        expect(
          missing,
          isEmpty,
          reason: 'Language "$lang" is missing ${missing.length} keys: ${missing.take(15).toList()}',
        );
      });
    }
  });
}

