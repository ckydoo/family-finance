import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final lighter = a.computeLuminance() > b.computeLuminance() ? a : b;
  final darker = identical(lighter, a) ? b : a;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}

void main() {
  for (final entry in <String, MhuriColors>{
    'light': MhuriColors.light,
    'dark': MhuriColors.dark,
  }.entries) {
    test('${entry.key} theme keeps text and semantic surfaces legible', () {
      final colors = entry.value;
      final pairs = <(String, Color, Color)>[
        ('primary text/background', colors.ink, colors.bg),
        ('primary text/card', colors.ink, colors.card),
        ('secondary text/background', colors.inkSoft, colors.bg),
        ('secondary text/card', colors.inkSoft, colors.card),
        ('success chip', colors.primaryDark, colors.successSoft),
        ('warning chip', colors.ink, colors.warningSoft),
        ('information chip', colors.ink, colors.infoSoft),
        ('violet chip', colors.ink, colors.violetSoft),
        ('danger chip', colors.expenseRed, colors.dangerSoft),
      ];

      for (final pair in pairs) {
        expect(
          _contrast(pair.$2, pair.$3),
          greaterThanOrEqualTo(4.5),
          reason: '${pair.$1} in ${entry.key} mode',
        );
      }
    });
  }
}
