import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/state/app_state.dart';
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
}
