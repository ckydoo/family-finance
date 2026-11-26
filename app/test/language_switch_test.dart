import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/members/members_screen.dart';
import 'package:mhuri_money/features/settings/settings_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'Settings language picker omits Shona/Ndebele and switches cleanly',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: AnimatedBuilder(
          animation: state,
          builder: (context, _) => MaterialApp(
            locale: Locale(state.localeCode),
            localizationsDelegates: mhuriLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Language'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('chiShona'), findsNothing);
    expect(find.text('isiNdebele'), findsNothing);
    expect(find.text('Español'), findsWidgets);
    expect(find.text('Français'), findsWidgets);
    expect(find.text('Português'), findsWidgets);

    await tester.tap(find.text('Español').last);
    await tester.pumpAndSettle();

    expect(state.localeCode, 'es');
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Legacy removed codes safely normalize to English.
    state.setLocale('sn');
    expect(state.localeCode, 'en');
    state.setLocale('nd');
    expect(state.localeCode, 'en');
  });

  testWidgets('MembersScreen links cleanly to unified SettingsScreen',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MembersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('App & currency settings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('App & currency settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
