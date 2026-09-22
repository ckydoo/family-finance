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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFabTip());
  }

  /// First-run discoverability for the central + (one-time, kv-flagged).
  Future<void> _maybeFabTip() async {
    final s = AppScope.of(context);
    if (await s.db?.kvGet('fab_tip_seen') == '1') return;
    await s.db?.kvSet('fab_tip_seen', '1');
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.fabTip),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final destinations = [
      _NavDest(Icons.home_outlined, Icons.home_rounded, l.tabHome),
      _NavDest(Icons.pie_chart_outline, Icons.pie_chart, l.tabBudgets),
      _NavDest(Icons.savings_outlined, Icons.savings, l.tabSavings),
      _NavDest(Icons.list_outlined, Icons.list_rounded, l.tabLists),
    ];

    // IndexedStack keeps each tab's scroll position alive.
    // 4 nav destinations map 1:1 onto the 4 stacked screens (the FAB is
    // docked in the BottomAppBar gap — it is not a tab slot).
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
      floatingActionButton: FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.addTransaction,
        onPressed: () => showQuickAdd(context),
        backgroundColor: context.accent,
        elevation: 4,
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.hairline)),
        ),
        child: BottomAppBar(
          height: 68,
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
              const SizedBox(width: 84),
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
    );
  }

  Widget _nav(_NavDest d, int idx) {
    final selected = _tab == idx;
    // Extreme text scale: icons only — the row can never overflow.
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
            ] else const SizedBox(height: 6),
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
