import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/ids.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/l10n/app_strings.dart';

/// Full-screen, keyboard-safe transaction entry (UX-polish P1).
///
/// Layout contract:
///  · pinned header - 44px close + title, never scrolls away;
///  · essentials first - type → amount+currency → envelope → person;
///  · note & payment method behind "More details" (collapsed by default);
///  · Save is pinned above the keyboard (bottomNavigationBar + viewInsets);
///  · dismissing with entered data asks first - after save it never does.
Future<void> showQuickAdd(BuildContext context, {TxType? initialType}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _QuickAddSheet(initialType: initialType),
    ),
  );
}

class _QuickAddSheet extends StatefulWidget {
  final TxType? initialType;
  const _QuickAddSheet({this.initialType});

  @override
  State<_QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends State<_QuickAddSheet> {
  late TxType _type;
  Currency _cur = Currency.usd;
  Method _method = Method.cash;
  String? _envelopeId;
  String? _memberId;
  bool _more = false;
  bool _saved = false;
  bool _saving = false;
  String? _amountError;
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TxType.expense;
    // Post-frame so inherited widget is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final s = AppScope.of(context);
      setState(() {
        _cur = s.displayCurrency;
        _envelopeId = s.envelopes.isEmpty ? null : s.envelopes.first.id;
        _memberId = s.user.id;
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
    final envelope = s.envelope(_envelopeId);
    if (_type != TxType.expense || amount == null || envelope == null) {
      return null;
    }
    return Money.fromMajor(amount, _cur)
        .inCurrency(envelope.limit.currency, s.rate);
  }

  Future<void> _save(AppState s, AppLocalizations l) async {
    if (_saving) return;
    final amt = _parsedAmount;
    if (amt == null) {
      setState(() => _amountError = l.enterAmountFirst);
      return;
    }
    final member = _memberId == null
        ? null
        : s.member(_memberId!) ?? (_memberId == s.user.id ? s.user : null);
    if (member == null) {
      setState(() => _amountError = l.whoLabel);
      return;
    }

    final envelope = _type == TxType.expense ? s.envelope(_envelopeId) : null;
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
                    envelope.name,
                    Money(overMinor, envelope.limit.currency).text,
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

    setState(() => _saving = true);
    final note = _note.text.trim().isEmpty
        ? (_type == TxType.income ? l.income : l.expense)
        : _note.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final savedOffline = l.savedOffline;
    _saved = true;
    navigator.pop();
    s.addTx(
      id: newUuid(),
      type: _type,
      amount: Money.fromMajor(amt, _cur),
      memberId: member.id,
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

  Future<void> _pickBudget(AppState state) async {
    const noBudget = '__no_budget__';
    String query = '';
    final recentIds = <String>[];
    for (final tx in state.txs) {
      final id = tx.envelopeId;
      if (tx.type == TxType.expense &&
          id != null &&
          !recentIds.contains(id) &&
          state.envelope(id) != null) {
        recentIds.add(id);
        if (recentIds.length == 3) break;
      }
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.bg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final matches = state.envelopes.where((envelope) {
            final value = query.trim().toLowerCase();
            return value.isEmpty || envelope.name.toLowerCase().contains(value);
          }).toList();
          final recent = matches
              .where((envelope) => recentIds.contains(envelope.id))
              .toList()
            ..sort((a, b) =>
                recentIds.indexOf(a.id).compareTo(recentIds.indexOf(b.id)));
          final shared = matches
              .where((envelope) =>
                  !envelope.isPersonal && !recentIds.contains(envelope.id))
              .toList();
          final personal = matches
              .where((envelope) =>
                  envelope.isPersonal && !recentIds.contains(envelope.id))
              .toList();

          Widget heading(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.7,
                    fontWeight: FontWeight.w800,
                    color: sheetContext.inkSoft,
                  ),
                ),
              );

          Widget budgetTile(Envelope envelope) {
            final remaining = state.remainingOn(envelope);
            final hasLimit = state.effectiveLimit(envelope).minor > 0;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(iconForKey(envelope.emoji) ?? Icons.savings,
                  color: sheetContext.primaryDark),
              title: Text(envelope.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                hasLimit ? '${remaining.text} left' : 'No limit',
                style: TextStyle(color: sheetContext.inkSoft),
              ),
              trailing: _envelopeId == envelope.id
                  ? Icon(Icons.check_circle, color: sheetContext.primary)
                  : const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(sheetContext, envelope.id),
            );
          }

          return FractionallySizedBox(
            heightFactor: 0.82,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                12 + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Choose a budget',
                            style: Theme.of(sheetContext).textTheme.titleLarge),
                      ),
                      IconButton(
                        tooltip: MaterialLocalizations.of(sheetContext)
                            .closeButtonTooltip,
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    autofocus: state.envelopes.length > 8,
                    onChanged: (value) => setSheet(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Search budgets',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: sheetContext.card,
                      border:
                          const OutlineInputBorder(borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: const Icon(Icons.remove_circle_outline),
                          title: const Text('No budget'),
                          subtitle: const Text('Keep this expense unallocated'),
                          trailing: _envelopeId == null
                              ? Icon(Icons.check_circle,
                                  color: sheetContext.primary)
                              : null,
                          onTap: () => Navigator.pop(sheetContext, noBudget),
                        ),
                        if (recent.isNotEmpty) ...[
                          heading('RECENT'),
                          for (final envelope in recent) budgetTile(envelope),
                        ],
                        if (shared.isNotEmpty) ...[
                          heading('SHARED BUDGETS'),
                          for (final envelope in shared) budgetTile(envelope),
                        ],
                        if (personal.isNotEmpty) ...[
                          heading('PERSONAL BUDGETS'),
                          for (final envelope in personal) budgetTile(envelope),
                        ],
                        if (matches.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 28),
                            child: Text(
                              'No budgets match your search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: sheetContext.inkSoft),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (!mounted || selected == null) return;
    setState(() => _envelopeId = selected == noBudget ? null : selected);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final members = <Member>[
      s.user,
      ...s.members.where((member) => member.id != s.user.id),
    ];

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
              Text(
                'What are you adding?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _TransactionTypeButton(
                      label: l.expense,
                      icon: Icons.arrow_upward_rounded,
                      selected: _type == TxType.expense,
                      selectedBackground: context.dangerSoft,
                      selectedForeground: context.expenseRed,
                      onTap: () => setState(() => _type = TxType.expense),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TransactionTypeButton(
                      label: l.income,
                      icon: Icons.arrow_downward_rounded,
                      selected: _type == TxType.income,
                      selectedBackground: context.successSoft,
                      selectedForeground: context.incomeGreen,
                      onTap: () => setState(() => _type = TxType.income),
                    ),
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
                inputFormatters: amountInputFormatters,
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
                  labelText: _type == TxType.expense
                      ? 'Amount spent'
                      : 'Amount received',
                  errorText: _amountError,
                  errorStyle: TextStyle(
                    color: context.danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  hintText: '0.00',
                ),
                onChanged: (_) {
                  if (_amountError != null) {
                    setState(() => _amountError = null);
                  } else {
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final c in s.activeCurrencies) ...[
                    ChoiceChip(
                      label: Text(c.short),
                      selected: _cur == c,
                      onSelected: (_) => setState(() => _cur = c),
                    ),
                  ],
                  if (s.activeCurrencies.length > 1)
                    Text(
                      _parsedAmount == null
                          ? ''
                          : '≈ ${Money.fromMajor(_parsedAmount!, _cur).converted(s.rate, s.otherCurrency(_cur)).text}',
                      style: TextStyle(fontSize: 12.5, color: context.inkSoft),
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
                Text('Which budget is this from?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: context.inkSoft)),
                const SizedBox(height: 8),
                _BudgetSelector(
                  envelope: s.envelope(_envelopeId),
                  hasLimit: s.envelope(_envelopeId) != null &&
                      s.effectiveLimit(s.envelope(_envelopeId)!).minor > 0,
                  remaining: s.envelope(_envelopeId) == null
                      ? null
                      : s.remainingOn(s.envelope(_envelopeId)!),
                  onTap: () => _pickBudget(s),
                ),
                const SizedBox(height: 12),
                if (s.envelope(_envelopeId) case final envelope?)
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
                  for (final m in members)
                    ChoiceChip(
                      label: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(iconForKey(m.emoji) ?? Icons.person,
                            size: 16, color: context.primaryDark),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: (MediaQuery.sizeOf(context).width - 140)
                              .clamp(100, 260),
                          child: Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      selected: _memberId == m.id,
                      onSelected: (_) => setState(() => _memberId = m.id),
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
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
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
                onPressed: _saving ? null : () => _save(s, l),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        _type == TxType.expense ? 'Add expense' : 'Add income',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTypeButton extends StatelessWidget {
  const _TransactionTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedBackground,
    required this.selectedForeground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedBackground;
  final Color selectedForeground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedBackground : context.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? selectedForeground : context.hairline,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: 19,
                    color: selected ? selectedForeground : context.inkSoft),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: selected ? selectedForeground : context.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BudgetSelector extends StatelessWidget {
  const _BudgetSelector({
    required this.envelope,
    required this.hasLimit,
    required this.remaining,
    required this.onTap,
  });

  final Envelope? envelope;
  final bool hasLimit;
  final Money? remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = envelope;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.hairline),
          ),
          child: Row(
            children: [
              Icon(
                selected == null
                    ? Icons.account_balance_wallet_outlined
                    : iconForKey(selected.emoji) ?? Icons.savings,
                color: context.primaryDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      selected?.name ?? 'No budget',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: context.ink,
                      ),
                    ),
                    Text(
                      selected == null
                          ? 'Tap to choose or search budgets'
                          : hasLimit
                              ? '${remaining?.text ?? ''} left'
                              : 'No limit',
                      style: TextStyle(fontSize: 11.5, color: context.inkSoft),
                    ),
                  ],
                ),
              ),
              Icon(Icons.search, color: context.primary),
            ],
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
        ? l.envelopeWillExceed(envelope.name, amount)
        : entered == null
            ? l.envelopeRemaining(envelope.name, amount)
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
