import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/app.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/kids/kids_mode.dart';
import 'package:mhuri_money/features/shell/adult_shell.dart';
import 'package:mhuri_money/features/teen/teen_zone.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  Widget harness(AppState state) => AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: RoleGate(),
        ),
      );

  AppState stateFor(Role role) {
    final state = AppState();
    final actor = Member(
      id: 'actor-${role.name}',
      name: role.name,
      emoji: 'person',
      role: role,
    );
    state.members
      ..clear()
      ..add(actor);
    state.setRealUser(actor);
    return state;
  }

  for (final role in [Role.owner, Role.adult, Role.viewer]) {
    testWidgets('${role.name} routes to the adult information shell',
        (tester) async {
      final state = stateFor(role);
      await tester.pumpWidget(harness(state));
      await tester.pump();

      expect(find.byType(AdultShell), findsOneWidget);
      expect(find.byType(TeenZone), findsNothing);
      expect(find.byType(KidsMode), findsNothing);
      expect(
        find.byType(FloatingActionButton),
        role == Role.viewer ? findsNothing : findsOneWidget,
      );
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  }

  testWidgets('teen routes only to Teen Zone', (tester) async {
    await tester.pumpWidget(harness(stateFor(Role.teen)));
    await tester.pump();

    expect(find.byType(TeenZone), findsOneWidget);
    expect(find.byType(AdultShell), findsNothing);
    expect(find.byType(KidsMode), findsNothing);
  });

  testWidgets('child routes only to Kids Mode', (tester) async {
    await tester.pumpWidget(harness(stateFor(Role.kid)));
    await tester.pump();

    expect(find.byType(KidsMode), findsOneWidget);
    expect(find.byType(AdultShell), findsNothing);
    expect(find.byType(TeenZone), findsNothing);
  });

  testWidgets('owner can exit a child preview without the child PIN',
      (tester) async {
    final state = stateFor(Role.owner);
    final owner = state.user;
    const child = Member(
      id: 'child-preview',
      name: 'Tino',
      emoji: 'child',
      role: Role.kid,
    );
    state.members.add(child);
    state.switchUser(child);

    await tester.pumpWidget(harness(state));
    await tester.pump();
    expect(find.byType(KidsMode), findsOneWidget);
    expect(find.text('Previewing as Tino'), findsOneWidget);

    await tester.tap(find.text('Exit'));
    await tester.pump();

    expect(state.user.id, owner.id);
    expect(find.byType(AdultShell), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
