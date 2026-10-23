import 'dart:convert';

import '../money/money.dart';

enum PreparationStatus { preview, applying, applied, failed }

class SavingsPreparation {
  const SavingsPreparation({required this.goalId, required this.amount});
  final String goalId;
  final Money amount;

  Map<String, Object?> toJson() => {
        'goal_id': goalId,
        'amount_minor': amount.minor,
        'currency': amount.currency.name,
      };

  factory SavingsPreparation.fromJson(Map<String, Object?> value) =>
      SavingsPreparation(
        goalId: value['goal_id'] as String,
        amount: Money(value['amount_minor'] as int,
            Currency.values.byName(value['currency'] as String)),
      );
}

class ShoppingPreparation {
  const ShoppingPreparation({
    required this.name,
    required this.quantity,
    required this.estimate,
  });
  final String name;
  final int quantity;
  final Money estimate;

  Map<String, Object?> toJson() => {
        'name': name,
        'quantity': quantity,
        'estimate_minor': estimate.minor,
        'currency': estimate.currency.name,
      };

  factory ShoppingPreparation.fromJson(Map<String, Object?> value) =>
      ShoppingPreparation(
        name: value['name'] as String,
        quantity: value['quantity'] as int,
        estimate: Money(value['estimate_minor'] as int,
            Currency.values.byName(value['currency'] as String)),
      );
}

/// Durable, editable preview. It contains plans only—never historical expense,
/// debt principal, debt repayment, or transaction records.
class PeriodPreparation {
  const PeriodPreparation({
    required this.operationId,
    required this.sourceCycle,
    required this.targetCycle,
    required this.createdAt,
    required this.allocations,
    required this.commitmentIds,
    required this.savings,
    required this.shoppingItems,
    this.expectedIncome,
    this.status = PreparationStatus.preview,
    this.error,
  });

  final String operationId;
  final DateTime sourceCycle;
  final DateTime targetCycle;
  final DateTime createdAt;
  final Map<String, Money> allocations;
  final Money? expectedIncome;
  final List<String> commitmentIds;
  final List<SavingsPreparation> savings;
  final List<ShoppingPreparation> shoppingItems;
  final PreparationStatus status;
  final String? error;

  PeriodPreparation copyWith({
    Map<String, Money>? allocations,
    Money? expectedIncome,
    bool clearExpectedIncome = false,
    List<String>? commitmentIds,
    List<SavingsPreparation>? savings,
    List<ShoppingPreparation>? shoppingItems,
    PreparationStatus? status,
    String? error,
  }) =>
      PeriodPreparation(
        operationId: operationId,
        sourceCycle: sourceCycle,
        targetCycle: targetCycle,
        createdAt: createdAt,
        allocations: allocations ?? this.allocations,
        expectedIncome:
            clearExpectedIncome ? null : expectedIncome ?? this.expectedIncome,
        commitmentIds: commitmentIds ?? this.commitmentIds,
        savings: savings ?? this.savings,
        shoppingItems: shoppingItems ?? this.shoppingItems,
        status: status ?? this.status,
        error: error,
      );

  String encode() => jsonEncode({
        'operation_id': operationId,
        'source_cycle': sourceCycle.toIso8601String(),
        'target_cycle': targetCycle.toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
        'allocations': {
          for (final entry in allocations.entries)
            entry.key: {
              'minor': entry.value.minor,
              'currency': entry.value.currency.name,
            }
        },
        'expected_income': expectedIncome == null
            ? null
            : {
                'minor': expectedIncome!.minor,
                'currency': expectedIncome!.currency.name,
              },
        'commitment_ids': commitmentIds,
        'savings': savings.map((value) => value.toJson()).toList(),
        'shopping_items': shoppingItems.map((value) => value.toJson()).toList(),
        'status': status.name,
        'error': error,
      });

  factory PeriodPreparation.decode(String source) {
    final value = jsonDecode(source) as Map<String, Object?>;
    final rawAllocations = value['allocations'] as Map<String, Object?>;
    final income = value['expected_income'];
    return PeriodPreparation(
      operationId: value['operation_id'] as String,
      sourceCycle: DateTime.parse(value['source_cycle'] as String),
      targetCycle: DateTime.parse(value['target_cycle'] as String),
      createdAt: DateTime.parse(value['created_at'] as String).toLocal(),
      allocations: rawAllocations.map((key, raw) {
        final money = raw as Map<String, Object?>;
        return MapEntry(
          key,
          Money(money['minor'] as int,
              Currency.values.byName(money['currency'] as String)),
        );
      }),
      expectedIncome: income == null
          ? null
          : Money(
              (income as Map<String, Object?>)['minor'] as int,
              Currency.values.byName(income['currency'] as String),
            ),
      commitmentIds:
          (value['commitment_ids'] as List).cast<String>().toList(),
      savings: (value['savings'] as List)
          .map((raw) => SavingsPreparation.fromJson(
              (raw as Map).cast<String, Object?>()))
          .toList(),
      shoppingItems: (value['shopping_items'] as List)
          .map((raw) => ShoppingPreparation.fromJson(
              (raw as Map).cast<String, Object?>()))
          .toList(),
      status: PreparationStatus.values.byName(value['status'] as String),
      error: value['error'] as String?,
    );
  }
}
