import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/app_strings.dart';

/// 3-tap quick entry (spec C1, §7.7): amount → envelope → member → ✓.
Future<void> showQuickAdd(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QuickAddSheet(),
  );
}

class _QuickAddSheet extends StatefulWidget {
  const _QuickAddSheet();

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  TxType _type = TxType.expense;
  Currency _cur = Currency.usd;
  Method _method = Method.cash;
  Envelope? _envelope;
  Member? _member;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Post-frame so inherited widget is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.of(context);
      setState(() {
        _envelope = s.envelopes.first;
        _member = s.user;
      });
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _parsedAmount {
    final v = double.tryParse(_amount.text.replaceAll(',', ''));
    return (v == null || v <= 0) ? null : v;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return SingleChildScrollView(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.quickAddTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.ink,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.close_rounded),
                  color: context.inkSoft,
                  style: IconButton.styleFrom(
                    backgroundColor: context.card,
                    minimumSize: const Size.square(44),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Expense / Income
            Row(
              children: [
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.expense),
                  selected: _type == TxType.expense,
                  onSelected: (_) => setState(() => _type = TxType.expense),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(AppLocalizations.of(context)!.income),
                  selected: _type == TxType.income,
                  onSelected: (_) => setState(() => _type = TxType.income),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Amount + currency
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: context.ink),
              decoration: InputDecoration(
                prefixText: '${_cur.symbol} ',
                prefixStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.inkSoft),
                filled: true,
                fillColor: context.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
                hintText: '0.00',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('USD'),
                  selected: _cur == Currency.usd,
                  onSelected: (_) => setState(() => _cur = Currency.usd),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('ZiG'),
                  selected: _cur == Currency.zwg,
                  onSelected: (_) => setState(() => _cur = Currency.zwg),
                ),
                const Spacer(),
                Text(
                  _parsedAmount == null
                      ? ''
                      : '≈ ${Money.fromMajor(_parsedAmount!, _cur).converted(s.rate).text}',
                  style: TextStyle(fontSize: 12.5, color: context.inkSoft),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Envelope (expenses only)
            if (_type == TxType.expense) ...[
              Text(AppLocalizations.of(context)!.envelopeLabel,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: context.inkSoft)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in s.envelopes.where((e) => !e.isPersonal))
                    ChoiceChip(
                      label: Row(children: [
                        Icon(iconForKey(e.emoji) ?? Icons.savings,
                            size: 16, color: context.primaryDark),
                        const SizedBox(width: 8),
                        Text(e.name),
                      ]),
                      selected: _envelope?.id == e.id,
                      onSelected: (_) => setState(() => _envelope = e),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Who
            Text(AppLocalizations.of(context)!.whoLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.inkSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in s.members)
                  ChoiceChip(
                    label: Row(children: [
                      Icon(iconForKey(m.emoji) ?? Icons.person,
                          size: 16, color: context.primaryDark),
                      const SizedBox(width: 8),
                      Text(m.name),
                    ]),
                    selected: _member?.id == m.id,
                    onSelected: (_) => setState(() => _member = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Method
            Text(AppLocalizations.of(context)!.paidWithLabel,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.inkSoft)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in Method.values.take(5))
                  ChoiceChip(
                    label: Text(methodLabel(AppLocalizations.of(context)!, m)),
                    selected: _method == m,
                    onSelected: (_) => setState(() => _method = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _note,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.noteHint,
                filled: true,
                fillColor: context.card,
                border: OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: () {
                final amt = _parsedAmount;
                if (amt == null || _member == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(AppLocalizations.of(context)!.enterAmountFirst),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final note = _note.text.trim().isEmpty
                    ? (_type == TxType.income
                        ? AppLocalizations.of(context)!.income
                        : AppLocalizations.of(context)!.expense)
                    : _note.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final savedOffline = AppLocalizations.of(context)!.savedOffline;
                final navigator = Navigator.of(context);
                navigator.pop();
                s.addTx(
                  type: _type,
                  amount: Money.fromMajor(amt, _cur),
                  memberId: _member!.id,
                  method: _method,
                  note: note,
                  envelopeId: _type == TxType.expense ? _envelope?.id : null,
                );
                HapticFeedback.mediumImpact();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(savedOffline),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
                minimumSize: const Size.fromHeight(54),
                shape: const StadiumBorder(),
              ),
              child: Text(
                AppLocalizations.of(context)!.save,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
