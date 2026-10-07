import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';

void main() {
  test('partial repayments reduce a debt and final payment settles it', () {
    final state = AppState();
    state.members.add(state.user);
    state.createDebt(
      name: 'Family loan',
      direction: DebtDirection.iOwe,
      principal: const Money(10000, Currency.usd),
    );
    final debt = state.familyDebts.single;
    expect(
        state.recordDebtRepayment(debt, const Money(3000, Currency.usd),
            id: 'first'),
        isTrue);
    expect(state.remainingOnDebt(debt).minor, 7000);
    expect(debt.status, 'active');

    expect(
        state.recordDebtRepayment(debt, const Money(7000, Currency.usd),
            id: 'final'),
        isTrue);
    expect(state.remainingOnDebt(debt).minor, 0);
    expect(debt.status, 'settled');
  });

  test('repayment cannot exceed balance or be duplicated', () {
    final state = AppState();
    state.members.add(state.user);
    final debt = FamilyDebt(
      id: 'debt',
      name: 'Advance',
      direction: DebtDirection.owedToMe,
      principal: const Money(5000, Currency.usd),
      createdById: state.user.id,
    );
    state.familyDebts.add(debt);
    expect(
        state.recordDebtRepayment(debt, const Money(6000, Currency.usd),
            id: 'too-much'),
        isFalse);
    expect(
        state.recordDebtRepayment(debt, const Money(1000, Currency.usd),
            id: 'same'),
        isTrue);
    expect(
        state.recordDebtRepayment(debt, const Money(1000, Currency.usd),
            id: 'same'),
        isFalse);
  });
}
