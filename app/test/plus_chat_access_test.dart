import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/family_chat/family_chat_screen.dart';

void main() {
  testWidgets('active legacy Plus entitlement unlocks enhanced chat controls',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.familyEntitlement = FamilyEntitlement(
      familyId: 'legacy-plus-family',
      status: EntitlementStatus.active,
      features: const {},
      verifiedAt: DateTime.now().subtract(const Duration(hours: 1)),
      isOfflineSnapshot: true,
    );
    expect(state.canWritePlusFeature('enhanced_family_chat'), isFalse);

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const FamilyChatScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Record voice note'), findsOneWidget);
    expect(find.byTooltip('Voice notes · Mhuri Plus'), findsNothing);
    expect(find.byTooltip('Add photo or reference'), findsOneWidget);
    expect(find.byTooltip('Emoji and stickers'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello family');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Send message'), findsOneWidget);
    expect(find.byTooltip('Record voice note'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.byTooltip('Record voice note'), findsOneWidget);

    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pumpAndSettle();
    expect(find.text('Emoji'), findsOneWidget);
    expect(find.text('Stickers'), findsOneWidget);
    expect(find.textContaining('choices'), findsOneWidget);

    state.dispose();
  });
}
