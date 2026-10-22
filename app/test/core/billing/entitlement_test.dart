import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/billing/billing_coordinator.dart';
import 'package:mhuri_money/core/billing/entitlement.dart';

void main() {
  group('FamilyEntitlement', () {
    test('unknown and malformed server states fail closed', () {
      final entitlement = FamilyEntitlement.fromJson(const {
        'family_id': 'family-1',
        'status': 'unexpected',
        'features': ['advanced_reports'],
      });

      expect(entitlement.status, EntitlementStatus.unavailable);
      expect(entitlement.plusActive, isFalse);
      expect(entitlement.features, contains('advanced_reports'));
    });

    test('expired Plus entitlement is not active', () {
      final entitlement = FamilyEntitlement.fromJson(const {
        'family_id': 'family-1',
        'status': 'active',
        'expires_at': '2000-01-01T00:00:00Z',
      });

      expect(entitlement.plusActive, isFalse);
    });

    test('future verified Plus entitlement is active', () {
      final entitlement = FamilyEntitlement.fromJson(const {
        'family_id': 'family-1',
        'status': 'active',
        'features': ['advanced_reports'],
        'expires_at': '2999-01-01T00:00:00Z',
      });

      expect(entitlement.plusActive, isTrue);
      expect(entitlement.features, contains('advanced_reports'));
    });
  });

  test('billing feature flag defaults off', () {
    expect(billingEnabled, isFalse);
  });

  test('purchase is completed only after backend verification', () async {
    final provider = _TestBillingProvider();
    final verified = Completer<void>();
    var completed = false;
    var receivedPlus = false;
    final coordinator = BillingCoordinator(
      provider: provider,
      verifyPurchase: (token, productId) async {
        expect(token, 'server-token');
        expect(productId, plusMonthlyProductId);
        return const FamilyEntitlement(
          familyId: 'family-1',
          status: EntitlementStatus.active,
          features: {'advanced_reports'},
        );
      },
      onEntitlement: (entitlement) {
        receivedPlus = entitlement.plusActive;
      },
    );

    provider.emit(BillingPurchaseEvent(
      productId: plusMonthlyProductId,
      status: 'purchased',
      serverVerificationData: 'server-token',
      complete: () async {
        completed = true;
        verified.complete();
      },
    ));
    await verified.future;

    expect(receivedPlus, isTrue);
    expect(completed, isTrue);
    await coordinator.dispose();
    await provider.close();
  });

  test('verification failure leaves purchase unfinished', () async {
    final provider = _TestBillingProvider();
    final reportedError = Completer<void>();
    var completed = false;
    final coordinator = BillingCoordinator(
      provider: provider,
      verifyPurchase: (_, __) async => throw StateError('offline'),
      onEntitlement: (_) {},
      onError: (_) => reportedError.complete(),
    );

    provider.emit(BillingPurchaseEvent(
      productId: plusMonthlyProductId,
      status: 'purchased',
      serverVerificationData: 'server-token',
      complete: () async => completed = true,
    ));
    await reportedError.future;

    expect(completed, isFalse);
    await coordinator.dispose();
    await provider.close();
  });
}

class _TestBillingProvider implements BillingProvider, BillingProductPurchaser {
  final _events = StreamController<BillingPurchaseEvent>.broadcast();

  void emit(BillingPurchaseEvent event) => _events.add(event);
  Future<void> close() => _events.close();

  @override
  Stream<BillingPurchaseEvent> get purchaseEvents => _events.stream;

  @override
  Future<List<BillingProduct>> loadProducts() async => const [];

  @override
  Future<void> purchase(BillingProduct product) async {}

  @override
  Future<void> purchaseProduct(String productId) async {}

  @override
  Future<void> restorePurchases() async {}
}
