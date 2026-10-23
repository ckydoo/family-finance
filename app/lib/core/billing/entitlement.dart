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
    this.userId,
    this.isOfflineSnapshot = false,
  });

  /// Maximum duration an offline read-only entitlement snapshot remains valid
  /// after a trusted server verification.
  static const Duration maxOfflineCacheAge = Duration(hours: 72);

  final String familyId;
  final EntitlementStatus status;
  final Set<String> features;
  final DateTime? expiresAt;
  final DateTime? verifiedAt;
  final String? userId;
  final bool isOfflineSnapshot;

  bool get plusActive => isActiveAt(DateTime.now());

  bool isActiveAt(DateTime now) {
    final activeStatus = status == EntitlementStatus.active ||
        status == EntitlementStatus.gracePeriod ||
        status == EntitlementStatus.canceledActive;
    if (!activeStatus) return false;
    final nowUtc = now.toUtc();
    if (expiresAt != null && !expiresAt!.toUtc().isAfter(nowUtc)) {
      return false;
    }
    if (isOfflineSnapshot) {
      if (verifiedAt == null) return false;
      final age = nowUtc.difference(verifiedAt!.toUtc());
      if (age.isNegative && age.abs() > const Duration(minutes: 5)) {
        return false;
      }
      if (age > maxOfflineCacheAge) return false;
    }
    return true;
  }

  /// Validates and converts this entitlement into a bounded read-only offline
  /// snapshot scoped to [expectedFamilyId] and [expectedUserId]. Returns null
  /// if family/user scope mismatches or the 72-hour window has elapsed.
  FamilyEntitlement? toOfflineSnapshot({
    required String expectedFamilyId,
    required String expectedUserId,
    required DateTime now,
  }) {
    if (expectedFamilyId.isEmpty ||
        expectedUserId.isEmpty ||
        familyId != expectedFamilyId ||
        userId != expectedUserId ||
        verifiedAt == null) {
      return null;
    }
    final candidate = FamilyEntitlement(
      familyId: familyId,
      status: status,
      features: features,
      expiresAt: expiresAt,
      verifiedAt: verifiedAt,
      userId: userId,
      isOfflineSnapshot: true,
    );
    return candidate.isActiveAt(now) ? candidate : null;
  }

  Map<String, Object?> toJson({String? userId}) => {
        'family_id': familyId,
        'status': status.name,
        'features': features.toList(growable: false),
        'expires_at': expiresAt?.toUtc().toIso8601String(),
        'verified_at': verifiedAt?.toUtc().toIso8601String(),
        if ((userId ?? this.userId) != null) 'user_id': userId ?? this.userId,
      };

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
      userId: json['user_id']?.toString(),
      isOfflineSnapshot: json['is_offline_snapshot'] == true,
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
    'Smart bills & commitments, payday-to-payday planner, automated period preparation, financial health check, savings & debt scenarios, and family polls, pins & advanced search';

const Set<String> kPlusV2Features = {
  'smart_commitments',
  'cash_flow_forecast',
  'period_preparation',
  'financial_health',
  'savings_projections',
  'debt_planning',
  'family_polls_pins',
  'advanced_chat_search',
  'advanced_insights',
  'advanced_reports',
  'enhanced_reports',
};
