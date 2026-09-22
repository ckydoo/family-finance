import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  test('family pool follows income and expense activity', () {
    final state = AppState();
    state.members.add(state.user);

    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(500, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      note: 'Income',
    );
    state.addTx(
      type: TxType.expense,
      amount: Money.fromMajor(250, Currency.usd),
      memberId: state.user.id,
      method: Method.bankCard,
      note: 'Expense',
    );

    expect(state.poolCombined(Currency.usd).minor, 25000);
    expect(state.poolCombined(Currency.zwg).minor, 25000 * state.rate);
  });

  testWidgets('home envelope card opens its details', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    state.members.add(state.user);
    state.addEnvelope(
      name: 'Groceries',
      limit: Money.fromMajor(300, Currency.usd),
    );

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Groceries').first);
    await tester.pumpAndSettle();

    expect(find.text('Move money'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
