import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeProductTour());
  }

  /// Three concise first-run explanations, persisted on this device.
  Future<void> _maybeProductTour() async {
    final s = AppScope.of(context);
    final db = s.db;
    if (db == null || !s.canAuthorTransact || _tourOpen) return;
    if (await db.kvGet('product_tour_v1_seen') == '1') return;
    // Persist before presenting. If the app is killed while the sheet is
    // open, the tour must still remain a true once-per-device experience.
    await db.kvSet('product_tour_v1_seen', '1');
    if (!mounted) return;
    _tourOpen = true;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      backgroundColor: context.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => _ProductTour(
        onComplete: () async {
          if (sheetContext.mounted) Navigator.pop(sheetContext);
        },
      ),
    );
    _tourOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final s = AppScope.of(context);
    final destinations = [
      _NavDest(Icons.home_outlined, Icons.home_rounded, l.tabHome),
      _NavDest(Icons.pie_chart_outline, Icons.pie_chart, l.tabBudgets),
      _NavDest(Icons.savings_outlined, Icons.savings, l.tabSavings),
      _NavDest(Icons.shopping_cart_outlined, Icons.shopping_cart, l.tabLists),
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
            children: const [
              HomeScreen(),
              BudgetsScreen(),
              SavingsScreen(),
              ListsScreen(),
            ],
          ),
        ),
      ),
      floatingActionButton: s.canAuthorTransact
          ? FloatingActionButton(
              tooltip: AppLocalizations.of(context)!.addTransaction,
              onPressed: () => showQuickAddMenu(context),
              backgroundColor: context.accent,
              elevation: 4,
              child: const Icon(Icons.add, size: 30, color: Colors.white),
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
                        _nav(destinations[1], 1),
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

  Widget _nav(_NavDest d, int idx) {
    final selected = _tab == idx;
    // Extreme text scale: icons only - the row can never overflow.
    final huge = MediaQuery.textScalerOf(context).scale(11) >= 19;
    final color = selected ? context.primaryDark : context.ink;
    return Expanded(
      child: InkWell(
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
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
  const _ProductTour({required this.onComplete});

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
      (Icons.pie_chart_outline_rounded, l.tourPlanTitle, l.tourPlanBody),
      (Icons.add_circle_outline_rounded, l.tourAddTitle, l.tourAddBody),
    ];
    final page = pages[_page];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: context.hairline,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.tourTitle,
                  style: TextStyle(
                    color: context.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: _closing ? null : _finish,
                child: Text(l.skip),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Icon(page.$1, size: 46, color: context.primary),
          const SizedBox(height: 18),
          Text(
            page.$2,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            page.$3,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: context.inkSoft, fontSize: 14, height: 1.45),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == _page ? 22 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == _page ? context.primary : context.hairline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _closing
                ? null
                : () {
                    if (_page == pages.length - 1) {
                      _finish();
                    } else {
                      setState(() => _page++);
                    }
                  },
            style: FilledButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: context.onSolid,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
            ),
            child: Text(
              _page == pages.length - 1 ? l.done : l.next,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
