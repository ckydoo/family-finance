import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/planning/commitments.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/sync/sync_mappers.dart';

void main() {
  const schedule = CommitmentSchedule();

  FinancialCommitment commitment({
    CommitmentRecurrence recurrence = CommitmentRecurrence.monthly,
    CommitmentStatus status = CommitmentStatus.active,
  }) =>
      FinancialCommitment(
        id: 'rent',
        name: 'Rent',
        amount: const Money(10000, Currency.usd),
        firstDueDate: DateTime(2026, 1, 31),
        recurrence: recurrence,
        createdById: 'me',
        status: status,
      );

  test('monthly schedule preserves anchor day after a short month', () {
    final values = schedule.generate(
      commitment(),
      through: DateTime(2026, 3, 31),
      idForKey: (key) => key,
    );

    expect(values.map((item) => item.occurrenceKey), [
      '2026-01-31',
      '2026-02-28',
      '2026-03-31',
    ]);
  });

  test('paused and ended commitments do not generate new occurrences', () {
    for (final status in [CommitmentStatus.paused, CommitmentStatus.ended]) {
      expect(
        schedule.generate(
          commitment(status: status),
          through: DateTime(2027),
          idForKey: (key) => key,
        ),
        isEmpty,
      );
    }
  });

  test('outstanding deduplicates payment ids and clamps at zero', () {
    final occurrence = schedule
        .generate(
          commitment(recurrence: CommitmentRecurrence.oneTime),
          through: DateTime(2026, 2),
          idForKey: (key) => key,
        )
        .single;
    final payment = CommitmentPayment(
      id: 'pay-1',
      occurrenceId: occurrence.id,
      transactionId: 'tx-1',
      amount: const Money(6000, Currency.usd),
      createdById: 'me',
      createdAt: DateTime(2026),
    );
    expect(schedule.outstanding(occurrence, [payment, payment]).minor, 4000);
  });

  test('planner adapter includes only the unpaid amount in the period', () {
    final source = commitment();
    final occurrence = schedule
        .generate(
          source,
          through: DateTime(2026, 1, 31),
          idForKey: (key) => key,
        )
        .single;
    final entries = schedule.toPlanningEntries(
      commitments: [source],
      occurrences: [occurrence],
      payments: [
        CommitmentPayment(
          id: 'partial',
          occurrenceId: occurrence.id,
          transactionId: 'expense',
          amount: const Money(2500, Currency.usd),
          createdById: 'me',
          createdAt: DateTime(2026),
        ),
      ],
      periodStart: DateTime(2026, 1),
      periodEnd: DateTime(2026, 2),
    );
    expect(entries.single.amount.minor, 7500);
    expect(entries.single.evidence.sourceId, occurrence.id);
  });

  test('commitment sync adapters round-trip all three entity types', () {
    const ctx = SyncCtx(
      spaceId: 'space',
      actorId: 'me',
      newId: _fixedId,
    );
    final source = commitment();
    final occurrence = schedule
        .generate(
          source,
          through: DateTime(2026, 1, 31),
          idForKey: (key) => 'occurrence',
        )
        .single;
    final payment = CommitmentPayment(
      id: 'payment',
      occurrenceId: occurrence.id,
      transactionId: 'expense',
      amount: const Money(2500, Currency.usd),
      createdById: 'me',
      createdAt: DateTime.utc(2026),
    );

    final decodedCommitment = kSyncAdapters['financial_commitment']!.decode(
      kSyncAdapters['financial_commitment']!.encode(source, ctx),
    ) as FinancialCommitment;
    final decodedOccurrence = kSyncAdapters['commitment_occurrence']!.decode(
      kSyncAdapters['commitment_occurrence']!.encode(occurrence, ctx),
    ) as CommitmentOccurrence;
    final decodedPayment = kSyncAdapters['commitment_payment']!.decode(
      kSyncAdapters['commitment_payment']!.encode(payment, ctx),
    ) as CommitmentPayment;
    expect(decodedCommitment.recurrence, CommitmentRecurrence.monthly);
    expect(decodedOccurrence.occurrenceKey, occurrence.occurrenceKey);
    expect(decodedPayment.transactionId, 'expense');
  });

  test('state generation is idempotent and payment links an existing expense',
      () {
    final state = AppState(clock: () => DateTime(2026, 1, 15));
    _unlockCommitments(state);
    expect(state.addFinancialCommitment(commitment()), isTrue);
    expect(
      state.generateCommitmentOccurrences(through: DateTime(2026, 3, 31)),
      2,
    );
    expect(
      state.generateCommitmentOccurrences(through: DateTime(2026, 3, 31)),
      0,
    );
    final occurrence = state.commitmentOccurrences.first;
    expect(
      state.addTx(
        id: 'expense-1',
        type: TxType.expense,
        amount: const Money(10000, Currency.usd),
        memberId: 'me',
        method: Method.cash,
        note: 'Rent paid',
      ),
      isTrue,
    );

    expect(
      state.associateCommitmentPayment(
        id: 'payment-1',
        occurrenceId: occurrence.id,
        transactionId: 'expense-1',
        amount: const Money(4000, Currency.usd),
      ),
      isTrue,
    );
    expect(state.commitmentOutstanding(occurrence).minor, 6000);
    expect(
      state.commitmentOccurrences.first.status,
      CommitmentOccurrenceStatus.partiallyPaid,
    );
    expect(
      state.associateCommitmentPayment(
        id: 'payment-1',
        occurrenceId: occurrence.id,
        transactionId: 'expense-1',
        amount: const Money(4000, Currency.usd),
      ),
      isFalse,
    );
    expect(state.txs.where((item) => item.id == 'expense-1'), hasLength(1));
  });

  test('one expense cannot be over-allocated across commitments', () {
    final state = AppState();
    _unlockCommitments(state);
    final first = commitment(recurrence: CommitmentRecurrence.oneTime);
    final second = FinancialCommitment(
      id: 'power',
      name: 'Power',
      amount: const Money(10000, Currency.usd),
      firstDueDate: DateTime(2026, 1, 31),
      recurrence: CommitmentRecurrence.oneTime,
      createdById: 'me',
    );
    expect(state.addFinancialCommitment(first), isTrue);
    expect(state.addFinancialCommitment(second), isTrue);
    expect(
      state.addTx(
        id: 'expense-2',
        type: TxType.expense,
        amount: const Money(10000, Currency.usd),
        memberId: 'me',
        method: Method.cash,
        note: 'Combined payment',
      ),
      isTrue,
    );
    expect(
      state.associateCommitmentPayment(
        id: 'allocation-1',
        occurrenceId: state.commitmentOccurrences[0].id,
        transactionId: 'expense-2',
        amount: const Money(7000, Currency.usd),
      ),
      isTrue,
    );
    expect(
      state.associateCommitmentPayment(
        id: 'allocation-2',
        occurrenceId: state.commitmentOccurrences[1].id,
        transactionId: 'expense-2',
        amount: const Money(4000, Currency.usd),
      ),
      isFalse,
    );
  });
}

void _unlockCommitments(AppState state) {
  state.familyEntitlement = const FamilyEntitlement(
    familyId: 'family',
    status: EntitlementStatus.active,
    features: {'smart_commitments'},
  );
}

String _fixedId() => 'fixed';
