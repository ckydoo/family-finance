import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';

/// Shared shopping list connected to the budget (spec Module F, §7.6).
class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  ItemState? _filter = ItemState.tobuy;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final visible = _filter == null
        ? s.items.toList()
        : s.items.where((i) => i.state == _filter).toList();

    final estUsd = s.estFor(Currency.usd);
    final estZwg = s.estFor(Currency.zwg);
    final groceries = s.envelope('e1');
    final budgetUse = groceries != null && groceries.limit.minor > 0
        ? estUsd.minor / groceries.limit.inCurrency(Currency.usd, s.rate).minor
        : 0.0;
    final hasUnloggedShopping = s.items.any(
      (i) =>
          !i.checkedOut &&
          (i.state == ItemState.done || i.state == ItemState.incart),
    );

    int count(ItemState st) => s.items.where((i) => i.state == st).length;

    return SafeArea(
      child: Stack(
        children: [
          RefreshIndicator(
              onRefresh: () => s.refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 190),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.shopping,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: AppLocalizations.of(context)!.addItem,
                        onPressed: () => _addSheet(context),
                        icon: Icon(Icons.add_circle,
                            color: context.primary, size: 30),
                      ),
                    ],
                  ),
                  Text(
                    AppLocalizations.of(context)!.listSharedSub,
                    style: TextStyle(fontSize: 13, color: context.inkSoft),
                  ),
                  const SizedBox(height: 14),

                  // ── Filter chips ────────────────────────────────────────────
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                            AppLocalizations.of(context)!
                                .filterAll(s.items.length)),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final st in ItemState.values)
                        ChoiceChip(
                          label: Text(
                              '${itemStateLabel(AppLocalizations.of(context)!, st)} (${count(st)})'),
                          selected: _filter == st,
                          onSelected: (_) => setState(() => _filter = st),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Items ───────────────────────────────────────────────────
                  if (visible.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          AppLocalizations.of(context)!.listEmptyAdd,
                          style: TextStyle(color: context.inkSoft),
                        ),
                      ),
                    )
                  else
                    for (final item in visible) ...[
                      _ItemRow(item: item),
                      const SizedBox(height: 8),
                    ],

                  const SizedBox(height: 16),

                  // ── Estimate + budget check ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Est. total: ${estUsd.text} · ≈ ${estZwg.text}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.rateLabel,
                          style:
                              TextStyle(fontSize: 11, color: context.inkSoft),
                        ),
                        const SizedBox(height: 12),
                        if (groceries != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: budgetUse.clamp(0.0, 1.0).toDouble(),
                              minHeight: 8,
                              backgroundColor: context.track,
                              color: budgetUse > 0.9
                                  ? context.danger
                                  : context.primary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppLocalizations.of(context)!.usesPct(
                                (budgetUse * 100).round(), groceries.name),
                            style:
                                TextStyle(fontSize: 12, color: context.inkSoft),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              )),

          // ── Finish shopping button ──────────────────────────────────────
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: ElevatedButton.icon(
              onPressed: hasUnloggedShopping
                  ? () {
                      final total = s.finishShopping();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!
                                .loggedTo(total.text, 'Groceries'),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
                minimumSize: const Size.fromHeight(54),
                shape: const StadiumBorder(),
                elevation: 4,
              ),
              icon: const Icon(Icons.receipt_long),
              label: Text(
                hasUnloggedShopping
                    ? AppLocalizations.of(context)!.finishShop
                    : AppLocalizations.of(context)!.shoppingLogged,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addSheet(BuildContext context) {
    final s = AppScope.of(context);
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    Currency cur = Currency.usd;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.addItem,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l.listNameLabel,
                    filled: true,
                    fillColor: context.card,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qty,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.listQtyLabel,
                          filled: true,
                          fillColor: context.card,
                          border:
                              OutlineInputBorder(borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!
                              .estPrice(cur.symbol),
                          filled: true,
                          fillColor: context.card,
                          border: const OutlineInputBorder(
                              borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('USD'),
                      selected: cur == Currency.usd,
                      onSelected: (_) => setSheet(() => cur = Currency.usd),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ZiG'),
                      selected: cur == Currency.zwg,
                      onSelected: (_) => setSheet(() => cur = Currency.zwg),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final n = name.text.trim();
                    final q = int.tryParse(qty.text) ?? 1;
                    final p = double.tryParse(price.text.replaceAll(',', ''));
                    if (n.isEmpty || p == null) {
                      ScaffoldMessenger.of(sheetCtx).showSnackBar(
                        SnackBar(
                          content: Text(
                              AppLocalizations.of(context)!.namePriceFirst),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    s.addItem(n, q, Money.fromMajor(p, cur));
                    Navigator.pop(sheetCtx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.addToList),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ListItem item;

  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final addedBy = s.member(item.addedById);
    final done = item.state == ItemState.done;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Checkbox(
            value: done,
            activeColor: context.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            onChanged: (_) => s.advanceItem(item),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: done ? context.inkSoft : context.ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '×${item.qty} · ${item.est.text} each · '
                  '${item.checkedOut ? AppLocalizations.of(context)!.loggedItem : itemStateLabel(AppLocalizations.of(context)!, item.state)} · by ${addedBy?.name ?? 'family'}',
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
              ],
            ),
          ),
          Text(
            (item.est.times(item.qty)).text,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: done ? context.inkSoft : context.ink,
            ),
          ),
          const SizedBox(width: 4),
          // Delete: tombstones everywhere — removed on this phone and on
          // every family device at the next sync.
          IconButton(
            tooltip: AppLocalizations.of(context)!.listDelete,
            icon: Icon(Icons.close, size: 18, color: context.inkSoft),
            padding: const EdgeInsets.all(8),
            constraints:
                const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: () {
              final s2 = AppScope.of(context);
              final messenger = ScaffoldMessenger.of(context);
              s2.deleteItem(item);
              messenger.showSnackBar(SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.listDeleted(item.name)),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ),
    );
  }
}
