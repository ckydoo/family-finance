import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
///  · the selected item gets the soft-teal pill behind its icon;
///  · one radius ruler, one hairline, labels always visible;
///  · no notch — the rounded-square FAB floats over a clean bar;
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
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final destinations = [
      _NavDest(Icons.home_outlined, Icons.home_rounded, l.tabHome),
      _NavDest(Icons.pie_chart_outline, Icons.pie_chart, l.tabBudgets),
      _NavDest(Icons.savings_outlined, Icons.savings, l.tabSavings),
      _NavDest(Icons.shopping_cart_outlined, Icons.shopping_cart, l.tabLists),
    ];

    // IndexedStack keeps each tab's scroll position alive. The center action
    // button is visual-only, so navigation indices map directly to screens.
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
            )),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: AppLocalizations.of(context)!.addTransaction,
        onPressed: () => showQuickAdd(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.bg, width: 4),
        ),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.hairline)),
        ),
        child: BottomAppBar(
          color: context.card,
          elevation: 0,
          padding: EdgeInsets.zero,
          child: Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                _nav(destinations[i], i),
                if (i == 1) const Spacer(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _nav(_NavDest d, int idx) {
    final selected = _tab == idx;
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? context.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                selected ? d.active : d.rest,
                size: 23,
                color: selected ? context.primaryDark : context.inkFaint,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              d.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.1,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? context.primaryDark : context.inkFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
