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

  test('dark accent surfaces use a readable foreground', () {
    final theme = buildAppDarkTheme();
    const colors = MhuriColors.dark;

    expect(
      _contrast(theme.colorScheme.onSecondary, colors.accent),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(theme.badgeTheme.textColor!, colors.accentDark),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('dark Material surfaces use the app palette', () {
    final scheme = buildAppDarkTheme().colorScheme;
    const colors = MhuriColors.dark;

    expect(scheme.surfaceDim, colors.bg);
    expect(scheme.surfaceContainerLowest, colors.bg);
    expect(scheme.surfaceContainerLow, colors.card);
    expect(scheme.surfaceContainer, colors.card);
    expect(scheme.surfaceContainerHigh, colors.surfaceSecondary);
  });

  test('light accent foregrounds remain unchanged', () {
    final theme = buildAppTheme();

    expect(theme.colorScheme.onSecondary, MhuriColors.light.ink);
    expect(theme.badgeTheme.textColor, Colors.white);
  });

  for (final theme in <ThemeData>[buildAppTheme(), buildAppDarkTheme()]) {
    test('${theme.brightness.name} color scheme pairs stay legible', () {
      final scheme = theme.colorScheme;
      final pairs = <(Color, Color)>[
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondary, scheme.secondary),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onError, scheme.error),
        (scheme.onErrorContainer, scheme.errorContainer),
        (scheme.onSurface, scheme.surface),
      ];

      for (final pair in pairs) {
        expect(_contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
      }
    });
  }
}
