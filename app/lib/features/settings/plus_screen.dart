import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/billing/billing_coordinator.dart';
import '../../core/billing/entitlement.dart';
import '../../core/billing/google_play_billing_provider.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart' show Role;

class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  GooglePlayBillingProvider? _provider;
  BillingCoordinator? _coordinator;
  List<BillingProduct> _products = const [];
  StreamSubscription<BillingPurchaseEvent>? _purchaseSubscription;
  bool _loadingProducts = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;
  Completer<void>? _restoreResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final state = AppScope.of(context);
    if (state.sync == null || !state.hasSpace) return;
    if (billingEnabled) {
      setState(() => _loadingProducts = true);
      try {
      final provider = GooglePlayBillingProvider();
      final coordinator = BillingCoordinator(
        provider: provider,
        verifyPurchase: (token, productId) => state.refreshFamilyEntitlement(
          purchaseToken: token,
          productId: productId,
        ),
        onEntitlement: (_) {
          if (!mounted) return;
          setState(() {
            _message = 'Purchase verified. Plus is available to your family.';
            _messageIsError = false;
            _busy = false;
          });
          _restoreResult?.complete();
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _message = _readableError(error);
            _messageIsError = true;
            _busy = false;
          });
          _restoreResult?.complete();
        },
      );
      _provider = provider;
      _coordinator = coordinator;
      _purchaseSubscription = provider.purchaseEvents.listen((event) {
        if (!mounted) return;
        if (event.status == 'pending') {
          setState(() {
            _busy = true;
            _message = 'Purchase pending in Google Play…';
            _messageIsError = false;
          });
        } else if (event.status == 'error' || event.status == 'canceled') {
          setState(() {
            _busy = false;
            _message = event.status == 'canceled'
                ? 'Purchase canceled.'
                : 'Google Play could not complete the purchase.';
            _messageIsError = event.status == 'error';
          });
        }
      });
      final products = await provider.loadProducts();
      if (!mounted) return;
      setState(() => _products = products);
      } catch (error) {
        if (mounted) {
          setState(() {
            _message = _readableError(error);
            _messageIsError = true;
          });
        }
      } finally {
        if (mounted) setState(() => _loadingProducts = false);
      }
    }
    if (!mounted) return;
    try {
      await state.refreshFamilyEntitlement();
    } catch (error) {
      if (mounted && billingEnabled) {
        setState(() {
          _message ??= _readableError(error);
          _messageIsError = true;
        });
      }
    }
  }

  Future<void> _purchase(BillingProduct product) async {
    final purchaser = _coordinator;
    if (purchaser == null) return;
    setState(() {
      _busy = true;
      _message = 'Waiting for Google Play…';
      _messageIsError = false;
    });
    try {
      await purchaser.purchaseProduct(product.id);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _message = _readableError(error);
          _messageIsError = true;
        });
      }
    }
  }

  Future<void> _restore() async {
    final state = AppScope.of(context);
    setState(() {
      _busy = true;
      _message = 'Checking purchases…';
      _messageIsError = false;
    });
    try {
      if (billingEnabled && _provider != null) {
        _restoreResult = Completer<void>();
        await _provider!.restorePurchases();
        await _restoreResult!.future.timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
      } else {
        final entitlement = await state.refreshFamilyEntitlement();
        if (!entitlement.plusActive) {
          setState(() => _message = 'No active Plus subscription was found.');
        }
      }
      if (mounted && state.familyEntitlement?.plusActive == true) {
        setState(() => _message = 'Plus is active for this family.');
      } else if (mounted && !_messageIsError) {
        setState(() => _message ??= 'No active Plus subscription was found.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _readableError(error);
          _messageIsError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    unawaited(_purchaseSubscription?.cancel());
    unawaited(_coordinator?.dispose().whenComplete(() => _provider?.dispose()));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final active = state.familyEntitlement?.plusActive == true;
        final canPurchase = const {Role.owner, Role.admin, Role.adult}
            .contains(state.authRole);
        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(title: const Text('Mhuri Plus')),
          body: SafeArea(
            child: ListView(
              padding: kPageInsets,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.workspace_premium, color: context.primary, size: 34),
                      const SizedBox(height: 12),
                      Text(
                        active ? 'Plus is active for your family' : 'More clarity for your whole family',
                        style: TextStyle(
                          color: context.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plusFunctionalityDescription,
                        style: TextStyle(color: context.inkSoft, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!state.hasSpace)
                  const _Notice('Join or create a family before managing its subscription.'),
                if (state.hasSpace && !canPurchase && !active)
                  const _Notice('Ask a parent or family admin to manage the family subscription.'),
                if (active)
                  _Notice('Status: ${state.familyEntitlement!.status.name}. This subscription is shared with family members.'),
                if (!billingEnabled)
                  const _Notice('Purchases are not enabled in this build. Configure Google Play products and server verification before release.'),
                if (billingEnabled && !Platform.isAndroid)
                  const _Notice('Purchases are available in the Android app through Google Play.'),
                if (billingEnabled && Platform.isAndroid) ...[
                  if (_loadingProducts && _products.isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20), child: CircularProgressIndicator(),
                    )),
                  for (final product in _products)
                    Card(
                      color: context.card,
                      child: ListTile(
                        title: Text(product.period == 'annual' ? 'Annual plan' : 'Monthly plan'),
                        subtitle: Text('${product.title}\n${product.localizedPrice} / ${product.period}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy || active || !canPurchase
                            ? null
                            : () => _purchase(product),
                      ),
                    ),
                  if (!_loadingProducts && _products.isEmpty)
                    const _Notice('No Plus plans are available from Google Play yet. Check the configured product IDs and Play Console availability.'),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy || !state.hasSpace ? null : _restore,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restore purchases / refresh status'),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(_message!, style: TextStyle(
                    color: _messageIsError ? context.danger : context.inkSoft,
                  )),
                ],
                const SizedBox(height: 20),
                Text(
                  'Subscriptions renew through Google Play. Cancel or manage renewal in your Google Play account. Family access is granted only after server verification.',
                  style: TextStyle(fontSize: 12, color: context.inkSoft, height: 1.4),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _readableError(Object error) {
    final raw = error.toString();
    if (raw.contains('STORE_VERIFICATION_NOT_CONFIGURED') ||
        raw.contains('STORE_PRODUCTS_NOT_CONFIGURED')) {
      return 'Store verification is not configured yet. No charge or Plus access was applied.';
    }
    if (raw.contains('FAMILY_ACCESS_DENIED')) {
      return 'This account is no longer an active member of that family.';
    }
    if (raw.contains('PURCHASE_ALREADY_CLAIMED')) {
      return 'This purchase is already linked to another family.';
    }
    return raw.replaceFirst('Exception: ', '');
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.hairline),
        ),
        child: Text(message, style: TextStyle(color: context.inkSoft, height: 1.4)),
      );
}

