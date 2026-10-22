import 'dart:async';
import 'dart:io';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'entitlement.dart';

/// Google Play adapter for the store-neutral [BillingProvider] contract.
///
/// Purchase completion is deliberately deferred to the consumer: it must
/// first submit `serverVerificationData` to the authenticated backend and
/// receive an accepted entitlement response. This class is inert unless the
/// build explicitly sets `MHURI_BILLING_ENABLED=true`.
class GooglePlayBillingProvider
    implements BillingProvider, BillingProductPurchaser {
  GooglePlayBillingProvider({InAppPurchase? store})
      : _store = store ?? InAppPurchase.instance {
    _purchaseSubscription = _store.purchaseStream.listen(
      _onPurchases,
      onError: _events.addError,
    );
  }

  final InAppPurchase _store;
  final StreamController<BillingPurchaseEvent> _events =
      StreamController<BillingPurchaseEvent>.broadcast();
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  static const Set<String> _productIds = {
    plusMonthlyProductId,
    plusAnnualProductId,
  };

  @override
  Stream<BillingPurchaseEvent> get purchaseEvents => _events.stream;

  @override
  Future<List<BillingProduct>> loadProducts() async {
    if (!billingEnabled || !Platform.isAndroid) return const [];
    if (!await _store.isAvailable()) return const [];
    final response = await _store.queryProductDetails(_productIds);
    if (response.error != null) {
      throw StateError(
        'Google Play product query failed: ${response.error}',
      );
    }
    _products
      ..clear()
      ..addEntries(response.productDetails
          .map((product) => MapEntry(product.id, product)));
    return response.productDetails
        .map((product) => BillingProduct(
              id: product.id,
              title: product.title,
              localizedPrice: product.price,
              period: product.id == plusAnnualProductId ? 'annual' : 'monthly',
            ))
        .toList(growable: false);
  }

  @override
  Future<void> purchase(BillingProduct product) async {
    if (!billingEnabled) {
      throw StateError('Billing is disabled for this build.');
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('Google Play billing is Android-only.');
    }
    final details = _products[product.id];
    if (details == null || !_productIds.contains(product.id)) {
      throw StateError('Product is not available from Google Play.');
    }
    final launched = await _store.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!launched) throw StateError('Google Play purchase did not start.');
  }

  @override
  Future<void> purchaseProduct(String productId) async {
    if (!billingEnabled) {
      throw StateError('Billing is disabled for this build.');
    }
    final product = _products[productId];
    if (product == null) throw StateError('Product is not available from Google Play.');
    await purchase(BillingProduct(
      id: product.id,
      title: product.title,
      localizedPrice: product.price,
      period: product.id == plusAnnualProductId ? 'annual' : 'monthly',
    ));
  }

  @override
  Future<void> restorePurchases() async {
    if (!billingEnabled) return;
    if (!Platform.isAndroid) {
      throw UnsupportedError('Google Play billing is Android-only.');
    }
    await _store.restorePurchases();
  }

  void _onPurchases(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final event = BillingPurchaseEvent(
        productId: purchase.productID,
        status: purchase.status.name,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
        complete: purchase.pendingCompletePurchase
            ? () => _store.completePurchase(purchase)
            : null,
      );
      _events.add(event);
    }
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
    await _events.close();
  }
}
