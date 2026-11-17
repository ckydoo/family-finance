import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Localization coverage guard.
///
/// Mhuri ships in six languages, so a user-facing sentence that is hard-coded
/// in English is a bug: those users see an untranslated screen. This test
/// locks the current backlog in `test/hardcoded_ui_strings.txt` and fails when
/// new hard-coded UI text appears.
///
/// Burning down the backlog is a mechanical job (add the key to the six ARBs,
/// then delete the line from the allowlist). Deleting a line that no longer
/// matches is harmless, so the list only ever shrinks by intent.
void main() {
  const candidates = [
    'Text(',
    'labelText:',
    'hintText:',
    'tooltip:',
    'title:',
    'subtitle:',
    'label:',
    'semanticLabel:',
  ];
  final literal = RegExp(r"'((?:[^'\\]|\\.)*)'");
  final hasLetter = RegExp('[A-Za-z]');
  final startsUpper = RegExp('^[A-Z]');

  test('no new hard-coded English UI strings in feature code', () {
    final allowlist = File('test/hardcoded_ui_strings.txt')
        .readAsLinesSync()
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toSet();

    final found = <String>{};
    for (final entity in Directory('lib/features').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (final line in lines) {
        if (line.contains('AppLocalizations')) continue;
        if (line.trimLeft().startsWith('//')) continue;
        if (!candidates.any(line.contains)) continue;
        for (final match in literal.allMatches(line)) {
          final text = match.group(1)!;
          if (!hasLetter.hasMatch(text)) continue;
          // Interpolated strings are assembled at runtime and their quoted
          // fragments are not prose (e.g. ${kid?.name ?? 'someone'}).
          if (text.contains(r'$')) continue;
          if (!startsUpper.hasMatch(text) && !text.contains(' ')) continue;
          if (text.startsWith('package:') ||
              text.contains('/') ||
              text.startsWith('#')) {
            continue;
          }
          found.add('${entity.path}|$text');
        }
      }
    }

    final regressions = found.difference(allowlist).toList()..sort();
    expect(
      regressions,
      isEmpty,
      reason: 'New hard-coded UI text found. Move these into the six ARB '
          'files (app_en/sn/nd/es/fr/pt.arb) and read them through '
          'AppLocalizations:\n${regressions.take(25).join('\n')}',
    );
  });
}
