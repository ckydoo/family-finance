import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/members/members_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('profile switcher scrolls without overflowing a phone screen',
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
      find.text('Switch profile'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Switch profile').first);
    await tester.pumpAndSettle();

    expect(find.byType(ListView), findsAtLeastNWidgets(2));
    expect(find.text('Zoe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
