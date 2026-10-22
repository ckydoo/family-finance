import 'dart:async';

import 'entitlement.dart';

/// Routes store updates through server verification before completing them.
/// Keep this uninstantiated until the app has an explicitly approved Plus UI.
class BillingCoordinator implements BillingProductPurchaser {
  BillingCoordinator({
    required BillingProvider provider,
    required Future<FamilyEntitlement> Function(
            String purchaseToken, String productId)
        verifyPurchase,
    required void Function(FamilyEntitlement entitlement) onEntitlement,
    void Function(Object error)? onError,
  })  : _provider = provider,
        _verifyPurchase = verifyPurchase,
        _onEntitlement = onEntitlement,
        _onError = onError {
    _subscription = _provider.purchaseEvents.listen(
      _handleEvent,
      onError: (Object error) => _onError?.call(error),
    );
  }

  final BillingProvider _provider;
  final Future<FamilyEntitlement> Function(String purchaseToken, String productId)
      _verifyPurchase;
  final void Function(FamilyEntitlement entitlement) _onEntitlement;
  final void Function(Object error)? _onError;
  late final StreamSubscription<BillingPurchaseEvent> _subscription;

  @override
  Future<void> purchaseProduct(String productId) async {
    final products = await _provider.loadProducts();
    final matches = products.where((product) => product.id == productId);
    if (matches.isEmpty) throw StateError('Product is not available.');
    await _provider.purchase(matches.first);
  }

  Future<void> _handleEvent(BillingPurchaseEvent event) async {
    if (event.status != 'purchased' && event.status != 'restored') return;
    if (event.productId != plusMonthlyProductId &&
        event.productId != plusAnnualProductId) {
      _onError?.call(StateError('Store returned an unrecognized product.'));
      return;
    }
    final token = event.serverVerificationData;
    if (token == null || token.isEmpty) {
      _onError?.call(StateError('Store purchase has no verification token.'));
      return;
    }
    try {
      final entitlement = await _verifyPurchase(token, event.productId);
      if (entitlement.status == EntitlementStatus.unavailable) {
        throw StateError('Server did not return a verified entitlement.');
      }
      _onEntitlement(entitlement);
      // A valid but expired/revoked purchase still needs store finalization;
      // the backend response, not Plus activation, is the acceptance signal.
      await event.complete?.call();
    } catch (error) {
      // Leave the transaction unfinished. A later stream replay can retry
      // verification after transient network/server failures.
      _onError?.call(error);
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
