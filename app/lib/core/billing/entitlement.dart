import 'package:flutter/foundation.dart';

/// Server-authoritative family subscription state.
///
/// Client purchase callbacks are never sufficient to grant an entitlement;
/// only a verified response from the backend may produce [plusActive].
enum EntitlementStatus {
  free,
  active,
  gracePeriod,
  canceledActive,
  billingIssue,
  expired,
  revoked,
  verificationPending,
  unavailable,
}

@immutable
class FamilyEntitlement {
  const FamilyEntitlement({
    required this.familyId,
    required this.status,
    required this.features,
    this.expiresAt,
    this.verifiedAt,
  });

  final String familyId;
  final EntitlementStatus status;
  final Set<String> features;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;

  bool get plusActive =>
      (status == EntitlementStatus.active ||
          status == EntitlementStatus.gracePeriod ||
          status == EntitlementStatus.canceledActive) &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  factory FamilyEntitlement.fromJson(Map<String, Object?> json) {
    final statusName = json['status']?.toString();
    final status = EntitlementStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => EntitlementStatus.unavailable,
    );
    final rawFeatures = json['features'];
    final features = rawFeatures is List
        ? rawFeatures.map((value) => value.toString()).toSet()
        : <String>{};
    return FamilyEntitlement(
      familyId: json['family_id']?.toString() ?? '',
      status: status,
      features: Set.unmodifiable(features),
      expiresAt: _date(json['expires_at']),
      verifiedAt: _date(json['verified_at']),
    );
  }

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;
}

/// Store-neutral billing boundary. Implementations must report store events
/// to the server and must not treat local purchase state as an entitlement.
abstract interface class BillingProvider {
  Future<List<BillingProduct>> loadProducts();
  Future<void> purchase(BillingProduct product);
  Future<void> restorePurchases();
  Stream<BillingPurchaseEvent> get purchaseEvents;
}

class BillingProduct {
  const BillingProduct({
    required this.id,
    required this.title,
    required this.localizedPrice,
    required this.period,
  });

  final String id;
  final String title;
  final String localizedPrice;
  final String period;
}

abstract interface class BillingProductPurchaser {
  Future<void> purchaseProduct(String productId);
}

class BillingPurchaseEvent {
  const BillingPurchaseEvent({
    required this.productId,
    required this.status,
    this.serverVerificationData,
    this.complete,
  });

  final String productId;
  final String status;
  final String? serverVerificationData;

  /// Complete the store transaction only after the backend accepted it.
  final Future<void> Function()? complete;
}

/// Billing remains disabled until products, verification credentials, and
/// operational readiness are explicitly configured for a release.
const bool billingEnabled = bool.fromEnvironment(
  'MHURI_BILLING_ENABLED',
  defaultValue: false,
);

const String plusMonthlyProductId = String.fromEnvironment(
  'MHURI_PLUS_MONTHLY_PRODUCT_ID',
  defaultValue: 'mhuri_plus_monthly',
);
const String plusAnnualProductId = String.fromEnvironment(
  'MHURI_PLUS_ANNUAL_PRODUCT_ID',
  defaultValue: 'mhuri_plus_annual',
);

const String plusFunctionalityDescription =
    'Advanced reports, insights, savings projections, and family tools';
