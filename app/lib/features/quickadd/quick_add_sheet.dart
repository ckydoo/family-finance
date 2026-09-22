import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/app_strings.dart';

/// Full-screen, keyboard-safe transaction entry (UX-polish P1).
///
/// Layout contract:
///  · pinned header — 44px close + title, never scrolls away;
///  · essentials first — type → amount+currency → envelope → person;
///  · note & payment method behind "More details" (collapsed by default);
///  · Save is pinned above the keyboard (bottomNavigationBar + viewInsets);
///  · dismissing with entered data asks first — after save it never does.
Future<void> showQuickAdd(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const _QuickAddSheet(),
    ),
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
  bool _more = false;
  bool _saved = false;
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
        _envelope = s.envelopes.isEmpty ? null : s.envelopes.first;
        _member = s.members.isEmpty ? null : s.user;
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

  /// Guard only when the user actually typed something and did not save.
  bool get _dirty =>
      !_saved &&
      (_amount.text.trim().isNotEmpty || _note.text.trim().isNotEmpty);

  /// Returns true when the user chose to STAY.
  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context)!;
    final keep = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(l.discardTitle),
        content: Text(l.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text(l.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            style: TextButton.styleFrom(foregroundColor: context.danger),
            child: Text(l.discard),
          ),
        ],
      ),
    );
    return keep ?? true;
  }

  Future<void> _close() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_dirty) {
      Navigator.of(context).pop();
      return;
    }
    if (!await _confirmDiscard()) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Money? _enteredExpense(AppState s) {
    final amount = _parsedAmount;
    final envelope = _envelope;
    if (_type != TxType.expense || amount == null || envelope == null) {
      return null;
    }
    return Money.fromMajor(amount, _cur)
        .inCurrency(envelope.limit.currency, s.rate);
  }

  Future<void> _save(AppState s, AppLocalizations l) async {
    final amt = _parsedAmount;
    if (amt == null || _member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.enterAmountFirst),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final envelope = _type == TxType.expense ? _envelope : null;
    final entered = _enteredExpense(s);
    if (envelope != null && entered != null) {
      final remaining = s.remainingOn(envelope);
      final overMinor = entered.minor - remaining.minor;
      if (overMinor > 0) {
        FocusManager.instance.primaryFocus?.unfocus();
        final logAnyway = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                icon: Icon(Icons.warning_amber_rounded,
                    color: dialogContext.danger),
                title: Text(l.overBudgetTitle),
                content: Text(
                  l.overBudgetBody(
                    Money(overMinor, envelope.limit.currency).text,
                    envelope.name,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l.adjustAmount),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: dialogContext.danger,
                      foregroundColor: dialogContext.onSolid,
                    ),
                    child: Text(l.logAnyway),
                  ),
                ],
              ),
            ) ??
            false;
        if (!logAnyway || !mounted) return;
      }
    }

    final note = _note.text.trim().isEmpty
        ? (_type == TxType.income ? l.income : l.expense)
        : _note.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final savedOffline = l.savedOffline;
    _saved = true;
    navigator.pop();
    s.addTx(
      type: _type,
      amount: Money.fromMajor(amt, _cur),
      memberId: _member!.id,
      method: _method,
      note: note,
      envelopeId: envelope?.id,
    );
    HapticFeedback.mediumImpact();
    messenger.showSnackBar(
      SnackBar(
        content: Text(savedOffline),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!await _confirmDiscard() && navigator.mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: context.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip:
                        MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded),
                    color: context.inkSoft,
                    style: IconButton.styleFrom(
                      backgroundColor: context.card,
                      minimumSize: const Size.square(44),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.quickAddTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Expense / Income
              Row(
                children: [
                  ChoiceChip(
                    label: Text(l.expense),
                    selected: _type == TxType.expense,
                    onSelected: (_) => setState(() => _type = TxType.expense),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(l.income),
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
                  Flexible(
                    child: Text(
                      _parsedAmount == null
                          ? ''
                          : '≈ ${Money.fromMajor(_parsedAmount!, _cur).converted(s.rate).text}',
                      style: TextStyle(fontSize: 12.5, color: context.inkSoft),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Envelope (expenses only)
              if (_type == TxType.expense && s.envelopes.isEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.hairline),
                  ),
                  child: Text(l.noEnvelopesYet,
                      style: TextStyle(
                          fontSize: 12.5, color: context.inkSoft, height: 1.4)),
                ),
                const SizedBox(height: 12),
              ],
              if (_type == TxType.expense && s.envelopes.isNotEmpty) ...[
                Text(l.envelopeLabel,
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
                        label: Row(mainAxisSize: MainAxisSize.min, children: [
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
                if (_envelope case final envelope?)
                  _EnvelopeLimitNotice(
                    envelope: envelope,
                    remaining: s.remainingOn(envelope),
                    entered: _enteredExpense(s),
                  ),
                const SizedBox(height: 8),
              ],

              // Who
              Text(l.whoLabel,
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
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
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
              const SizedBox(height: 4),

              // ── More details ────────────────────────────────────────────
              TextButton.icon(
                onPressed: () => setState(() => _more = !_more),
                icon: Icon(_more
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded),
                label: Text(_more ? l.lessDetails : l.moreDetails),
                style: TextButton.styleFrom(foregroundColor: context.inkSoft),
              ),
              if (_more) ...[
                Text(l.paidWithLabel,
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
                        label: Text(methodLabel(l, m)),
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
                    labelText: l.noteHint,
                    filled: true,
                    fillColor: context.card,
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        // Save stays visible above the keyboard at all times.
        bottomNavigationBar: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: ElevatedButton(
                onPressed: () => _save(s, l),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(54),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  l.save,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvelopeLimitNotice extends StatelessWidget {
  const _EnvelopeLimitNotice({
    required this.envelope,
    required this.remaining,
    required this.entered,
  });

  final Envelope envelope;
  final Money remaining;
  final Money? entered;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final projected =
        entered == null ? remaining.minor : remaining.minor - entered!.minor;
    final isOver = projected < 0;
    final amount = Money(projected.abs(), remaining.currency).text;
    final text = isOver
        ? l.envelopeWillExceed(amount, envelope.name)
        : entered == null
            ? l.envelopeRemaining(amount, envelope.name)
            : l.envelopeWillLeave(amount, envelope.name);
    final color = isOver ? context.expenseRed : context.inkSoft;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isOver ? context.dangerSoft : context.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOver
                ? Icons.warning_amber_rounded
                : Icons.account_balance_wallet_outlined,
            size: 18,
            color: isOver ? context.expenseRed : context.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
