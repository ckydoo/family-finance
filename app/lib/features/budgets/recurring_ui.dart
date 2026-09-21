import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/app_strings.dart';

/// One recurring rule row (C7). Due rules show a highlighted "Post" action;
/// the review happens before anything is recorded.
class RecurringRow extends StatelessWidget {
  const RecurringRow({super.key, required this.rule});

  final RecurringRule rule;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final env = s.envelope(rule.envelopeId);
    final dueSoon =
        rule.isDueWithin(const Duration(days: 3));
    final dueText = _dueText(context, rule);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rule.active ? context.card : context.track,
        borderRadius: BorderRadius.circular(18),
        border: dueSoon ? Border.all(color: context.accent, width: 1.5) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFEDF4F1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
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
                shape: const StadiumBorder(),
              ),
              child: Text(
                AppLocalizations.of(context)!.post,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              tooltip: AppLocalizations.of(context)!.skipPeriod,
              onPressed: () {
                s.skipRecurring(rule);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context)!.recSkipped(_dueText(context, rule)),
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: Icon(Icons.skip_next, size: 20, color: context.inkSoft),
            ),
          ] else
            IconButton(
              tooltip: rule.active ? AppLocalizations.of(context)!.pauseRule : AppLocalizations.of(context)!.resumeRule,
              onPressed: () => s.toggleRecurring(rule),
              icon: Icon(
                rule.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                color: context.inkSoft,
              ),
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

/// Add-recurring bottom sheet (C7).
Future<void> showAddRecurringSheet(BuildContext context) {
  final s = AppScope.of(context);
  final name = TextEditingController();
  final amount = TextEditingController();
  Currency cur = Currency.usd;
  Frequency freq = Frequency.monthly;
  Envelope? envelope = s.envelopes.isEmpty ? null : s.envelopes.first;
  Member member = s.user;
  Method method = Method.bankTransfer;
  DateTime nextDue = DateTime.now().add(const Duration(days: 7));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) => SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
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
                AppLocalizations.of(context)!.recNew,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.recReview,
                style: TextStyle(fontSize: 11.5, color: context.inkSoft),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.recNameHint,
                  filled: true,
                  fillColor: context.card,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
                  ChoiceChip(
                    label: const Text('USD'),
                    selected: cur == Currency.usd,
                    onSelected: (_) => setSheet(() => cur = Currency.usd),
                  ),
                  ChoiceChip(
                    label: const Text('ZiG'),
                    selected: cur == Currency.zwg,
                    onSelected: (_) => setSheet(() => cur = Currency.zwg),
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
              DropdownButtonFormField<Envelope>(
                initialValue: envelope,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.envelopeLabel,
                  filled: true,
                  fillColor: context.card,
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(AppLocalizations.of(context)!.recNoEnvelope),
                  ),
                  for (final e in s.envelopes)
                    DropdownMenuItem(
                        value: e,
                            child: Row(children: [
                              Icon(iconForKey(e.emoji) ?? Icons.savings,
                                  size: 16, color: context.primaryDark),
                              const SizedBox(width: 8),
                              Text(e.name),
                            ])),
                ],
                onChanged: (v) => setSheet(() => envelope = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<Member>(
                      initialValue: member,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.whoLabel,
                        filled: true,
                        fillColor: context.card,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      items: [
                        for (final m in s.members)
                          DropdownMenuItem(
                              value: m,
                            child: Row(children: [
                              Icon(iconForKey(m.emoji) ?? Icons.person,
                                  size: 16, color: context.primaryDark),
                              const SizedBox(width: 8),
                              Text(m.name),
                            ])),
                      ],
                      onChanged: (v) => setSheet(() => member = v ?? s.user),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<Method>(
                      initialValue: method,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.paidWithLabel,
                        filled: true,
                        fillColor: context.card,
                        border:
                            OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                      items: [
                        for (final m in Method.values.take(5))
                          DropdownMenuItem(
                              value: m, child: Text(methodLabel(AppLocalizations.of(context)!, m))),
                      ],
                      onChanged: (v) =>
                          setSheet(() => method = v ?? Method.bankTransfer),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    AppLocalizations.of(context)!.recNextDue,
                    style: TextStyle(fontSize: 13, color: context.inkSoft),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: sheetCtx,
                        initialDate: nextDue,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 365)),
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  final n = name.text.trim();
                  final v = double.tryParse(amount.text.replaceAll(',', ''));
                  if (n.isEmpty || v == null || v <= 0) {
                    ScaffoldMessenger.of(sheetCtx).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.recNameAmount),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  s.addRecurring(
                    name: n,
                    emoji: 'autorenew',
                    amount: Money.fromMajor(v, cur),
                    memberId: member.id,
                    method: method,
                    frequency: freq,
                    nextDue: nextDue,
                    envelopeId: envelope?.id,
                  );
                  Navigator.pop(sheetCtx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(50),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  AppLocalizations.of(context)!.recSaveRule,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
