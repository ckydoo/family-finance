import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/activity/activity_screen.dart';
import 'package:mhuri_money/features/reports/reports_screen.dart';
import 'package:mhuri_money/features/lists/lists_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'Reports displays Shopping & Lists Tracking card and tracks items',
      (tester) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    // Add shopping list items
    state.addItem('Whole Milk', 2, const Money(250, Currency.usd));
    state.addItem('Brown Bread', 1, const Money(150, Currency.usd));
    // Mark one as done
    state.items.first.state = ItemState.done;

    // Add a grocery expense transaction in the current cycle
    state.addTx(
      type: TxType.expense,
      amount: const Money(4200, Currency.usd),
      memberId: 'me',
      method: Method.bankCard,
      note: 'FreshMart groceries run',
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Shopping & Lists Tracking card is rendered
    await tester.scrollUntilVisible(
      find.text('Shopping & Lists Tracking'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Shopping & Lists Tracking'), findsOneWidget);
    expect(find.text('1/2 bought'), findsOneWidget);
    expect(find.text('Period grocery spend'), findsOneWidget);
    expect(find.text('Est. items to buy'), findsOneWidget);

    // Verify items are visible in tracked items preview
    expect(find.textContaining('Whole Milk'), findsOneWidget);
    expect(find.textContaining('Brown Bread'), findsOneWidget);

    // Scroll to the button and verify navigation
    final btn = find.text('View full shopping list');
    await tester.scrollUntilVisible(btn, 200);
    await tester.pumpAndSettle();

    expect(btn, findsOneWidget);
    await tester.tap(btn);
    await tester.pumpAndSettle();

    // Verify ListsScreen opened
    expect(find.byType(ListsScreen), findsOneWidget);
  });

  testWidgets(
      'Who spent what compares member spending accurately and drills into filtered ActivityScreen',
      (tester) async {
    tester.view.physicalSize = const Size(402, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    const me = Member(
      id: 'm_me',
      name: 'Tendai',
      emoji: 'person',
      role: Role.owner,
    );
    const sister = Member(
      id: 'm_sister',
      name: 'Chipo',
      emoji: 'person',
      role: Role.admin,
    );
    state.setRealUser(me);
    state.members
      ..clear()
      ..addAll(const [me, sister]);

    // Tendai spends $40.00, Sister Chipo spends $60.00 -> $100.00 total (40% vs 60%).
    state.addTx(
      id: 'tx_me_1',
      type: TxType.expense,
      amount: const Money(4000, Currency.usd),
      memberId: me.id,
      method: Method.cash,
      note: 'Fuel top-up',
    );
    state.addTx(
      id: 'tx_sis_1',
      type: TxType.expense,
      amount: const Money(6000, Currency.usd),
      memberId: sister.id,
      method: Method.mobileMoney,
      note: 'Salon & groceries',
    );
    // Simulate server-synced audit entry logged by Tendai on behalf of Chipo.
    state.familyActivities.add(
      FamilyActivity(
        id: 'srv_audit_sis_1',
        actorId: me.id,
        action: 'tx.create',
        entity: 'transaction',
        entityId: 'tx_sis_1',
        at: state.now,
        detail: {
          'amount_minor': 6000,
          'currency': 'USD',
          'member_id': sister.id,
        },
      ),
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: const MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Who spent what'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Who spent what'), findsOneWidget);
    expect(find.text('2 active'), findsOneWidget);
    expect(find.text('Chipo'), findsOneWidget);
    expect(find.text('Tendai'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    // Tap Chipo's row to drill into her exact itemized expenses.
    final sisterRow = find.byKey(const ValueKey('report_member_row_m_sister'));
    await tester.ensureVisible(sisterRow);
    await tester.pumpAndSettle();
    await tester.tap(sisterRow);
    await tester.pumpAndSettle();

    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('Salon & groceries'), findsOneWidget);
    expect(find.text('Fuel top-up'), findsNothing);
  });
}
