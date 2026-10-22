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
    final balanceBefore = state.availableToSpend(Currency.usd).minor;
    expect(
        state.recordDebtRepayment(debt, const Money(3000, Currency.usd),
            id: 'first'),
        isTrue);
    expect(state.remainingOnDebt(debt).minor, 7000);
    expect(state.availableToSpend(Currency.usd).minor, balanceBefore - 3000);
    expect(debt.status, 'active');

    expect(
        state.recordDebtRepayment(debt, const Money(7000, Currency.usd),
            id: 'final'),
        isTrue);
    expect(state.remainingOnDebt(debt).minor, 0);
    expect(state.availableToSpend(Currency.usd).minor, balanceBefore - 10000);
    expect(debt.status, 'settled');
  });

  test('repayment received for money owed to me increases balance', () {
    final state = AppState();
    state.members.add(state.user);
    state.createDebt(
      name: 'School advance',
      direction: DebtDirection.owedToMe,
      principal: const Money(5000, Currency.usd),
    );

    final before = state.availableToSpend(Currency.usd).minor;
    expect(
      state.recordDebtRepayment(
        state.familyDebts.single,
        const Money(2000, Currency.usd),
        id: 'received',
      ),
      isTrue,
    );
    expect(state.availableToSpend(Currency.usd).minor, before + 2000);
    expect(state.txs.first.type, TxType.income);
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

  test('debt can be edited without losing repayments and then archived', () {
    final state = AppState();
    state.members.add(state.user);
    state.createDebt(
      name: 'Old name',
      direction: DebtDirection.iOwe,
      principal: const Money(10000, Currency.usd),
    );
    final debt = state.familyDebts.single;
    expect(
      state.recordDebtRepayment(debt, const Money(2500, Currency.usd),
          id: 'payment-kept'),
      isTrue,
    );

    expect(
      state.updateDebt(
        debt,
        name: 'School advance',
        direction: DebtDirection.familyLoan,
        principal: const Money(12000, Currency.usd),
        dueDate: DateTime(2027, 1, 15),
      ),
      isTrue,
    );
    expect(debt.name, 'School advance');
    expect(debt.direction, DebtDirection.familyLoan);
    expect(state.remainingOnDebt(debt).minor, 9500);
    expect(state.debtRepayments.single.id, 'payment-kept');

    expect(state.archiveDebt(debt), isTrue);
    expect(state.familyDebts, isEmpty);
    expect(debt.status, 'archived');
    expect(state.debtRepayments.single.id, 'payment-kept');
  });

  test('debt principal cannot be reduced below repayments', () {
    final state = AppState();
    state.members.add(state.user);
    state.createDebt(
      name: 'Advance',
      direction: DebtDirection.iOwe,
      principal: const Money(10000, Currency.usd),
    );
    final debt = state.familyDebts.single;
    state.recordDebtRepayment(debt, const Money(6000, Currency.usd), id: 'p1');

    expect(
      state.updateDebt(
        debt,
        name: 'Advance',
        direction: DebtDirection.iOwe,
        principal: const Money(5000, Currency.usd),
      ),
      isFalse,
    );
    expect(debt.principal.minor, 10000);
  });
}
