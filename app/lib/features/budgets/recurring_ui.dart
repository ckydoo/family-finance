import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/widgets/ui.dart';

/// One recurring rule row (C7). Due rules show a highlighted "Post" action;
/// the review happens before anything is recorded.
class RecurringRow extends StatelessWidget {
  const RecurringRow({super.key, required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final env = s.envelope(rule.envelopeId);
    final dueSoon = rule.isDueWithin(const Duration(days: 3));
    final dueText = _dueText(context, rule);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: dueSoon && rule.active
            ? context.accentSoft
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              iconForKey(rule.emoji) ?? Icons.autorenew,
              size: 19,
              color: context.primaryDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: rule.active ? context.ink : context.inkSoft,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${rule.amount.text} · ${freqLabel(AppLocalizations.of(context)!, rule.frequency)}'
                  '${env != null ? ' · ${env.name}' : ''}'
                  ' · $dueText',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: dueSoon ? context.expenseRed : context.inkSoft,
                    fontWeight: dueSoon ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (dueSoon && rule.active) ...[
            ElevatedButton(
              onPressed: () {
                s.postRecurring(rule);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${rule.name} posted ✓'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accent,
                foregroundColor: context.onSolid,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
              ),
              child: Text(
                AppLocalizations.of(context)!.post,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.skipPeriod,
              onPressed: () {
                s.skipRecurring(rule);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!
                          .recSkipped(_dueText(context, rule)),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(Icons.skip_next, size: 20, color: context.inkSoft),
            ),
          ] else
            IconButton(
              tooltip: rule.active
                  ? AppLocalizations.of(context)!.pauseRule
                  : AppLocalizations.of(context)!.resumeRule,
              onPressed: () => s.toggleRecurring(rule),
              icon: Icon(
                rule.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: context.inkSoft,
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Regular payment actions',
            onSelected: (action) async {
              if (action == 'edit') {
                _showEditRecurringSheet(context, s, rule);
                return;
              }
              final ok = await confirmDialog(
                context,
                title: 'Archive ${rule.name}?',
                body:
                    'The regular payment will stop appearing here. Transactions already posted from it remain in your history.',
                confirmLabel: 'Archive payment',
                danger: true,
              );
              if (ok && context.mounted) {
                s.archiveRecurring(rule);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Regular payment archived'),
                    behavior: SnackBarBehavior.floating));
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit payment')),
              if (s.canAdmin)
                const PopupMenuItem(
                    value: 'archive', child: Text('Archive payment')),
            ],
          ),
        ],
      ),
    );
  }

  String _dueText(BuildContext context, RecurringRule r) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(r.nextDue.year, r.nextDue.month, r.nextDue.day);
    final days = due.difference(today).inDays;
    if (days < 0) return AppLocalizations.of(context)!.dueBy(-days);
    if (days == 0) return AppLocalizations.of(context)!.dueToday;
    if (days == 1) return AppLocalizations.of(context)!.dueTomorrow;
    return AppLocalizations.of(context)!.dueIn(days);
  }
}

void _showEditRecurringSheet(
    BuildContext context, AppState state, RecurringRule rule) {
  final name = TextEditingController(text: rule.name);
  final amount =
      TextEditingController(text: (rule.amount.minor / 100).toStringAsFixed(2));
  var frequency = rule.frequency;
  String? error;
  showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheet) => MhuriSheetShell(
        title: 'Edit regular payment',
        footer: PrimaryButton(
          label: 'Save changes',
          onPressed: () {
            final parsed = double.tryParse(amount.text.replaceAll(',', ''));
            if (name.text.trim().isEmpty || parsed == null || parsed <= 0) {
              setSheet(() => error = 'Enter a name and valid amount.');
              return;
            }
            state.updateRecurring(
              rule,
              name: name.text,
              amount: Money.fromMajor(parsed, rule.amount.currency),
              frequency: frequency,
              nextDue: rule.nextDue,
              envelopeId: rule.envelopeId,
              memberId: rule.memberId,
              method: rule.method,
            );
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(sheetContext);
            messenger.showSnackBar(const SnackBar(
                content: Text('Regular payment updated'),
                behavior: SnackBarBehavior.floating));
          },
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 12),
          TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountInputFormatters,
              decoration: InputDecoration(
                  labelText: 'Amount (${rule.amount.currency.symbol})')),
          const SizedBox(height: 12),
          DropdownButtonFormField<Frequency>(
              initialValue: frequency,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: [
                for (final value in Frequency.values)
                  DropdownMenuItem(value: value, child: Text(value.label))
              ],
              onChanged: (value) {
                if (value != null) setSheet(() => frequency = value);
              }),
          if (error != null) ErrorNotice(error!),
        ]),
      ),
    ),
  );
}

/// Add-recurring bottom sheet (C7).
Future<void> showAddRecurringSheet(BuildContext context) {
  final s = AppScope.of(context);
  final name = TextEditingController();
  final amount = TextEditingController();
  Currency cur = s.displayCurrency;
  Frequency freq = Frequency.monthly;
  String? envelopeId = s.envelopes.isEmpty ? null : s.envelopes.first.id;
  String memberId = s.user.id;
  Method method = Method.bankTransfer;
  DateTime nextDue = DateTime.now().add(const Duration(days: 7));
  String? recError;

  return showMhuriSheet<void>(
    context: context,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => MhuriSheetShell(
        title: AppLocalizations.of(context)!.recNew,
        subtitle: AppLocalizations.of(context)!.recReview,
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recError != null) ...[
              ErrorNotice(recError!),
              const SizedBox(height: 10),
            ],
            PrimaryButton(
              label: AppLocalizations.of(context)!.recSaveRule,
              onPressed: () {
                final n = name.text.trim();
                final v = double.tryParse(amount.text.replaceAll(',', ''));
                if (n.isEmpty) {
                  setSheet(() =>
                      recError = AppLocalizations.of(context)!.recNameHint);
                  return;
                }
                if (v == null || v <= 0) {
                  setSheet(() => recError =
                      AppLocalizations.of(context)!.enterAmountFirst);
                  return;
                }
                s.addRecurring(
                  name: n,
                  emoji: 'autorenew',
                  amount: Money.fromMajor(v, cur),
                  memberId: memberId,
                  method: method,
                  frequency: freq,
                  nextDue: nextDue,
                  envelopeId: envelopeId,
                );
                Navigator.pop(sheetCtx);
              },
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 14),
            TextField(
              controller: name,
              autofocus: true,
              onChanged: (_) {
                if (recError != null) setSheet(() => recError = null);
              },
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.recNameHint,
                filled: true,
                fillColor: context.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountInputFormatters,
              onChanged: (_) {
                if (recError != null) setSheet(() => recError = null);
              },
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
              decoration: InputDecoration(
                prefixText: '${cur.symbol} ',
                filled: true,
                fillColor: context.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.activeCurrencies.length > 1)
                  for (final c in s.activeCurrencies)
                    ChoiceChip(
                      label: Text(c.short),
                      selected: cur == c,
                      onSelected: (_) => setSheet(() => cur = c),
                    ),
                for (final f in Frequency.values)
                  ChoiceChip(
                    label: Text(freqLabel(AppLocalizations.of(context)!, f)),
                    selected: freq == f,
                    onSelected: (_) => setSheet(() => freq = f),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: s.envelopes.any((e) => e.id == envelopeId)
                  ? envelopeId
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.envelopeLabel,
                filled: true,
                fillColor: context.card,
                border: const OutlineInputBorder(borderSide: BorderSide.none),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(AppLocalizations.of(context)!.recNoEnvelope),
                ),
                for (final e in s.envelopes)
                  DropdownMenuItem<String?>(
                      value: e.id,
                      child: Row(children: [
                        Icon(iconForKey(e.emoji) ?? Icons.savings,
                            size: 16, color: context.primaryDark),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(e.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ])),
              ],
              onChanged: (v) => setSheet(() => envelopeId = v),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final members = <Member>[
                  s.user,
                  ...s.members.where((m) => m.id != s.user.id),
                ];
                Widget memberField() => DropdownButtonFormField<String>(
                      initialValue: members.any((m) => m.id == memberId)
                          ? memberId
                          : s.user.id,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.whoLabel,
                        filled: true,
                        fillColor: context.card,
                        border: const OutlineInputBorder(
                            borderSide: BorderSide.none),
                      ),
                      items: [
                        for (final m in members)
                          DropdownMenuItem<String>(
                              value: m.id,
                              child: Row(children: [
                                Icon(iconForKey(m.emoji) ?? Icons.person,
                                    size: 16, color: context.primaryDark),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ])),
                      ],
                      onChanged: (v) =>
                          setSheet(() => memberId = v ?? s.user.id),
                    );

                Widget methodField() => DropdownButtonFormField<Method>(
                      initialValue: method,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.paidWithLabel,
                        filled: true,
                        fillColor: context.card,
                        border: const OutlineInputBorder(
                            borderSide: BorderSide.none),
                      ),
                      items: [
                        for (final m in Method.values.take(5))
                          DropdownMenuItem(
                            value: m,
                            child: Text(
                              methodLabel(AppLocalizations.of(context)!, m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setSheet(() => method = v ?? Method.bankTransfer),
                    );

                final textScale = MediaQuery.textScalerOf(context).scale(1);
                if (constraints.maxWidth < 520 || textScale > 1.15) {
                  return Column(
                    children: [
                      memberField(),
                      const SizedBox(height: 12),
                      methodField(),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: memberField()),
                    const SizedBox(width: 10),
                    Expanded(child: methodField()),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  AppLocalizations.of(context)!.recNextDue,
                  style: TextStyle(fontSize: 13, color: context.inkSoft),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: sheetCtx,
                      initialDate: nextDue,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setSheet(() => nextDue = picked);
                  },
                  icon: Icon(Icons.calendar_month,
                      size: 18, color: context.primary),
                  label: Text(
                    '${nextDue.day}/${nextDue.month}/${nextDue.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
