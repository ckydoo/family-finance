import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../budgets/budgets_screen.dart';
import '../home/home_screen.dart';
import '../lists/lists_screen.dart';
import '../quickadd/quick_add_sheet.dart';
import '../savings/savings_screen.dart';

/// Adult bottom navigation: Home · Budgets · (＋) · Savings · Lists
///
/// Interface rules (M3-informed, one system):
///  · every destination has an OUTLINED rest icon and a FILLED selected icon;
///  · the selected item turns green (icon + label), no pill;
///  · one radius ruler, one hairline, labels always visible;
///  · center-docked circular amber FAB in a curved notch (CircularNotchedRectangle);
///  · full-cell tap targets (Expanded + InkWell).
class AdultShell extends StatefulWidget {
  const AdultShell({super.key});

  @override
  State<AdultShell> createState() => _AdultShellState();
}

class _NavDest {
  const _NavDest(this.rest, this.active, this.label);

  final IconData rest; // outlined
  final IconData active; // filled
  final String label;
}

class _AdultShellState extends State<AdultShell> {
  int _tab = 0;
  bool _tourOpen = false;
  final _overviewTourKey = GlobalKey();
  final _familyTourKey = GlobalKey();
  final _budgetsTourKey = GlobalKey();
  final _addTourKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProductTour());
  }

  /// Concise first-run explanations, persisted on this device. The route wait
  /// prevents this tutorial from stacking over another startup presentation.
  Future<void> _maybeProductTour() async {
    final s = AppScope.of(context);
    final db = s.db;
    if (db == null || !s.canAuthorTransact || _tourOpen) return;
    _tourOpen = true;
    if (await db.kvGet('product_tour_v1_seen') == '1') {
      _tourOpen = false;
      return;
    }
    // A brand-new household already has the guided Home card with the same
    // income, budget, and spending prompts. Its overview key also wraps that
    // tall card, so opening the coach marks here would spotlight almost the
    // whole screen and stack two onboarding experiences on top of each other.
    // Treat the guided Home experience as the first-run tour for this device.
    if (s.isGuidedHomeActive) {
      await db.kvSet('product_tour_v1_seen', '1');
      _tourOpen = false;
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 650));
    while (mounted && ModalRoute.of(context)?.isCurrent != true) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!mounted) return;
    // Persist before presenting. If the app is killed while the tour is
    // open, the tour must still remain a true once-per-device experience.
    await db.kvSet('product_tour_v1_seen', '1');
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: AppLocalizations.of(context)!.tourTitle,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (tourContext, _, __) => _ProductTour(
        targets: [
          _overviewTourKey,
          _familyTourKey,
          _budgetsTourKey,
          _addTourKey,
        ],
        onComplete: () async {
          if (tourContext.mounted) Navigator.pop(tourContext);
        },
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
    );
    _tourOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = AppScope.of(context);
    final destinations = [
      _NavDest(FontAwesomeIcons.house.data, FontAwesomeIcons.houseChimney.data,
          l.tabHome),
      _NavDest(FontAwesomeIcons.chartPie.data,
          FontAwesomeIcons.chartSimple.data, l.tabBudgets),
      _NavDest(FontAwesomeIcons.coins.data, FontAwesomeIcons.piggyBank.data,
          l.tabSavings),
      _NavDest(FontAwesomeIcons.listCheck.data,
          FontAwesomeIcons.cartShopping.data, l.tabLists),
    ];
    final navTextScale = MediaQuery.textScalerOf(context).scale(11) / 11;
    final navHeight = (68 + ((navTextScale - 1).clamp(0, 1) * 18)).toDouble();

    // IndexedStack keeps each tab's scroll position alive.
    // 4 nav destinations map 1:1 onto the 4 stacked screens (the FAB is
    // docked in the BottomAppBar gap - it is not a tab slot).
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          // Budgets (tab 1) is the two-pane surface; other tabs stay phone-width.
          constraints: BoxConstraints(maxWidth: _tab == 1 ? 980 : 620),
          child: IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                tourOverviewKey: _overviewTourKey,
                tourFamilyKey: _familyTourKey,
              ),
              const BudgetsScreen(),
              const SavingsScreen(),
              const ListsScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: s.canAuthorTransact
          ? FloatingActionButton(
              key: _addTourKey,
              tooltip: AppLocalizations.of(context)!.addTransaction,
              onPressed: () => showQuickAddMenu(context),
              backgroundColor: context.accent,
              elevation: 2,
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: Theme.of(context).brightness == Brightness.dark
                    ? context.onSolid
                    : context.primaryDark,
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: ColoredBox(
        color: context.card,
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.only(bottom: 2),
          child: Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: context.hairline)),
            ),
            child: BottomAppBar(
              // Give accessibility-scaled labels enough vertical room while
              // preserving the compact standard-height navigation bar.
              height: navHeight,
              color: context.card,
              elevation: 0,
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _nav(destinations[0], 0),
                        _nav(destinations[1], 1, key: _budgetsTourKey),
                      ],
                    ),
                  ),
                  SizedBox(width: s.canAuthorTransact ? 84 : 16),
                  Expanded(
                    child: Row(
                      children: [
                        _nav(destinations[2], 2),
                        _nav(destinations[3], 3),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nav(_NavDest d, int idx, {Key? key}) {
    final selected = _tab == idx;
    // Extreme text scale: icons only - the row can never overflow.
    final huge = MediaQuery.textScalerOf(context).scale(11) >= 19;
    final color = selected ? context.primaryDark : context.inkSoft;
    return Expanded(
      child: InkWell(
        key: key,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tab = idx);
        },
        borderRadius: kBRadiusM,
        splashColor: context.primarySoft,
        highlightColor: context.primarySoft,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              scale: selected ? 1.08 : 1.0,
              child: Icon(
                selected ? d.active : d.rest,
                size: huge ? 26 : 22,
                color: color,
              ),
            ),
            if (!huge) ...const [
              SizedBox(height: 2),
            ] else
              const SizedBox(height: 6),
            if (!huge)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  d.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductTour extends StatefulWidget {
  const _ProductTour({required this.targets, required this.onComplete});

  final List<GlobalKey> targets;
  final Future<void> Function() onComplete;

  @override
  State<_ProductTour> createState() => _ProductTourState();
}

class _ProductTourState extends State<_ProductTour> {
  int _page = 0;
  bool _closing = false;

  Future<void> _finish() async {
    if (_closing) return;
    setState(() => _closing = true);
    await widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pages = [
      (Icons.account_balance_wallet_outlined, l.tourPoolTitle, l.tourPoolBody),
      (Icons.family_restroom_rounded, l.tourFamilyTitle, l.tourFamilyBody),
      (Icons.pie_chart_outline_rounded, l.tourPlanTitle, l.tourPlanBody),
      (Icons.add_circle_outline_rounded, l.tourAddTitle, l.tourAddBody),
    ];
    final page = pages[_page];
    final media = MediaQuery.of(context);
    final screen = media.size;
    final targetContext = widget.targets[_page].currentContext;
    final box = targetContext?.findRenderObject() as RenderBox?;
    final rawRect = box == null
        ? Rect.fromCenter(
            center: Offset(screen.width / 2, screen.height / 2),
            width: 56,
            height: 56,
          )
        : box.localToGlobal(Offset.zero) & box.size;
    final target = rawRect.inflate(8);
    final showBelow = target.center.dy < screen.height * .48;
    const horizontalPadding = 16.0;
    final bubbleWidth =
        (screen.width - horizontalPadding * 2).clamp(240.0, 380.0);
    final bubbleLeft = (target.center.dx - bubbleWidth / 2).clamp(
        horizontalPadding, screen.width - bubbleWidth - horizontalPadding);
    final safeTop = media.padding.top + 8;
    final safeBottom = media.padding.bottom + 8;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TourShadePainter(target)),
          ),
          Positioned.fromRect(
            rect: target,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.accent, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: context.accent.withValues(alpha: .35),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: bubbleLeft,
            width: bubbleWidth,
            top: showBelow ? target.bottom + 10 : null,
            bottom: showBelow ? null : screen.height - target.top + 10,
            child: SafeArea(
              top: false,
              bottom: false,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: showBelow
                      ? screen.height - target.bottom - safeBottom - 18
                      : target.top - safeTop - 18,
                ),
                child: _TourBubble(
                  icon: page.$1,
                  title: page.$2,
                  body: page.$3,
                  page: _page,
                  pageCount: pages.length,
                  arrowOnTop: showBelow,
                  arrowX: (target.center.dx - bubbleLeft)
                      .clamp(28.0, bubbleWidth - 28.0),
                  skipLabel: l.skip,
                  nextLabel: _page == pages.length - 1 ? l.done : l.next,
                  closing: _closing,
                  onSkip: _finish,
                  onNext: () {
                    if (_page == pages.length - 1) {
                      _finish();
                    } else {
                      setState(() => _page++);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TourBubble extends StatelessWidget {
  const _TourBubble({
    required this.icon,
    required this.title,
    required this.body,
    required this.page,
    required this.pageCount,
    required this.arrowOnTop,
    required this.arrowX,
    required this.skipLabel,
    required this.nextLabel,
    required this.closing,
    required this.onSkip,
    required this.onNext,
  });

  final IconData icon;
  final String title;
  final String body;
  final int page;
  final int pageCount;
  final bool arrowOnTop;
  final double arrowX;
  final String skipLabel;
  final String nextLabel;
  final bool closing;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final arrow = CustomPaint(
      size: const Size(24, 12),
      painter: _TourArrowPainter(context.card, pointsUp: arrowOnTop),
    );
    return SingleChildScrollView(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: arrowOnTop ? 11 : 0,
              bottom: arrowOnTop ? 0 : 11,
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 24,
                      offset: Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, size: 22, color: context.primary),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              color: context.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ),
                    TextButton(
                        onPressed: closing ? null : onSkip,
                        child: Text(skipLabel)),
                  ]),
                  const SizedBox(height: 6),
                  Text(body,
                      style: TextStyle(
                          color: context.inkSoft, fontSize: 13.5, height: 1.4)),
                  const SizedBox(height: 14),
                  Row(children: [
                    for (var i = 0; i < pageCount; i++)
                      Container(
                        width: i == page ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 5),
                        decoration: BoxDecoration(
                          color: i == page ? context.primary : context.hairline,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: closing ? null : onNext,
                      style: FilledButton.styleFrom(
                          backgroundColor: context.primary,
                          foregroundColor: context.onSolid),
                      child: Text(nextLabel),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            left: arrowX - 12,
            top: arrowOnTop ? 0 : null,
            bottom: arrowOnTop ? null : 0,
            child: arrow,
          ),
        ],
      ),
    );
  }
}

class _TourShadePainter extends CustomPainter {
  const _TourShadePainter(this.hole);
  final Rect hole;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(hole, const Radius.circular(18)));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .58));
  }

  @override
  bool shouldRepaint(_TourShadePainter oldDelegate) => oldDelegate.hole != hole;
}

class _TourArrowPainter extends CustomPainter {
  const _TourArrowPainter(this.color, {required this.pointsUp});
  final Color color;
  final bool pointsUp;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TourArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.pointsUp != pointsUp;
}
