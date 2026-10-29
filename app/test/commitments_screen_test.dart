import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/commitments/commitments_screen.dart';

void main() {
  testWidgets(
      'CommitmentsScreen gates on Plus and supports partial payment linking',
      (tester) async {
    final now = DateTime(2026, 10, 22);
    final state = AppState(clock: () => now);
    state.setRealUser(
      const Member(id: 'u1', name: 'Parent', emoji: 'person', role: Role.owner),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AppScope(notifier: state, child: const CommitmentsScreen()),
      ),
    );

    // Without Plus entitlement, shows Plus upgrade prompt
    expect(
      find.text('Smart Bills & Commitments is a Mhuri Plus feature'),
      findsOneWidget,
    );

    // Activate Plus entitlement
    state.familyEntitlement = const FamilyEntitlement(
      familyId: 'fam-1',
      status: EntitlementStatus.active,
      features: {'smart_commitments', 'cash_flow_forecast'},
    );
    state.addFinancialCommitment(
      FinancialCommitment(
        id: 'c-rent',
        name: 'Rent',
        amount: const Money(20000, Currency.usd),
        firstDueDate: DateTime(2026, 10, 25),
        recurrence: CommitmentRecurrence.monthly,
        createdById: 'u1',
      ),
    );
    state.addTx(
      id: 'tx-expense-1',
      type: TxType.expense,
      amount: const Money(15000, Currency.usd),
      memberId: 'u1',
      method: Method.bankTransfer,
      note: 'Rent part 1',
      when: now,
    );
    await tester.pumpAndSettle();

    final addButton = tester.widget<FloatingActionButton>(
      find.byKey(const Key('add_commitment_fab')),
    );
    expect(addButton.backgroundColor, isNotNull);
    expect(addButton.foregroundColor, isNotNull);
    expect(find.text('Rent'), findsOneWidget);
    expect(find.text('Link Payment'), findsOneWidget);

    // Open Link Payment sheet and link partial payment of $150.00
    await tester.tap(find.text('Link Payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_link_payment_button')));
    await tester.pumpAndSettle();

    final occ = state.commitmentOccurrences.first;
    expect(occ.status, CommitmentOccurrenceStatus.partiallyPaid);
    expect(state.commitmentOutstanding(occ).minor, 5000);
    expect(find.text('Partially paid'), findsOneWidget);

    state.dispose();
  });
}
