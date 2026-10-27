import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/features/activity/activity_screen.dart';
import 'package:mhuri_money/features/settings/private_accounts_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
      'closing the private account dialog does not use a disposed controller',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);
    await tester.pumpWidget(AppScope(
      notifier: state,
      child: const MaterialApp(home: PrivateAccountsScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create').first);
    await tester.pumpAndSettle();
    expect(find.text('Create private account'), findsAtLeastNWidgets(2));

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('private account opens its history and transaction details',
      (tester) async {
    final state = AppState();
    state.members.add(state.user);
    final account = state.createPrivateAccount('Side hustle');
    expect(account, isNotNull);
    expect(state.createPrivateAccount('Second account'), isNull);
    state.addTx(
      id: 'private-history-entry',
      accountId: account!.id,
      type: TxType.income,
      amount: const Money(2500, Currency.usd),
      memberId: state.realUser.id,
      method: Method.cash,
      note: 'Weekend sales',
    );

    await tester.pumpWidget(AppScope(
      notifier: state,
      child: const MaterialApp(
        localizationsDelegates: mhuriLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrivateAccountsScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Side hustle'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityScreen), findsOneWidget);
    expect(find.text('Weekend sales'), findsOneWidget);

    await tester.tap(find.text('Weekend sales'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction details'), findsOneWidget);
  });
}
