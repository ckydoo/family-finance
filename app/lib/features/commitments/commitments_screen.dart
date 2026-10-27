import 'package:flutter/material.dart';

import '../../core/money/money.dart';
import '../../core/planning/commitments.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/plus_ui.dart';
import '../settings/plus_screen.dart';

class CommitmentsScreen extends StatefulWidget {
  const CommitmentsScreen({super.key});

  @override
  State<CommitmentsScreen> createState() => _CommitmentsScreenState();
}

class _CommitmentsScreenState extends State<CommitmentsScreen> {
  String _filter = 'upcoming';

  bool _isUnlocked(AppState state) =>
      state.hasPlusFeature('smart_commitments') ||
      state.hasPlusFeature('cash_flow_forecast');

  void _extendHorizon(AppState state) {
    final horizon = state.now.add(const Duration(days: 60));
    final count = state.generateCommitmentOccurrences(through: horizon);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 0
              ? 'Generated $count upcoming occurrence${count == 1 ? '' : 's'}.'
              : 'Schedule is already up to date for the next 60 days.',
        ),
      ),
    );
  }

  Future<void> _showAddCommitmentSheet(AppState state) async {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    var currency = state.primaryCurrency;
    var recurrence = CommitmentRecurrence.monthly;
    var firstDue = DateTime(state.now.year, state.now.month, state.now.day)
        .add(const Duration(days: 7));
    DateTime? endDate;
    String? envelopeId;
    final selectedReminders = <int>{1, 3};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Smart Commitment',
                    style: TextStyle(
                      color: sheetContext.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Schedules future obligations and reminders without recording an expense until paid.',
                    style: TextStyle(color: sheetContext.inkSoft, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('commitment_name_input'),
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Commitment name (e.g. School fees, Rent)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('commitment_amount_input'),
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<Currency>(
                        value: currency,
                        onChanged: (next) {
                          if (next != null) {
                            setSheetState(() => currency = next);
                          }
                        },
                        items: [
                          for (final c in state.activeCurrencies)
                            DropdownMenuItem(value: c, child: Text(c.code)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<CommitmentRecurrence>(
                    initialValue: recurrence,
                    decoration: const InputDecoration(labelText: 'Schedule'),
                    items: [
                      for (final r in CommitmentRecurrence.values)
                        DropdownMenuItem(
                          value: r,
                          child: Text(_recurrenceLabel(r)),
                        ),
                    ],
                    onChanged: (next) {
                      if (next != null) {
                        setSheetState(() => recurrence = next);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  if (state.envelopes.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      initialValue: envelopeId,
                      decoration: const InputDecoration(
                        labelText: 'Budget category (optional)',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('No category linked'),
                        ),
                        for (final env in state.envelopes)
                          DropdownMenuItem<String?>(
                            value: env.id,
                            child: Text(env.name),
                          ),
                      ],
                      onChanged: (next) =>
                          setSheetState(() => envelopeId = next),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: sheetContext,
                              initialDate: firstDue,
                              firstDate: DateTime(state.now.year - 1),
                              lastDate: DateTime(state.now.year + 5),
                            );
                            if (picked != null) {
                              setSheetState(() => firstDue = picked);
                            }
                          },
                          icon: const Icon(Icons.event, size: 18),
                          label: Text('First due: ${_dateText(firstDue)}'),
                        ),
                      ),
                      if (recurrence != CommitmentRecurrence.oneTime) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: sheetContext,
                                initialDate: endDate ??
                                    firstDue.add(const Duration(days: 180)),
                                firstDate: firstDue,
                                lastDate: DateTime(state.now.year + 10),
                              );
                              if (picked != null) {
                                setSheetState(() => endDate = picked);
                              }
                            },
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: Text(
                              endDate == null
                                  ? 'No end date'
                                  : 'Ends: ${_dateText(endDate!)}',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reminders before due date',
                    style: TextStyle(
                      color: sheetContext.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final day in const [0, 1, 3, 7])
                        FilterChip(
                          label:
                              Text(day == 0 ? 'On due date' : '${day}d before'),
                          selected: selectedReminders.contains(day),
                          onSelected: (selected) {
                            setSheetState(() {
                              if (selected) {
                                selectedReminders.add(day);
                              } else {
                                selectedReminders.remove(day);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('save_commitment_button'),
                      onPressed: () {
                        final parsed =
                            double.tryParse(amountController.text.trim());
                        if (nameController.text.trim().isEmpty ||
                            parsed == null ||
                            parsed <= 0) {
                          return;
                        }
                        final minor = (parsed * 100).round();
                        final commitment = FinancialCommitment(
                          id: newUuid(),
                          name: nameController.text.trim(),
                          amount: Money(minor, currency),
                          firstDueDate: firstDue,
                          recurrence: recurrence,
                          createdById: state.realUser.id,
                          envelopeId: envelopeId,
                          endDate: recurrence == CommitmentRecurrence.oneTime
                              ? null
                              : endDate,
                          reminderDaysBefore: (selectedReminders.toList()
                            ..sort()),
                        );
                        final ok = state.addFinancialCommitment(commitment);
                        if (ok) {
                          state.generateCommitmentOccurrences(
                            through: firstDue.add(const Duration(days: 60)),
                          );
                          Navigator.pop(sheetContext);
                        }
                      },
                      child: const Text('Save Commitment'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showLinkPaymentSheet(
    AppState state,
    CommitmentOccurrence occurrence,
    FinancialCommitment? commitment,
  ) async {
    final outstanding = state.commitmentOutstanding(occurrence);
    final eligibleTxs = state.familyTransactions.where((tx) {
      if (tx.deletedAt != null ||
          tx.type.name != 'expense' ||
          tx.amount.currency != occurrence.amount.currency) {
        return false;
      }
      return state.transactionUnallocatedForCommitments(tx).minor > 0;
    }).toList(growable: false);

    String? selectedTxId = eligibleTxs.isNotEmpty ? eligibleTxs.first.id : null;
    final initialMinor = eligibleTxs.isNotEmpty
        ? (state.transactionUnallocatedForCommitments(eligibleTxs.first).minor <
                outstanding.minor
            ? state
                .transactionUnallocatedForCommitments(eligibleTxs.first)
                .minor
            : outstanding.minor)
        : outstanding.minor;
    final amountController = TextEditingController(
      text: (initialMinor / 100).toStringAsFixed(2),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Link Expense Payment · ${commitment?.name ?? occurrence.occurrenceKey}',
                  style: TextStyle(
                    color: sheetContext.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Outstanding: ${outstanding.text} (Due ${_dateText(occurrence.dueDate)})',
                  style: TextStyle(color: sheetContext.inkSoft, fontSize: 13),
                ),
                const SizedBox(height: 14),
                if (eligibleTxs.isEmpty)
                  Text(
                    'No unlinked ${occurrence.amount.currency.code} expense transactions found. Record an expense first, then link it here for partial or full settlement.',
                    style: TextStyle(color: sheetContext.inkSoft, height: 1.4),
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: selectedTxId,
                    decoration: const InputDecoration(
                      labelText: 'Select recorded expense transaction',
                    ),
                    items: [
                      for (final tx in eligibleTxs)
                        DropdownMenuItem(
                          value: tx.id,
                          child: Text(
                            '${tx.note.isEmpty ? 'Expense' : tx.note} · ${state.transactionUnallocatedForCommitments(tx).text} available',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (next) {
                      if (next == null) return;
                      final tx =
                          eligibleTxs.firstWhere((item) => item.id == next);
                      final avail =
                          state.transactionUnallocatedForCommitments(tx);
                      final suggested = avail.minor < outstanding.minor
                          ? avail.minor
                          : outstanding.minor;
                      setSheetState(() {
                        selectedTxId = next;
                        amountController.text =
                            (suggested / 100).toStringAsFixed(2);
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('link_payment_amount_input'),
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText:
                          'Payment amount (${occurrence.amount.currency.code}) — supports partial payments',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const Key('confirm_link_payment_button'),
                      onPressed: () {
                        final txId = selectedTxId;
                        final parsed =
                            double.tryParse(amountController.text.trim());
                        if (txId == null || parsed == null || parsed <= 0) {
                          return;
                        }
                        final minor = (parsed * 100).round();
                        final amount = Money(minor, occurrence.amount.currency);
                        final paymentId = uuidFromSeed(
                          'payment:${occurrence.id}:$txId:${state.commitmentPayments.length}:$minor',
                        );
                        final ok = state.associateCommitmentPayment(
                          id: paymentId,
                          occurrenceId: occurrence.id,
                          transactionId: txId,
                          amount: amount,
                        );
                        if (ok) {
                          Navigator.pop(sheetContext);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Amount exceeds occurrence balance or transaction unallocated amount.',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Link Payment'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final unlocked = _isUnlocked(state);
        final overdue = state.overdueCommitments();
        final upcoming = state.upcomingCommitments();
        final byId = {
          for (final item in state.financialCommitments) item.id: item,
        };

        return Scaffold(
          backgroundColor: context.bg,
          appBar: AppBar(
            title: const Text('Smart Bills & Commitments'),
            actions: [
              if (unlocked && state.canAuthorTransact)
                IconButton(
                  tooltip: 'Generate next 60 days',
                  onPressed: () => _extendHorizon(state),
                  icon: const Icon(Icons.autorenew),
                ),
            ],
          ),
          floatingActionButton: unlocked && state.canAuthorTransact
              ? FloatingActionButton.extended(
                  key: const Key('add_commitment_fab'),
                  onPressed: () => _showAddCommitmentSheet(state),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Commitment'),
                )
              : null,
          body: !unlocked
              ? ListView(
                  padding: kPageInsets,
                  children: [
                    PlusEmptyState(
                      icon: Icons.event_repeat_rounded,
                      title:
                          'Smart Bills & Commitments is a Mhuri Plus feature',
                      message:
                          'Your fixed recurring expenses remain free. Plus adds flexible due dates, one-time obligations, partial payments, and reminders without recording an expense before it is paid.',
                      action: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const PlusScreen()),
                        ),
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: const Text('Explore Mhuri Plus'),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: kPageInsets,
                  children: [
                    const PlusHero(
                      eyebrow: 'Smart commitments',
                      title: 'Stay ahead of every due date',
                      description:
                          'Track what is due, connect real payments and keep recurring obligations visible.',
                      icon: Icons.event_repeat_rounded,
                    ),
                    const SizedBox(height: 16),
                    _SummaryHeader(
                      overdueCount: overdue.length,
                      upcomingCount: upcoming.length,
                      activeCommitments: state.financialCommitments
                          .where((c) => c.status == CommitmentStatus.active)
                          .length,
                    ),
                    const SizedBox(height: 14),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'upcoming',
                          label: Text('Due & Overdue'),
                          icon: Icon(Icons.schedule, size: 16),
                        ),
                        ButtonSegment(
                          value: 'schedules',
                          label: Text('Schedules'),
                          icon: Icon(Icons.repeat, size: 16),
                        ),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (next) =>
                          setState(() => _filter = next.first),
                    ),
                    const SizedBox(height: 16),
                    if (_filter == 'upcoming') ...[
                      if (overdue.isEmpty && upcoming.isEmpty)
                        const _EmptyPane(
                          title: 'No upcoming commitment occurrences',
                          subtitle:
                              'Add a one-time or recurring commitment to track due dates, partial payments, and reminders without creating expenses prematurely.',
                        ),
                      if (overdue.isNotEmpty) ...[
                        Text(
                          'Overdue (${overdue.length})',
                          style: TextStyle(
                            color: context.danger,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final occ in overdue)
                          _OccurrenceCard(
                            occurrence: occ,
                            commitment: byId[occ.commitmentId],
                            outstanding: state.commitmentOutstanding(occ),
                            isOverdue: true,
                            canManage: state.canAuthorTransact,
                            onLinkPayment: () => _showLinkPaymentSheet(
                              state,
                              occ,
                              byId[occ.commitmentId],
                            ),
                            onSkip: () =>
                                state.updateCommitmentOccurrenceStatus(
                              occ.id,
                              CommitmentOccurrenceStatus.skipped,
                            ),
                          ),
                        const SizedBox(height: 12),
                      ],
                      if (upcoming.isNotEmpty) ...[
                        Text(
                          'Upcoming (${upcoming.length})',
                          style: TextStyle(
                            color: context.ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final occ in upcoming)
                          _OccurrenceCard(
                            occurrence: occ,
                            commitment: byId[occ.commitmentId],
                            outstanding: state.commitmentOutstanding(occ),
                            isOverdue: false,
                            canManage: state.canAuthorTransact,
                            onLinkPayment: () => _showLinkPaymentSheet(
                              state,
                              occ,
                              byId[occ.commitmentId],
                            ),
                            onSkip: () =>
                                state.updateCommitmentOccurrenceStatus(
                              occ.id,
                              CommitmentOccurrenceStatus.skipped,
                            ),
                          ),
                      ],
                    ] else ...[
                      if (state.financialCommitments.isEmpty)
                        const _EmptyPane(
                          title: 'No commitment schedules yet',
                          subtitle:
                              'Create a recurring or one-time commitment to forecast obligations in the Payday Planner.',
                        ),
                      for (final item in state.financialCommitments)
                        _CommitmentRuleCard(
                          commitment: item,
                          envelopeName: state.envelope(item.envelopeId)?.name,
                          canManage: state.canAuthorTransact,
                          onStatusChanged: (nextStatus) =>
                              state.setCommitmentStatus(item.id, nextStatus),
                        ),
                    ],
                    const SizedBox(height: 80),
                  ],
                ),
        );
      },
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({
    required this.overdueCount,
    required this.upcomingCount,
    required this.activeCommitments,
  });

  final int overdueCount;
  final int upcomingCount;
  final int activeCommitments;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.hairline),
        ),
        child: Row(
          children: [
            Expanded(
              child: _MetricStat(
                label: 'Overdue',
                value: '$overdueCount',
                color: overdueCount > 0 ? context.danger : context.ink,
              ),
            ),
            Expanded(
              child: _MetricStat(
                label: 'Upcoming',
                value: '$upcomingCount',
                color: context.primary,
              ),
            ),
            Expanded(
              child: _MetricStat(
                label: 'Active rules',
                value: '$activeCommitments',
                color: context.ink,
              ),
            ),
          ],
        ),
      );
}

class _MetricStat extends StatelessWidget {
  const _MetricStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: context.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      );
}

class _OccurrenceCard extends StatelessWidget {
  const _OccurrenceCard({
    required this.occurrence,
    required this.commitment,
    required this.outstanding,
    required this.isOverdue,
    required this.canManage,
    required this.onLinkPayment,
    required this.onSkip,
  });

  final CommitmentOccurrence occurrence;
  final FinancialCommitment? commitment;
  final Money outstanding;
  final bool isOverdue;
  final bool canManage;
  final VoidCallback onLinkPayment;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final paidMinor = occurrence.amount.minor - outstanding.minor;
    final isPartial = paidMinor > 0 && outstanding.minor > 0;
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    commitment?.name ?? 'Commitment',
                    style: TextStyle(
                      color: context.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? context.danger.withValues(alpha: 0.14)
                        : context.primarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isOverdue
                        ? 'Overdue'
                        : isPartial
                            ? 'Partially paid'
                            : 'Scheduled',
                    style: TextStyle(
                      color: isOverdue ? context.danger : context.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Due ${_dateText(occurrence.dueDate)} · Total ${occurrence.amount.text} · Remaining ${outstanding.text}',
              style: TextStyle(color: context.inkSoft, fontSize: 12),
            ),
            if (canManage) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onLinkPayment,
                    icon: const Icon(Icons.link, size: 16),
                    label: const Text('Link Payment'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: onSkip,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommitmentRuleCard extends StatelessWidget {
  const _CommitmentRuleCard({
    required this.commitment,
    required this.envelopeName,
    required this.canManage,
    required this.onStatusChanged,
  });

  final FinancialCommitment commitment;
  final String? envelopeName;
  final bool canManage;
  final ValueChanged<CommitmentStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final remindersText = commitment.reminderDaysBefore.isEmpty
        ? 'No reminders'
        : commitment.reminderDaysBefore
            .map((d) => d == 0 ? 'due day' : '${d}d before')
            .join(', ');
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          '${commitment.name} · ${commitment.amount.text}',
          style: TextStyle(color: context.ink, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${_recurrenceLabel(commitment.recurrence)} · Status: ${commitment.status.name}'
          '${envelopeName != null ? ' · $envelopeName' : ''}\n'
          'Reminders: $remindersText',
          style: TextStyle(color: context.inkSoft, fontSize: 12),
        ),
        isThreeLine: true,
        trailing: canManage
            ? PopupMenuButton<CommitmentStatus>(
                onSelected: onStatusChanged,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: CommitmentStatus.active,
                    child: Text('Set Active'),
                  ),
                  PopupMenuItem(
                    value: CommitmentStatus.paused,
                    child: Text('Pause'),
                  ),
                  PopupMenuItem(
                    value: CommitmentStatus.ended,
                    child: Text('End schedule'),
                  ),
                  PopupMenuItem(
                    value: CommitmentStatus.archived,
                    child: Text('Archive'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: context.ink,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(color: context.inkSoft, height: 1.4),
            ),
          ],
        ),
      );
}

String _recurrenceLabel(CommitmentRecurrence recurrence) =>
    switch (recurrence) {
      CommitmentRecurrence.oneTime => 'One-time',
      CommitmentRecurrence.weekly => 'Weekly',
      CommitmentRecurrence.fortnightly => 'Fortnightly',
      CommitmentRecurrence.monthly => 'Monthly',
      CommitmentRecurrence.quarterly => 'Quarterly',
      CommitmentRecurrence.yearly => 'Yearly',
    };

String _dateText(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
