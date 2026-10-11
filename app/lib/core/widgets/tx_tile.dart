import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/models.dart';
import '../money/money.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/when.dart';
import 'app_icons.dart';
import 'ui.dart';

/// One transaction row - used on Home (recent) and Activity (full feed).
class TxTile extends StatelessWidget {
  final Tx tx;
  final bool dense;
  final bool surface;

  const TxTile({
    super.key,
    required this.tx,
    this.dense = false,
    this.surface = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final env = s.envelope(tx.envelopeId);
    final icon = tx.type == TxType.income
        ? Icons.savings
        : iconForKey(env?.emoji) ?? Icons.receipt_long;
    final member = s.member(tx.memberId);
    final isIn = tx.type == TxType.income;

    final splits = s.txAllocations.where((a) => a.txId == tx.id).toList();
    final budgetLabel = splits.isNotEmpty
        ? 'Split (${splits.length})'
        : (env?.name ?? (isIn ? null : 'Unbudgeted'));
    final methodLabel = tx.method.label;

    final canManage = tx.memberId == s.realUser.id || s.canAdmin;
    return Material(
      color: surface ? context.card : Colors.transparent,
      borderRadius: surface ? kBRadiusL : null,
      child: InkWell(
        onTap: () => _showTransaction(context, s, canManage: canManage),
        borderRadius: surface ? kBRadiusL : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: surface ? 14 : 0,
            vertical: dense ? 10 : 13,
          ),
          decoration: BoxDecoration(
            border: surface
                ? null
                : Border(bottom: BorderSide(color: context.hairline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: Icon(icon, size: 21, color: context.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.note.isEmpty ? (env?.name ?? (isIn ? 'Income' : 'Expense')) : tx.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: context.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            [
                              if (member?.name != null && member!.name.isNotEmpty) member.name,
                              fmtWhen(tx.when),
                              methodLabel,
                              if (budgetLabel != null) budgetLabel,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${isIn ? '+' : '-'}${tx.amount.text}',
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isIn ? context.incomeGreen : context.expenseRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransaction(BuildContext context, AppState state, {bool canManage = true}) {
    final note = TextEditingController(text: tx.note);
    final amount =
        TextEditingController(text: (tx.amount.minor / 100).toStringAsFixed(2));
    var method = tx.method;
    var envelopeId = tx.envelopeId;
    String? error;
    var editing = false;
    final splits = state.txAllocations.where((a) => a.txId == tx.id).toList();
    final member = state.member(tx.memberId);
    final env = state.envelope(tx.envelopeId);
    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => MhuriSheetShell(
          title: 'Transaction details',
          subtitle: 'Added by ${member?.name ?? 'family'}',
          footer: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: editing
                      ? () => setSheet(() {
                            editing = false;
                            error = null;
                            note.text = tx.note;
                            amount.text =
                                (tx.amount.minor / 100).toStringAsFixed(2);
                            method = tx.method;
                            envelopeId = tx.envelopeId;
                          })
                      : () => Navigator.pop(sheetContext),
                  child: Text(editing ? 'Cancel' : 'Close'),
                ),
              ),
              if (canManage) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: editing
                        ? () {
                            final parsed =
                                double.tryParse(amount.text.replaceAll(',', ''));
                            if (note.text.trim().isEmpty ||
                                parsed == null ||
                                parsed <= 0) {
                              setSheet(() => error =
                                  'Enter a description and valid amount.');
                              return;
                            }
                            state.updateTx(
                              tx,
                              amount: Money.fromMajor(parsed, tx.amount.currency),
                              method: method,
                              note: note.text,
                              when: tx.when,
                              envelopeId:
                                  tx.type == TxType.expense ? envelopeId : null,
                            );
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(sheetContext);
                            messenger.showSnackBar(const SnackBar(
                                content: Text('Transaction updated'),
                                behavior: SnackBarBehavior.floating));
                          }
                        : () => setSheet(() => editing = true),
                    child: Text(editing ? 'Save changes' : 'Edit transaction'),
                  ),
                ),
              ],
            ],
          ),
          child: editing
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: note,
                      autofocus: true,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: amountInputFormatters,
                      decoration: InputDecoration(
                          labelText: 'Amount (${tx.amount.currency.symbol})')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Method>(
                    initialValue: method,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Paid with'),
                    items: [
                      for (final value in Method.values)
                        DropdownMenuItem(value: value, child: Text(value.label))
                    ],
                    onChanged: (value) {
                      if (value != null) setSheet(() => method = value);
                    },
                  ),
                  if (tx.type == TxType.expense) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: envelopeId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Budget'),
                      items: [
                        const DropdownMenuItem<String?>(
                            value: null, child: Text('No budget')),
                        for (final budget in state.envelopes)
                          DropdownMenuItem<String?>(
                              value: budget.id,
                              child: Text(budget.name,
                                  overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (value) => setSheet(() => envelopeId = value),
                    ),
                  ],
                  if (error != null) ErrorNotice(error!),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final remove = await confirmDialog(
                        sheetContext,
                        title: 'Remove this transaction?',
                        body:
                            'The correction will update budgets and monthly totals. Its server history remains attributable.',
                        confirmLabel: 'Remove transaction',
                        danger: true,
                      );
                      if (!remove || !sheetContext.mounted) return;
                      state.deleteTx(tx);
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(sheetContext);
                      messenger.showSnackBar(const SnackBar(
                          content: Text('Transaction removed'),
                          behavior: SnackBarBehavior.floating));
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Remove transaction'),
                    style: TextButton.styleFrom(
                      foregroundColor: sheetContext.expenseRed,
                    ),
                  ),
                ])
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _detailRow(
                      sheetContext,
                      'Description',
                      tx.note.isEmpty
                          ? (env?.name ?? (tx.type == TxType.income ? 'Income' : 'Expense'))
                          : tx.note,
                    ),
                    _detailRow(sheetContext, 'Amount', tx.amount.text),
                    if (tx.amount.currency != state.displayCurrency)
                      _detailRow(
                        sheetContext,
                        'Display equivalent',
                        tx.amount.inCurrency(state.displayCurrency, state.rate).text,
                      ),
                    _detailRow(sheetContext, 'Type',
                        tx.type == TxType.income ? 'Income' : 'Expense'),
                    _detailRow(sheetContext, 'Payment method', tx.method.label),
                    _detailRow(
                      sheetContext,
                      'Logged by',
                      member?.name ?? 'Family member',
                    ),
                    if (tx.type == TxType.expense)
                      _detailRow(
                        sheetContext,
                        'Budget',
                        splits.isEmpty
                            ? env?.name ?? 'Unbudgeted'
                            : splits
                                .map((a) =>
                                    '${state.envelope(a.envelopeId)?.name ?? 'Budget'} ${a.amount.text}')
                                .join(' · '),
                      ),
                    if (tx.receiptUri != null)
                      _detailRow(sheetContext, 'Receipt', 'Attached'),
                    _detailRow(
                      sheetContext,
                      'Date & time',
                      DateFormat.yMMMd().add_jm().format(tx.when.toLocal()),
                      showDivider: false,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {bool showDivider = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: context.hairline))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: context.inkSoft)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
