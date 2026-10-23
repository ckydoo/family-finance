import '../money/money.dart';

/// The provenance of a forecast value. The planner deliberately keeps these
/// categories separate so a planned amount can never masquerade as cash.
enum PlanningValueKind {
  recordedBalance,
  expectedIncome,
  commitment,
  plannedEssential,
  savingsAllocation,
  estimate,
  scenarioAdjustment,
}

enum PlanningDirection { inflow, outflow }

class PlanningEvidence {
  const PlanningEvidence({
    required this.sourceType,
    required this.sourceId,
    required this.label,
    this.isEstimate = false,
  });

  final String sourceType;
  final String sourceId;
  final String label;
  final bool isEstimate;
}

class PlanningEntry {
  const PlanningEntry({
    required this.id,
    required this.date,
    required this.amount,
    required this.kind,
    required this.direction,
    required this.evidence,
  });

  final String id;
  final DateTime date;
  final Money amount;
  final PlanningValueKind kind;
  final PlanningDirection direction;
  final PlanningEvidence evidence;

  int get signedMinor =>
      direction == PlanningDirection.inflow ? amount.minor : -amount.minor;
}

/// A non-persistent scenario overlay. It references a real planning entry but
/// never mutates that entry or any repository record.
class ScenarioChange {
  const ScenarioChange({
    required this.id,
    this.targetEntryId,
    this.replacementAmount,
    this.dateShift = Duration.zero,
    this.removeTarget = false,
    this.additionalEntry,
  });

  final String id;
  final String? targetEntryId;
  final Money? replacementAmount;
  final Duration dateShift;
  final bool removeTarget;
  final PlanningEntry? additionalEntry;
}

class ForecastPoint {
  const ForecastPoint({required this.entry, required this.balance});

  final PlanningEntry entry;
  final Money balance;
}

class ForecastShortfall {
  const ForecastShortfall({
    required this.date,
    required this.amountBelowZero,
    required this.triggerEntryId,
  });

  final DateTime date;
  final Money amountBelowZero;
  final String triggerEntryId;
}

class FinancialForecast {
  const FinancialForecast({
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.openingBalanceConfirmed,
    required this.points,
    required this.closingBalance,
    required this.lowestBalance,
    required this.shortfalls,
    required this.includedEvidence,
  });

  final Currency currency;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Money openingBalance;
  final bool openingBalanceConfirmed;
  final List<ForecastPoint> points;
  final Money closingBalance;
  final Money lowestBalance;
  final List<ForecastShortfall> shortfalls;
  final List<PlanningEvidence> includedEvidence;

  bool get hasShortfall => shortfalls.isNotEmpty;
}

class FinancialPlanningException implements Exception {
  const FinancialPlanningException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'FinancialPlanningException($code, $message)';
}

/// Pure deterministic forecast engine. It performs no I/O and mutates none of
/// its inputs, making the same rules reusable by UI, tests, RPC previews and a
/// future authorized Assistant operation.
class FinancialPlanner {
  const FinancialPlanner();

  FinancialForecast forecast({
    required DateTime periodStart,
    required DateTime periodEnd,
    required Money openingBalance,
    required bool openingBalanceConfirmed,
    required Iterable<PlanningEntry> entries,
    Iterable<ScenarioChange> scenario = const [],
  }) {
    if (!periodEnd.isAfter(periodStart)) {
      throw const FinancialPlanningException(
        'INVALID_PERIOD',
        'The planning period must end after it starts.',
      );
    }
    if (!openingBalanceConfirmed) {
      throw const FinancialPlanningException(
        'OPENING_BALANCE_UNCONFIRMED',
        'Confirm the available opening balance before forecasting.',
      );
    }

    final source = List<PlanningEntry>.unmodifiable(entries);
    final byId = <String, PlanningEntry>{};
    for (final entry in source) {
      if (entry.id.isEmpty || byId.containsKey(entry.id)) {
        throw const FinancialPlanningException(
          'DUPLICATE_ENTRY',
          'Every planning input must have a stable unique ID.',
        );
      }
      if (entry.amount.minor < 0) {
        throw const FinancialPlanningException(
          'NEGATIVE_AMOUNT',
          'Planning amounts must be non-negative; direction carries the sign.',
        );
      }
      if (entry.amount.currency != openingBalance.currency) {
        throw const FinancialPlanningException(
          'CURRENCY_MISMATCH',
          'A forecast cannot silently combine currencies.',
        );
      }
      byId[entry.id] = entry;
    }

    final effective = Map<String, PlanningEntry>.from(byId);
    final scenarioIds = <String>{};
    for (final change in scenario) {
      if (change.id.isEmpty || !scenarioIds.add(change.id)) {
        throw const FinancialPlanningException(
          'DUPLICATE_SCENARIO_CHANGE',
          'Every scenario change must have a stable unique ID.',
        );
      }
      final additional = change.additionalEntry;
      if (additional != null) {
        if (additional.kind != PlanningValueKind.scenarioAdjustment) {
          throw const FinancialPlanningException(
            'INVALID_SCENARIO_ENTRY',
            'Additional scenario entries must be marked as adjustments.',
          );
        }
        if (additional.amount.currency != openingBalance.currency) {
          throw const FinancialPlanningException(
            'CURRENCY_MISMATCH',
            'A scenario cannot silently combine currencies.',
          );
        }
        if (effective.containsKey(additional.id)) {
          throw const FinancialPlanningException(
            'DUPLICATE_ENTRY',
            'A scenario adjustment cannot reuse an existing entry ID.',
          );
        }
        effective[additional.id] = additional;
      }
      final targetId = change.targetEntryId;
      if (targetId == null) continue;
      final target = effective[targetId];
      if (target == null) {
        throw const FinancialPlanningException(
          'SCENARIO_TARGET_NOT_FOUND',
          'A scenario change referenced a missing planning input.',
        );
      }
      if (change.removeTarget) {
        effective.remove(targetId);
        continue;
      }
      final amount = change.replacementAmount ?? target.amount;
      if (amount.currency != openingBalance.currency || amount.minor < 0) {
        throw const FinancialPlanningException(
          'CURRENCY_MISMATCH',
          'Scenario replacement amounts must use the forecast currency.',
        );
      }
      effective[targetId] = PlanningEntry(
        id: target.id,
        date: target.date.add(change.dateShift),
        amount: amount,
        kind: target.kind,
        direction: target.direction,
        evidence: target.evidence,
      );
    }

    final included = effective.values
        .where((entry) =>
            !entry.date.isBefore(periodStart) && entry.date.isBefore(periodEnd))
        .toList(growable: false)
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.id.compareTo(b.id);
      });

    var running = openingBalance.minor;
    var lowest = running;
    final points = <ForecastPoint>[];
    final shortfalls = <ForecastShortfall>[];
    for (final entry in included) {
      final before = running;
      running += entry.signedMinor;
      if (running < lowest) lowest = running;
      points.add(ForecastPoint(
        entry: entry,
        balance: Money(running, openingBalance.currency),
      ));
      if (before >= 0 && running < 0) {
        shortfalls.add(ForecastShortfall(
          date: entry.date,
          amountBelowZero: Money(-running, openingBalance.currency),
          triggerEntryId: entry.id,
        ));
      }
    }

    return FinancialForecast(
      currency: openingBalance.currency,
      periodStart: periodStart,
      periodEnd: periodEnd,
      openingBalance: openingBalance,
      openingBalanceConfirmed: true,
      points: List.unmodifiable(points),
      closingBalance: Money(running, openingBalance.currency),
      lowestBalance: Money(lowest, openingBalance.currency),
      shortfalls: List.unmodifiable(shortfalls),
      includedEvidence:
          List.unmodifiable(included.map((entry) => entry.evidence)),
    );
  }

  /// Convenience for families that actively use several currencies. Each
  /// currency receives an independent opening balance and independent result.
  Map<Currency, FinancialForecast> forecastByCurrency({
    required DateTime periodStart,
    required DateTime periodEnd,
    required Map<Currency, Money> openingBalances,
    required Set<Currency> confirmedCurrencies,
    required Iterable<PlanningEntry> entries,
  }) {
    final all = List<PlanningEntry>.unmodifiable(entries);
    return Map.unmodifiable({
      for (final pair in openingBalances.entries)
        pair.key: forecast(
          periodStart: periodStart,
          periodEnd: periodEnd,
          openingBalance: pair.value,
          openingBalanceConfirmed: confirmedCurrencies.contains(pair.key),
          entries: all.where((entry) => entry.amount.currency == pair.key),
        ),
    });
  }
}
