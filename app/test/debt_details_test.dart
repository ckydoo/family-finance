import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('debt details identify who recorded every repayment',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = AppState();
    const recorder = Member(
      id: 'repayment-recorder',
      name: 'Tariro',
      emoji: 'person',
      role: Role.adult,
    );
    state.members.add(recorder);
    state.familyDebts.add(FamilyDebt(
      id: 'debt-details',
      name: 'School loan',
      direction: DebtDirection.iOwe,
      principal: const Money(10000, Currency.usd),
      createdById: state.user.id,
      dueDate: DateTime(2026, 12, 1),
    ));
    state.debtRepayments.add(DebtRepayment(
      id: 'repayment-1',
      debtId: 'debt-details',
      memberId: recorder.id,
      amount: const Money(2500, Currency.usd),
      paidAt: DateTime(2026, 10, 11, 14, 30),
    ));

    await tester.pumpWidget(AppScope(
      notifier: state,
      child: const MaterialApp(
        localizationsDelegates: mhuriLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SavingsScreen(
          standalone: true,
          initialSection: SavingsSection.debts,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('School loan'));
    await tester.pumpAndSettle();

    expect(find.text('Repayment history'), findsOneWidget);
    expect(find.textContaining('Recorded by Tariro'), findsOneWidget);
    expect(find.textContaining('25.00'), findsWidgets);
    expect(find.textContaining('Added by'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Edit'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
