import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  for (final languageCode in ['sn', 'nd']) {
    testWidgets('$languageCode provides MaterialLocalizations', (tester) async {
      late BuildContext refreshContext;

      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(languageCode),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              refreshContext = context;
              return RefreshIndicator(
                onRefresh: () async {},
                child: ListView(
                  children: const [SizedBox(height: 900)],
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(MaterialLocalizations.of(refreshContext), isNotNull);
      expect(AppLocalizations.of(refreshContext), isNotNull);
      expect(tester.takeException(), isNull);
    });
  }
}
