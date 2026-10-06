import 'package:flutter/material.dart';

import '../../core/utils/ids.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/ui.dart';

/// Shared shopping list connected to the budget (spec Module F, §7.6).
class ListsScreen extends StatefulWidget {
  final bool standalone;
  const ListsScreen({super.key, this.standalone = false});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  ItemState? _filter = ItemState.tobuy;
  bool _finishingShopping = false;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final visible = _filter == null
        ? s.items.toList()
        : s.items.where((i) => i.state == _filter).toList();

    final estPrimary = s.estFor(s.primaryCurrency);
    final estSecondary =
        s.secondaryCurrency != null ? s.estFor(s.secondaryCurrency!) : null;
    final groceries = s.envelope('e1');
    final budgetUse = groceries != null && groceries.limit.minor > 0
        ? estPrimary.minor /
            groceries.limit.inCurrency(s.primaryCurrency, s.rate).minor
        : 0.0;
    final hasUnloggedShopping = s.items.any(
      (i) =>
          !i.checkedOut &&
          (i.state == ItemState.done || i.state == ItemState.incart),
    );

    int count(ItemState st) => s.items.where((i) => i.state == st).length;

    final Widget content = SafeArea(
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => s.refresh(),
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(context)!.shopping,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
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
                            style:
                                TextStyle(fontSize: 13, color: context.inkSoft),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: Text(AppLocalizations.of(context)!
                                    .filterAll(s.items.length)),
                                selected: _filter == null,
                                onSelected: (_) =>
                                    setState(() => _filter = null),
                              ),
                              for (final st in ItemState.values)
                                ChoiceChip(
                                  label: Text(
                                      '${itemStateLabel(AppLocalizations.of(context)!, st)} (${count(st)})'),
                                  selected: _filter == st,
                                  onSelected: (_) =>
                                      setState(() => _filter = st),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (visible.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: context.card,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.shopping_cart_outlined,
                                      color: context.primary, size: 30),
                                  const SizedBox(height: 10),
                                  Text(
                                    s.items.isEmpty
                                        ? 'Your shopping list is empty'
                                        : 'Nothing in this view',
                                    style: TextStyle(
                                      color: context.ink,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    s.items.isEmpty
                                        ? 'Add things your family needs to buy and everyone can keep track together.'
                                        : 'Choose another filter to see your items.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: context.inkSoft,
                                        fontSize: 12,
                                        height: 1.4),
                                  ),
                                  if (s.items.isEmpty) ...[
                                    const SizedBox(height: 14),
                                    FilledButton.icon(
                                      onPressed: () => _addSheet(context),
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add first item'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (visible.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.separated(
                        itemCount: visible.length,
                        itemBuilder: (context, index) =>
                            _ItemRow(item: visible[index]),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    sliver: SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated total',
                              style: TextStyle(
                                  fontSize: 11.5, color: context.inkSoft),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                estPrimary.text,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            if (estSecondary != null)
                              Text(
                                '≈ ${estSecondary.text}',
                                style: TextStyle(
                                    fontSize: 12.5, color: context.inkSoft),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              s.rateLabel,
                              style: TextStyle(
                                  fontSize: 11, color: context.inkSoft),
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
                                style: TextStyle(
                                    fontSize: 12, color: context.inkSoft),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Finish shopping button ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: ElevatedButton.icon(
              onPressed: (hasUnloggedShopping && !_finishingShopping)
                  ? () async {
                      setState(() => _finishingShopping = true);
                      try {
                        final total = s.finishShopping(txId: newUuid());
                        if (mounted) {
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
                      } finally {
                        if (mounted) {
                          setState(() => _finishingShopping = false);
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                elevation: 4,
              ),
              icon: _finishingShopping
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.receipt_long),
              label: Text(
                hasUnloggedShopping
                    ? AppLocalizations.of(context)!.finishShop
                    : AppLocalizations.of(context)!.shoppingLogged,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.shopping),
        ),
        body: content,
      );
    }
    return content;
  }

  void _addSheet(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final qty = TextEditingController(text: '1');
    final price = TextEditingController();
    Currency cur = s.displayCurrency;
    String? itemError;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => MhuriSheetShell(
          title: AppLocalizations.of(context)!.addItem,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                onChanged: (_) {
                  if (itemError != null) setSheet(() => itemError = null);
                },
                decoration: InputDecoration(
                  labelText: l.listNameLabel,
                  filled: true,
                  fillColor: context.card,
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qty,
                      keyboardType: TextInputType.number,
                      inputFormatters: integerInputFormatters,
                      onChanged: (_) {
                        if (itemError != null) setSheet(() => itemError = null);
                      },
                      decoration: InputDecoration(
                        labelText: l.listQtyLabel,
                        filled: true,
                        fillColor: context.card,
                        border: const OutlineInputBorder(
                            borderSide: BorderSide.none),
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
                      inputFormatters: amountInputFormatters,
                      onChanged: (_) {
                        if (itemError != null) setSheet(() => itemError = null);
                      },
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)!.estPrice(cur.symbol),
                        filled: true,
                        fillColor: context.card,
                        border: const OutlineInputBorder(
                            borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                ],
              ),
              if (s.activeCurrencies.length > 1) ...[
                Row(
                  children: [
                    for (final c in s.activeCurrencies) ...[
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() {
                          cur = c;
                          if (itemError != null) itemError = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (itemError != null) ...[
                const SizedBox(height: 12),
                ErrorNotice(itemError!),
              ],
              const SizedBox(height: 16),
              PrimaryButton(
                label: AppLocalizations.of(context)!.addToList,
                onPressed: () {
                  final n = name.text.trim();
                  final q = int.tryParse(qty.text) ?? 1;
                  final p = double.tryParse(price.text.replaceAll(',', ''));
                  if (n.isEmpty) {
                    setSheet(() => itemError = l.listNameLabel);
                    return;
                  }
                  if (q <= 0) {
                    setSheet(() => itemError = l.listQtyLabel);
                    return;
                  }
                  if (p == null || p <= 0) {
                    setSheet(() => itemError =
                        AppLocalizations.of(context)!.enterAmountFirst);
                    return;
                  }
                  s.addItem(n, q, Money.fromMajor(p, cur));
                  Navigator.pop(sheetCtx);
                },
              ),
            ],
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.hairline)),
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
                  'Qty ${item.qty} · ${item.est.text} each\n'
                  'Added by ${addedBy?.name ?? 'family'}${item.checkedOut ? ' · Recorded' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5, color: context.inkSoft, height: 1.35),
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
          PopupMenuButton<String>(
            tooltip: 'Item actions',
            onSelected: (action) async {
              if (action == 'edit') {
                _editSheet(context, s);
                return;
              }
              final remove = await confirmDialog(
                context,
                title: 'Remove ${item.name}?',
                body: 'This removes the item from the shared shopping list.',
                confirmLabel: 'Remove item',
                danger: true,
              );
              if (!remove || !context.mounted) return;
              final messenger = ScaffoldMessenger.of(context);
              s.deleteItem(item);
              messenger.showSnackBar(SnackBar(
                content:
                    Text(AppLocalizations.of(context)!.listDeleted(item.name)),
                behavior: SnackBarBehavior.floating,
              ));
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit item')),
              PopupMenuItem(value: 'remove', child: Text('Remove item')),
            ],
          ),
        ],
      ),
    );
  }

  void _editSheet(BuildContext context, AppState state) {
    final name = TextEditingController(text: item.name);
    final qty = TextEditingController(text: '${item.qty}');
    final price =
        TextEditingController(text: (item.est.minor / 100).toStringAsFixed(2));
    String? error;
    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => MhuriSheetShell(
          title: 'Edit item',
          footer: PrimaryButton(
            label: 'Save changes',
            onPressed: () {
              final q = int.tryParse(qty.text);
              final p = double.tryParse(price.text.replaceAll(',', ''));
              if (name.text.trim().isEmpty ||
                  q == null ||
                  q < 1 ||
                  p == null ||
                  p < 0) {
                setSheet(() => error =
                    'Enter a name, quantity and valid estimated price.');
                return;
              }
              state.updateItem(item,
                  name: name.text,
                  qty: q,
                  estimate: Money.fromMajor(p, item.est.currency));
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(sheetContext);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Shopping item updated'),
                  behavior: SnackBarBehavior.floating));
            },
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Item')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: qty,
                        keyboardType: TextInputType.number,
                        inputFormatters: integerInputFormatters,
                        decoration:
                            const InputDecoration(labelText: 'Quantity'))),
                const SizedBox(width: 12),
                Expanded(
                    child: TextField(
                        controller: price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: amountInputFormatters,
                        decoration: InputDecoration(
                            labelText:
                                'Estimated price (${item.est.currency.symbol})'))),
              ]),
              if (error != null) ErrorNotice(error!),
            ],
          ),
        ),
      ),
    );
  }
}
