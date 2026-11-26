import '../money/money.dart';
import '../time/household_timezone.dart';
import 'financial_planner.dart';

enum CommitmentStatus { active, paused, ended, archived }

enum CommitmentRecurrence {
  oneTime,
  weekly,
  fortnightly,
  monthly,
  quarterly,
  yearly
}

enum CommitmentOccurrenceStatus {
  upcoming,
  partiallyPaid,
  paid,
  skipped,
  canceled
}

class FinancialCommitment {
  const FinancialCommitment({
    required this.id,
    required this.name,
    required this.amount,
    required this.firstDueDate,
    required this.recurrence,
    required this.createdById,
    this.envelopeId,
    this.status = CommitmentStatus.active,
    this.endDate,
    this.reminderDaysBefore = const [3],
  });

  final String id;
  final String name;
  final Money amount;
  final DateTime firstDueDate;
  final CommitmentRecurrence recurrence;
  final String createdById;
  final String? envelopeId;
  final CommitmentStatus status;
  final DateTime? endDate;
  final List<int> reminderDaysBefore;

  bool get isRecurring => recurrence != CommitmentRecurrence.oneTime;

  FinancialCommitment copy() => FinancialCommitment(
        id: id,
        name: name,
        amount: amount,
        firstDueDate: firstDueDate,
        recurrence: recurrence,
        createdById: createdById,
        envelopeId: envelopeId,
        status: status,
        endDate: endDate,
        reminderDaysBefore: List<int>.of(reminderDaysBefore),
      );
}

class CommitmentOccurrence {
  const CommitmentOccurrence({
    required this.id,
    required this.commitmentId,
    required this.occurrenceKey,
    required this.dueDate,
    required this.amount,
    this.status = CommitmentOccurrenceStatus.upcoming,
  });

  final String id;
  final String commitmentId;
  final String occurrenceKey;
  final DateTime dueDate;
  final Money amount;
  final CommitmentOccurrenceStatus status;

  CommitmentOccurrence copy() => CommitmentOccurrence(
        id: id,
        commitmentId: commitmentId,
        occurrenceKey: occurrenceKey,
        dueDate: dueDate,
        amount: amount,
        status: status,
      );
}

class CommitmentPayment {
  const CommitmentPayment({
    required this.id,
    required this.occurrenceId,
    required this.transactionId,
    required this.amount,
    required this.createdById,
    required this.createdAt,
  });

  final String id;
  final String occurrenceId;
  final String transactionId;
  final Money amount;
  final String createdById;
  final DateTime createdAt;

  CommitmentPayment copy() => CommitmentPayment(
        id: id,
        occurrenceId: occurrenceId,
        transactionId: transactionId,
        amount: amount,
        createdById: createdById,
        createdAt: createdAt,
      );
}

class CommitmentSchedule {
  const CommitmentSchedule();

  List<CommitmentOccurrence> generate(
    FinancialCommitment commitment, {
    required DateTime through,
    required String Function(String occurrenceKey) idForKey,
    String? timezone,
  }) {
    final anchorStart = HouseholdTimezone.dateAtMidnight(
      commitment.firstDueDate.year,
      commitment.firstDueDate.month,
      commitment.firstDueDate.day,
      timezone,
    );
    if (commitment.status == CommitmentStatus.paused ||
        commitment.status == CommitmentStatus.archived ||
        commitment.status == CommitmentStatus.ended ||
        through.isBefore(anchorStart)) {
      return const [];
    }
    final result = <CommitmentOccurrence>[];
    var occurrenceIndex = 0;
    var due = anchorStart;
    while (!due.isAfter(through) &&
        (commitment.endDate == null || !due.isAfter(commitment.endDate!))) {
      final key = _dateKey(due);
      result.add(CommitmentOccurrence(
        id: idForKey(key),
        commitmentId: commitment.id,
        occurrenceKey: key,
        dueDate: due,
        amount: commitment.amount,
      ));
      if (!commitment.isRecurring) break;
      occurrenceIndex++;
      due = _atIndex(
        anchorStart,
        commitment.recurrence,
        occurrenceIndex,
        timezone,
      );
    }
    return List.unmodifiable(result);
  }

  Money outstanding(
    CommitmentOccurrence occurrence,
    Iterable<CommitmentPayment> payments,
  ) {
    var paid = 0;
    final paymentIds = <String>{};
    for (final payment
        in payments.where((payment) => payment.occurrenceId == occurrence.id)) {
      if (!paymentIds.add(payment.id)) continue;
      if (payment.amount.currency != occurrence.amount.currency) {
        throw StateError(
            'Commitment payments must use the occurrence currency.');
      }
      paid += payment.amount.minor;
    }
    return Money(
      (occurrence.amount.minor - paid).clamp(0, occurrence.amount.minor),
      occurrence.amount.currency,
    );
  }

  List<PlanningEntry> toPlanningEntries({
    required Iterable<FinancialCommitment> commitments,
    required Iterable<CommitmentOccurrence> occurrences,
    required Iterable<CommitmentPayment> payments,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final commitmentsById = {for (final value in commitments) value.id: value};
    final result = <PlanningEntry>[];
    for (final occurrence in occurrences) {
      if (occurrence.dueDate.isBefore(periodStart) ||
          !occurrence.dueDate.isBefore(periodEnd) ||
          occurrence.status == CommitmentOccurrenceStatus.paid ||
          occurrence.status == CommitmentOccurrenceStatus.skipped ||
          occurrence.status == CommitmentOccurrenceStatus.canceled) {
        continue;
      }
      final commitment = commitmentsById[occurrence.commitmentId];
      if (commitment == null ||
          commitment.status == CommitmentStatus.archived) {
        continue;
      }
      final remaining = outstanding(occurrence, payments);
      if (remaining.isZero) continue;
      result.add(PlanningEntry(
        id: 'commitment:${occurrence.id}',
        date: occurrence.dueDate,
        amount: remaining,
        kind: PlanningValueKind.commitment,
        direction: PlanningDirection.outflow,
        evidence: PlanningEvidence(
          sourceType: 'commitment_occurrence',
          sourceId: occurrence.id,
          label: commitment.name,
        ),
      ));
    }
    result.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return List.unmodifiable(result);
  }

  DateTime _atIndex(
    DateTime value,
    CommitmentRecurrence recurrence,
    int index,
    String? timezone,
  ) =>
      switch (recurrence) {
        CommitmentRecurrence.oneTime => value,
        CommitmentRecurrence.weekly => HouseholdTimezone.dateAtMidnight(
            value.year,
            value.month,
            value.day + 7 * index,
            timezone,
          ),
        CommitmentRecurrence.fortnightly => HouseholdTimezone.dateAtMidnight(
            value.year,
            value.month,
            value.day + 14 * index,
            timezone,
          ),
        CommitmentRecurrence.monthly => _addMonths(value, index, timezone),
        CommitmentRecurrence.quarterly =>
          _addMonths(value, 3 * index, timezone),
        CommitmentRecurrence.yearly => _addMonths(value, 12 * index, timezone),
      };

  DateTime _addMonths(DateTime value, int count, String? timezone) {
    final total = value.year * 12 + value.month - 1 + count;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final day = value.day.clamp(1, DateTime.utc(year, month + 1, 0).day);
    if (timezone == null || timezone.trim().isEmpty) {
      return DateTime(year, month, day, value.hour, value.minute);
    }
    return HouseholdTimezone.dateAtMidnight(year, month, day, timezone);
  }

  String _dateKey(DateTime value) => '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
