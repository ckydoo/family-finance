import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/members/invite_screen.dart';
import 'package:mhuri_money/features/members/members_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('family header uses stored data and never fixture text',
      (tester) async {
    final state = AppState();
    state.space = const FamilySpace(name: 'The Moyo Family');
    state.monthStartDay = 25;
    state.members.add(state.user);

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

    expect(find.text('The Moyo Family'), findsOneWidget);
    expect(find.text('Budget cycle starts on day 25'), findsOneWidget);
    expect(find.text('The Taylor Family'), findsNothing);
    expect(find.text('MHRI-4F2K'), findsNothing);
  });

  testWidgets('primary invite action opens role-bound invite management',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);

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

    await tester.tap(find.text('Invite family member'));
    await tester.pumpAndSettle();

    expect(find.text('New invite'), findsOneWidget);
    expect(find.text('Adult'), findsOneWidget);
    expect(find.text('Teen'), findsOneWidget);
    expect(find.text('Child'), findsOneWidget);
    expect(find.text('Create account for member'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assisted member account is separate from invite-code flow',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: InviteScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create invite'), findsOneWidget);
    await tester.tap(find.text('Create account for member'));
    await tester.pumpAndSettle();

    expect(find.text('Preferred name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Temporary password'), findsOneWidget);
    expect(find.text('Parent'), findsAtLeastNWidgets(1));
    expect(find.text('Create invite'), findsOneWidget,
        reason: 'the original invite flow remains behind the modal');
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile switcher scrolls without overflowing a phone screen',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    state.members.addAll(const [
      Member(id: 'm_owner', name: 'Farai', emoji: '👑', role: Role.owner),
      Member(id: 'm_zoe', name: 'Zoe', emoji: '🎨', role: Role.teen),
    ]);

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

  testWidgets('Kids Mode exit PIN accepts and saves six digits',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    state.members.add(state.user);

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
      find.text('Kids Mode exit PIN'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kids Mode exit PIN'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '998877');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '998877',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(await state.pinStore.verifyPin('pin_parent', '998877'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy chore records remain editable under points and rewards',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    state.members.add(state.user);

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
      find.text('Points & rewards'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Points & rewards'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add legacy chore'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Wash the car');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add chore'));
    await tester.pumpAndSettle();

    expect(state.chores.single.name, 'Wash the car');
    expect(state.chores.single.stars, 3);
    expect(find.text('Wash the car added for the kids.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
