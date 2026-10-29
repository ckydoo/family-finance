import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/billing/billing_coordinator.dart';
import '../../core/billing/entitlement.dart';
import '../../core/billing/google_play_billing_provider.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/models.dart' show Role;
import '../../core/widgets/plus_ui.dart';
import '../budgets/period_preparation_screen.dart';
import '../commitments/commitments_screen.dart';
import '../planner/payday_planner_screen.dart';
import '../reports/financial_health_screen.dart';
import '../savings/advanced_planning_screen.dart';

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
      if (billingEnabled && _provider != null && !state.hasPlus) {
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
        final canPurchase =
            const {Role.owner, Role.admin, Role.adult}.contains(state.authRole);
        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(title: const Text('Mhuri Plus')),
          body: SafeArea(
            child: ListView(
              padding: kPageInsets,
              children: [
                PlusHero(
                  eyebrow: active ? 'Membership active' : 'Mhuri Plus',
                  title: active
                      ? 'Your whole family has Plus'
                      : 'Plan ahead with more confidence',
                  description: active
                      ? 'Use advanced planning tools and enhanced family chat across this family space.'
                      : 'Plan ahead with cash-flow forecasts, goal scenarios, and enhanced family collaboration.',
                  icon: active
                      ? Icons.verified_rounded
                      : Icons.workspace_premium_rounded,
                  trailing: active
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: context.accent,
                              borderRadius: BorderRadius.circular(99)),
                          child: Text('ACTIVE',
                              style: MhuriType.caption.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSecondary)),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                if (active) ...[
                  Text('What would you like to do?',
                      style: MhuriType.titleM.copyWith(color: context.ink)),
                  const SizedBox(height: 10),
                  _GoalEntry(
                    icon: Icons.insights_rounded,
                    title: 'Can we afford everything until payday?',
                    subtitle: 'Build a simple cash outlook',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const PaydayPlannerScreen(),
                    )),
                  ),
                  _GoalEntry(
                    icon: Icons.event_repeat_rounded,
                    title: 'Keep track of rent and bills',
                    subtitle: 'Set due dates, reminders and payments',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const CommitmentsScreen(),
                    )),
                  ),
                  _GoalEntry(
                    icon: Icons.savings_rounded,
                    title: 'Plan a goal or clear a debt',
                    subtitle: 'See realistic completion dates',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const AdvancedPlanningScreen(),
                    )),
                  ),
                  _GoalEntry(
                    icon: Icons.health_and_safety_outlined,
                    title: 'See how the family is doing',
                    subtitle: 'Review the current financial picture',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const FinancialHealthScreen(),
                    )),
                  ),
                  _GoalEntry(
                    icon: Icons.next_plan_outlined,
                    title: 'Set up the next period',
                    subtitle: 'Review and carry plans forward',
                    onTap: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const PeriodPreparationScreen(),
                    )),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!state.hasSpace)
                  const _Notice(
                      'Join or create a family before managing its subscription.'),
                if (state.hasSpace && !canPurchase && !active)
                  const _Notice(
                      'Ask a parent or family admin to manage the family subscription.'),
                if (entitlement != null)
                  _LifecycleBanner(entitlement: entitlement, active: active),
                if (!active && !billingEnabled)
                  const _Notice(
                      'Purchases are not enabled in this build. Configure Google Play products and server verification before release.'),
                if (billingEnabled && !Platform.isAndroid)
                  const _Notice(
                      'Purchases are available in the Android app through Google Play.'),
                if (!active && billingEnabled && Platform.isAndroid) ...[
                  if (_loadingProducts && _products.isEmpty)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )),
                  for (final product in _products) ...[
                    _PlanCard(
                      product: product,
                      recommended: product.period == 'annual',
                      onTap: _busy || !canPurchase
                          ? null
                          : () => _purchase(product),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (!_loadingProducts && _products.isEmpty)
                    const _Notice(
                        'No Plus plans are available from Google Play yet. Check the configured product IDs and Play Console availability.'),
                ],
                const SizedBox(height: 12),
                PlusSectionCard(
                  title: active ? 'Membership' : 'Already subscribed?',
                  subtitle: active
                      ? 'Plus is shared with everyone in this family.'
                      : billingEnabled
                          ? 'Restore a purchase made with this Google Play account.'
                          : 'Check whether this family has an active Plus membership.',
                  icon: active
                      ? Icons.family_restroom_rounded
                      : Icons.restore_rounded,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy || !state.hasSpace ? null : _restore,
                      icon: const Icon(Icons.sync_rounded),
                      label: Text(active || !billingEnabled
                          ? 'Check Plus status'
                          : 'Restore purchase'),
                    ),
                  ),
                ),
                if (_busy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  PlusInlineMessage(
                      message: _message!,
                      isError: _messageIsError,
                      onRetry: _messageIsError ? _restore : null),
                ],
                const SizedBox(height: 20),
                const _PlanComparisonCard(),
                const SizedBox(height: 16),
                Text(
                  'Google Play manages your subscription. While Plus is active, family spaces created through this account share Plus access; each space keeps its own finances and members.',
                  textAlign: TextAlign.center,
                  style: MhuriType.caption
                      .copyWith(color: context.inkSoft, height: 1.4),
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
    return friendlyPlusError(error);
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.product, required this.recommended, this.onTap});

  final BillingProduct product;
  final bool recommended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.card,
        shape: RoundedRectangleBorder(
          borderRadius: kBRadiusL,
          side: BorderSide(
              color: recommended ? context.accent : context.hairline,
              width: recommended ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: kBRadiusL,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: recommended
                          ? context.accentSoft
                          : context.primarySoft,
                      borderRadius: kBRadiusM),
                  child: Icon(
                      recommended
                          ? Icons.stars_rounded
                          : Icons.calendar_month_rounded,
                      color:
                          recommended ? context.accentDark : context.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(product.period == 'annual' ? 'Annual' : 'Monthly',
                            style:
                                MhuriType.titleM.copyWith(color: context.ink)),
                        if (recommended) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                color: context.accentSoft,
                                borderRadius: BorderRadius.circular(99)),
                            child: Text('BEST VALUE',
                                style: MhuriType.caption.copyWith(
                                    color: context.accentDark, fontSize: 10)),
                          ),
                        ],
                      ]),
                      Text('${product.localizedPrice} / ${product.period}',
                          style:
                              MhuriType.body.copyWith(color: context.inkSoft)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: context.primary),
              ],
            ),
          ),
        ),
      );
}

class _GoalEntry extends StatelessWidget {
  const _GoalEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: context.card,
          shape: RoundedRectangleBorder(
            borderRadius: kBRadiusL,
            side: BorderSide(color: context.hairline),
          ),
          child: ListTile(
            onTap: onTap,
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: context.accentSoft,
                borderRadius: kBRadiusM,
              ),
              child: Icon(icon, color: context.accentDark),
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.arrow_forward_rounded),
          ),
        ),
      );
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
      EntitlementStatus.free => 'Current plan: Mhuri Free.',
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
      'Track variable, one-time, and recurring obligations with due dates, partial payments, and reminders. Fixed recurring expense rules stay free.',
    ),
    (
      'Payday-to-Payday Planner',
      'Forward-looking cash outlook, shortfall detection, and non-destructive what-if scenarios.',
    ),
    (
      'Prepare the Next Budget Period',
      'Review a suggested carry-forward plan based on past activity, edit it, then apply it yourself.',
    ),
    (
      'Financial Health Check',
      'Actionable period reviews, comparisons, shortfalls, and drill-down supporting evidence.',
    ),
    (
      'Enhanced Reports & Category Insights',
      'Compare category spending across periods and explore deeper family reports. Standard reports and CSV export stay free.',
    ),
    (
      'Advanced Savings & Debt Planning',
      'Contribution schedules, payoff timelines, and what-if target comparisons.',
    ),
    (
      'Premium Family Collaboration',
      'Photos and voice notes, emoji and stickers, message editing, task and budget references, polls, pinned messages, and advanced chat search. Family text chat, replies, and deleting your own messages stay free.',
    ),
    (
      'Separate Family Spaces',
      'Create additional family spaces with separate members and finances while Mhuri Plus is active.',
    ),
    (
      'More Family Members',
      'Invite more than five members to Plus family spaces.',
    ),
  ];

  static const _freeFeatures = [
    'Family space creation, invites, roles & permissions',
    'One created family space with up to five members',
    'Income, expenses, split transactions, budgets & categories',
    'Fixed recurring expenses (amount and frequency), with post or skip',
    'Copy last month’s budget plan and review it before saving',
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
        child: Text(message,
            style: TextStyle(color: context.inkSoft, height: 1.4)),
      );
}
