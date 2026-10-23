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
        final entitlement = state.familyEntitlement;
        final active = state.hasPlus;
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
                      const SizedBox(height: 10),
                      Text(
                        'One subscription covers your entire family space. Core family budgeting, expenses, savings, debts, shopping, tasks, and chat always remain free.',
                        style: TextStyle(
                          color: context.inkSoft,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!state.hasSpace)
                  const _Notice('Join or create a family before managing its subscription.'),
                if (state.hasSpace && !canPurchase && !active)
                  const _Notice('Ask a parent or family admin to manage the family subscription.'),
                if (entitlement != null) _LifecycleBanner(entitlement: entitlement, active: active),
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
                const _PlanComparisonCard(),
                const SizedBox(height: 16),
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
    if (raw.contains('FAMILY_ALREADY_HAS_PURCHASE')) {
      return 'This family already has an active Plus subscription.';
    }
    return raw.replaceFirst('Exception: ', '');
  }
}

class _LifecycleBanner extends StatelessWidget {
  const _LifecycleBanner({required this.entitlement, required this.active});

  final FamilyEntitlement entitlement;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final expiryText = entitlement.expiresAt != null
        ? ' · Period ends ${entitlement.expiresAt!.toLocal().toIso8601String().substring(0, 10)}'
        : '';
    final offlineBadge = entitlement.isOfflineSnapshot
        ? ' (Cached offline snapshot · valid up to 72h after server verification)'
        : '';
    final text = switch (entitlement.status) {
      EntitlementStatus.active =>
        'Status: active$expiryText$offlineBadge. Shared with all family members.',
      EntitlementStatus.gracePeriod =>
        'Status: gracePeriod$expiryText$offlineBadge. Payment retry in progress in Google Play; Plus access remains active.',
      EntitlementStatus.canceledActive =>
        'Status: canceledActive$expiryText$offlineBadge. Auto-renewal is off; Plus remains active until the end of the current period.',
      EntitlementStatus.billingIssue =>
        'Status: billingIssue. Update your payment method in Google Play to restore Plus access.',
      EntitlementStatus.expired =>
        'Status: expired$expiryText. Renew in Google Play to re-enable Plus planning features.',
      EntitlementStatus.revoked =>
        'Status: revoked. This subscription was refunded or revoked in Google Play.',
      EntitlementStatus.verificationPending =>
        'Status: verificationPending. Waiting for server verification.',
      EntitlementStatus.free =>
        'Current plan: Mhuri Free.',
      EntitlementStatus.unavailable =>
        'Subscription status is temporarily unavailable.',
    };
    if (entitlement.status == EntitlementStatus.free && !active) {
      return const SizedBox.shrink();
    }
    return _Notice(text);
  }
}

class _PlanComparisonCard extends StatelessWidget {
  const _PlanComparisonCard();

  static const _plusFeatures = [
    (
      'Smart Bills & Commitments',
      'One-time & recurring obligations, due-date schedules, partial payments, and multiple reminders.',
    ),
    (
      'Payday-to-Payday Planner',
      'Forward-looking cash outlook, shortfall detection, and non-destructive what-if scenarios.',
    ),
    (
      'Automated Period Preparation',
      'Preview-first preparation of budgets, commitments, savings plans, and reusable shopping items.',
    ),
    (
      'Financial Health Check',
      'Actionable period reviews, comparisons, shortfalls, and drill-down supporting evidence.',
    ),
    (
      'Advanced Savings & Debt Planning',
      'Contribution schedules, payoff timelines, and what-if target comparisons.',
    ),
    (
      'Premium Family Collaboration',
      'Family chat polls, pinned messages hub, and advanced server-filtered chat search.',
    ),
  ];

  static const _freeFeatures = [
    'Family space creation, invites, roles & permissions',
    'Income, expenses, split transactions, budgets & categories',
    'Basic recurring bills & "Use last month" budget copy',
    'Savings goals, contributions, debts & repayments',
    'Shopping lists, checkout, family tasks, chat & CSV export',
  ];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Included in Mhuri Plus',
              style: TextStyle(
                color: context.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in _plusFeatures) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, size: 18, color: context.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.$1,
                          style: TextStyle(
                            color: context.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: context.inkSoft,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Divider(color: context.hairline, height: 20),
            Text(
              'Always free in Mhuri Free',
              style: TextStyle(
                color: context.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final feature in _freeFeatures) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check, size: 16, color: context.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: TextStyle(
                          color: context.inkSoft,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
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

