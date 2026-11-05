import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/family_chat/family_chat_screen.dart';
import 'package:mhuri_money/features/settings/plus_screen.dart';

Widget _chatHarness(AppState state) => AppScope(
      notifier: state,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: const FamilyChatScreen(),
      ),
    );

void _phoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Free family sees the Plus gate instead of chat or a composer',
      (tester) async {
    _phoneSize(tester);
    final state = AppState();

    await tester.pumpWidget(_chatHarness(state));
    await tester.pump();

    expect(find.text('Family chat is a Mhuri Plus feature'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byTooltip('Send message'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('family-chat-explore-plus')));
    await tester.pumpAndSettle();
    expect(find.byType(PlusScreen), findsOneWidget);

    state.dispose();
  });

  testWidgets('active legacy Plus entitlement unlocks enhanced chat controls',
      (tester) async {
    _phoneSize(tester);
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

    await tester.pumpWidget(_chatHarness(state));
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

  testWidgets('keyboard emoji are filtered but the in-app emoji tray works',
      (tester) async {
    _phoneSize(tester);
    final state = AppState()
      ..familyEntitlement = const FamilyEntitlement(
        familyId: 'plus-family',
        status: EntitlementStatus.active,
        features: kPlusV2Features,
      );

    await tester.pumpWidget(_chatHarness(state));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello 😀 family');
    await tester.pump();
    expect(find.text('Hello  family'), findsOneWidget);

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(state.familyChatMessages.single.text, 'Hello  family');

    await tester.tap(find.byTooltip('Emoji and stickers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('😀').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(state.familyChatMessages.length, 2);
    expect(
      state.familyChatMessages
          .singleWhere((message) => message.text == '😀')
          .text,
      '😀',
    );

    state.dispose();
  });

  testWidgets('message editing also filters keyboard emoji', (tester) async {
    _phoneSize(tester);
    final state = AppState()
      ..familyEntitlement = const FamilyEntitlement(
        familyId: 'plus-family',
        status: EntitlementStatus.active,
        features: kPlusV2Features,
      );
    state.familyChatMessages.add(FamilyChatMessage(
      id: 'message-to-edit',
      familyId: 'plus-family',
      senderId: state.user.id,
      text: 'Original',
      createdAt: DateTime(2026, 11, 5, 12),
    ));

    await tester.pumpWidget(_chatHarness(state));
    await tester.pump();
    await tester.longPress(find.text('Original'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit message'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Edited 😀');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(state.familyChatMessages.single.text, 'Edited');

    state.dispose();
  });
}
