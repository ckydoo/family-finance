import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/core/db/persistence.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/planning/period_preparation.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('commitment, occurrence, and payment survive restart', () async {
    final raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (database, version) => AppDatabase.createSchema(database),
      ),
    );
    final database = AppDatabase.wrap(raw);
    final first = AppState(db: database);
    await first.ready();
    first.familyEntitlement = const FamilyEntitlement(
      familyId: 'family',
      status: EntitlementStatus.active,
      features: {'smart_commitments'},
    );
    final commitment = FinancialCommitment(
      id: 'rent',
      name: 'Rent',
      amount: const Money(10000, Currency.usd),
      firstDueDate: DateTime(2026, 11),
      recurrence: CommitmentRecurrence.monthly,
      createdById: 'me',
    );
    expect(first.addFinancialCommitment(commitment), isTrue);
    expect(
      first.addTx(
        id: 'rent-expense',
        type: TxType.expense,
        amount: const Money(10000, Currency.usd),
        memberId: 'me',
        method: Method.bankTransfer,
        note: 'Rent',
      ),
      isTrue,
    );
    expect(
      first.associateCommitmentPayment(
        id: 'rent-payment',
        occurrenceId: first.commitmentOccurrences.single.id,
        transactionId: 'rent-expense',
        amount: const Money(2500, Currency.usd),
      ),
      isTrue,
    );
    final preparation = PeriodPreparation(
      operationId: 'prepare-next',
      sourceCycle: DateTime(2026, 10),
      targetCycle: DateTime(2026, 11),
      createdAt: DateTime(2026, 10, 22),
      allocations: const {'rent': Money(10000, Currency.usd)},
      commitmentIds: const ['rent'],
      savings: const [],
      shoppingItems: const [],
    );
    first.periodPreparations.add(preparation);
    await Persistence(database).savePeriodPreparation(preparation);
    await first.flushWrites();

    final second = AppState(db: database);
    await second.ready();
    expect(second.financialCommitments.single.id, 'rent');
    expect(second.commitmentOccurrences.single.status,
        CommitmentOccurrenceStatus.partiallyPaid);
    expect(second.commitmentPayments.single.transactionId, 'rent-expense');
    expect(second.periodPreparations.single.operationId, 'prepare-next');
    expect(
        second.commitmentOutstanding(second.commitmentOccurrences.single).minor,
        7500);
    await second.flushWrites();
    await raw.close();
  });
}
