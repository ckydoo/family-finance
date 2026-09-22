import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/features/settings/settings_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  Widget harness(AppState state, Widget screen) => AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      );

  testWidgets('mukando activation lives in Settings, not Savings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();

    await tester.pumpWidget(harness(state, const SavingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Turn on mukando'), findsNothing);
    expect(find.textContaining('Mukando —'), findsNothing);

    await tester.pumpWidget(harness(state, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Savings circle (mukando)'), findsOneWidget);
    expect(find.byType(SwitchListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
