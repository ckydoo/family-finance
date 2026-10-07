import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
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
}
