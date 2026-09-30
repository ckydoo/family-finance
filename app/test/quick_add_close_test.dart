import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/features/quickadd/quick_add_sheet.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('Quick Add closes without saving', (tester) async {
    final state = AppState();
    final originalCount = state.txs.length;

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('Open Quick Add'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Quick Add'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Quick add'), findsNothing);
    expect(state.txs, hasLength(originalCount));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Add explains type and searches a large budget list',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState();
    state.members.add(state.user);
    for (var i = 1; i <= 12; i++) {
      state.addEnvelope(
        name: 'Budget $i',
        limit: Money.fromMajor(100 + i, Currency.usd),
      );
    }

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showQuickAdd(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('What are you adding?'), findsOneWidget);
    expect(find.text('Amount spent'), findsOneWidget);
    expect(find.text('Add expense'), findsOneWidget);

    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();
    expect(find.text('Amount received'), findsOneWidget);
    expect(find.text('Add income'), findsOneWidget);
    expect(find.text('Which budget is this from?'), findsNothing);

    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Budget 1'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a budget'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search budgets'),
      'Budget 11',
    );
    await tester.pumpAndSettle();
    expect(find.text('Budget 11'), findsWidgets);
    expect(find.text('Budget 2'), findsNothing);

    await tester.tap(find.text('Budget 11').last);
    await tester.pumpAndSettle();
    expect(find.text('Budget 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
