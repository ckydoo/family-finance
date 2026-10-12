import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/utils/ids.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ring_progress.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// Savings goals, kid jars and the savings-circle tracker (spec Module E, §7.5).
enum SavingsSection { goals, debts }

Future<void> _showMukandoSetup(BuildContext context, AppState s) async {
  if (!s.canAdmin) {
    await _showSavingsRestriction(context, action: 'configure Mukando');
    return;
  }
  final name = TextEditingController(
      text:
          s.circle.name == 'Savings circle' ? 'Family Mukando' : s.circle.name);
  final amount = TextEditingController(
      text: s.circle.contribution.minor > 0
          ? s.circle.contribution.major.toStringAsFixed(2)
          : '20.00');
  var currency = s.circle.contribution.currency;
  var frequency = s.circle.frequency;
  var totalRounds = s.circle.totalRounds > 0 ? s.circle.totalRounds : 0;
  var startDate = s.circle.startedOnMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(s.circle.startedOnMs)
      : DateTime.now();

  // Eligible members (exclude kid and viewer roles)
  final eligibleMembers = s.members
      .where((m) => m.role != Role.kid && m.role != Role.viewer)
      .toList();

  // Selected participant IDs preserving existing order if any, or default eligible
  final orderedIds = <String>[];
  for (final id in s.circle.participantIds) {
    if (eligibleMembers.any((m) => m.id == id) && !orderedIds.contains(id)) {
      orderedIds.add(id);
    }
  }
  if (orderedIds.isEmpty) {
    orderedIds.addAll(eligibleMembers.map((m) => m.id));
  }

  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) {
        if (totalRounds == 0) {
          totalRounds = orderedIds.isNotEmpty ? orderedIds.length : 1;
        }

        return MhuriSheetShell(
          title: s.circle.isConfigured ? 'Configure Mukando' : 'Set up Mukando',
          subtitle: 'Rotating savings circle for family members',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: name,
                decoration: InputDecoration(
                  labelText: 'Circle name',
                  hintText: 'e.g. Family Mukando',
                  filled: true,
                  fillColor: context.card,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Contribution per turn',
                        filled: true,
                        fillColor: context.card,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<Currency>(
                      initialValue: currency,
                      decoration: InputDecoration(
                        labelText: 'Currency',
                        filled: true,
                        fillColor: context.card,
                      ),
                      items: Currency.values
                          .map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.code),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheetState(() => currency = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: InputDecoration(
                        labelText: 'Frequency',
                        filled: true,
                        fillColor: context.card,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                        DropdownMenuItem(
                            value: 'fortnightly', child: Text('Fortnightly')),
                        DropdownMenuItem(
                            value: 'monthly', child: Text('Monthly')),
                      ],
                      onChanged: (v) {
                        if (v != null) setSheetState(() => frequency = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setSheetState(() => startDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Start date',
                          filled: true,
                          fillColor: context.card,
                        ),
                        child: Text(
                          DateFormat.yMMMd().format(startDate),
                          style: TextStyle(fontSize: 13, color: context.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total rounds: $totalRounds',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: totalRounds > 1
                        ? () => setSheetState(() => totalRounds--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setSheetState(() => totalRounds++),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members & Collection Order',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    ),
                  ),
                  Text(
                    '${orderedIds.length} selected',
                    style: TextStyle(fontSize: 12, color: context.inkSoft),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Top member collects in Round 1. Use arrows to reorder collection turns.',
                style: TextStyle(fontSize: 12, color: context.inkSoft),
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < orderedIds.length; i++) ...[
                Builder(builder: (ctx) {
                  final memberId = orderedIds[i];
                  final m = s.member(memberId);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.hairline),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.primarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        MemberAvatar(
                          backgroundColor: context.primarySoft,
                          icon: iconForKey(m?.emoji) ?? kFallbackSemanticIcon,
                          imageUrl: m?.avatarUrl,
                          radius: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            m?.name ?? 'Member',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.ink,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: i > 0
                              ? () => setSheetState(() {
                                    final item = orderedIds.removeAt(i);
                                    orderedIds.insert(i - 1, item);
                                  })
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: i < orderedIds.length - 1
                              ? () => setSheetState(() {
                                    final item = orderedIds.removeAt(i);
                                    orderedIds.insert(i + 1, item);
                                  })
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          visualDensity: VisualDensity.compact,
                          onPressed: orderedIds.length > 1
                              ? () => setSheetState(() {
                                    orderedIds.removeAt(i);
                                    if (totalRounds > orderedIds.length &&
                                        totalRounds > 1) {
                                      totalRounds = orderedIds.length;
                                    }
                                  })
                              : null,
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // Add remaining members dropdown
              if (eligibleMembers.any((m) => !orderedIds.contains(m.id))) ...[
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    hintText: '+ Add member to circle',
                    filled: true,
                    fillColor: context.card,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: eligibleMembers
                      .where((m) => !orderedIds.contains(m.id))
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ))
                      .toList(),
                  onChanged: (id) {
                    if (id != null) {
                      setSheetState(() {
                        orderedIds.add(id);
                        if (totalRounds < orderedIds.length) {
                          totalRounds = orderedIds.length;
                        }
                      });
                    }
                  },
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(amount.text.trim());
                  final selectedParticipants = [
                    for (final id in orderedIds)
                      if (s.member(id) != null) s.member(id)!
                  ];
                  if (val == null || val <= 0 || selectedParticipants.isEmpty) {
                    return;
                  }
                  s.configureMukando(
                    name: name.text.trim().isEmpty
                        ? 'Family Mukando'
                        : name.text.trim(),
                    contribution: Money.fromMajor(val, currency),
                    frequency: frequency,
                    participants: selectedParticipants,
                    totalRounds: totalRounds,
                    startDate: startDate,
                  );
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Mukando configured successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                ),
                child: const Text('Save Mukando'),
              ),
            ],
          ),
        );
      },
    ),
  );
  name.dispose();
  amount.dispose();
}

Future<void> _showSavingsRestriction(
  BuildContext context, {
  required String action,
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Permission needed'),
        content: Text(
          'Your family role cannot $action. A Family Owner, Family Admin, or Adult Member can do this.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({
    super.key,
    this.standalone = false,
    this.initialSection = SavingsSection.goals,
    this.startAdding = false,
  });

  final bool standalone;
  final SavingsSection initialSection;
  final bool startAdding;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late SavingsSection _section;

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    if (widget.startAdding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openCreate(AppScope.of(context));
      });
    }
  }

  void _openCreate(AppState state) {
    if (!state.canCreateSavingsRecords) {
      _showSavingsRestriction(context, action: 'create shared savings records');
      return;
    }
    switch (_section) {
      case SavingsSection.goals:
        _newGoalSheet(context);
      case SavingsSection.debts:
        _newDebtSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final familyGoals = s.goals.where((g) => !g.isKidJar).toList();
    final kidGoals = s.goals.where((g) => g.isKidJar).toList();
    final kidsWithoutJar = s.members
        .where((member) =>
            member.role == Role.kid && s.kidJarFor(member.id) == null)
        .toList();
    final m = s.circle;

    final content = SafeArea(
      child: RefreshIndicator(
          onRefresh: () => s.refresh(),
          child: ListView(
            padding: kTabPageInsets,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.savingsTitle,
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: context.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: switch (_section) {
                      SavingsSection.goals =>
                        AppLocalizations.of(context)!.newSavingsGoal,
                      SavingsSection.debts => 'Add debt or money owed',
                    },
                    onPressed: () => _openCreate(s),
                    icon: Icon(Icons.add_circle_rounded,
                        color: context.primary, size: 30),
                  ),
                ],
              ),
              Text(
                switch (_section) {
                  SavingsSection.goals =>
                    'Save towards the things that matter to your family.',
                  SavingsSection.debts =>
                    'Keep repayments, due dates and balances clear.',
                },
                style: TextStyle(fontSize: 13, color: context.inkSoft),
              ),
              const SizedBox(height: 14),
              SegmentedButton<SavingsSection>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: SavingsSection.goals, label: Text('Goals')),
                  ButtonSegment(
                      value: SavingsSection.debts, label: Text('Debts')),
                ],
                selected: {_section},
                onSelectionChanged: (value) =>
                    setState(() => _section = value.first),
              ),
              const SizedBox(height: 16),
              if (_section == SavingsSection.goals) ...[
                if (familyGoals.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: EmptyState(
                      icon: Icons.track_changes,
                      title: AppLocalizations.of(context)!.noGoals,
                      subtitle: AppLocalizations.of(context)!.noGoalsHint,
                    ),
                  ),
                  Text(
                    'Ideas for family savings:',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: context.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final idea in [
                        'Emergency fund',
                        'School fees',
                        'Home',
                        'Car',
                        'Business',
                        'Travel',
                        'Other',
                      ])
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 14),
                          label: Text(idea),
                          onPressed: () {
                            if (!s.canCreateSavingsRecords) {
                              _showSavingsRestriction(context,
                                  action: 'create a savings goal');
                              return;
                            }
                            _newGoalSheet(context,
                                initialName: idea == 'Other' ? '' : idea);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      if (!s.canCreateSavingsRecords) {
                        _showSavingsRestriction(context,
                            action: 'create a savings goal');
                        return;
                      }
                      _newGoalSheet(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.primary,
                      foregroundColor: context.onSolid,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                    ),
                    icon: const Icon(Icons.add),
                    label:
                        Text(AppLocalizations.of(context)!.createSavingsGoal),
                  ),
                  const SizedBox(height: 12),
                ],
                for (final g in familyGoals) ...[
                  GoalCard(goal: g),
                  const SizedBox(height: 12),
                ],
              ],
              if (_section == SavingsSection.debts) ...[
                Row(children: [
                  Expanded(
                    child: Text(
                      'Debts & money owed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.ink,
                      ),
                    ),
                  ),
                ]),
                if (s.familyDebts.isEmpty)
                  OutlinedButton.icon(
                    onPressed: () {
                      if (!s.canCreateSavingsRecords) {
                        _showSavingsRestriction(context, action: 'add a debt');
                        return;
                      }
                      _newDebtSheet(context);
                    },
                    icon: const Icon(Icons.handshake_outlined),
                    label: const Text('Add debt or money owed'),
                  )
                else
                  for (final debt in s.familyDebts) ...[
                    _DebtCard(debt: debt),
                    const SizedBox(height: 10),
                  ],
              ],
              if (_section == SavingsSection.goals) ...[
                // ── Kid jars ────────────────────────────────────────────────────
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.kidsJars,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.ink,
                        ),
                      ),
                    ),
                    if (s.canEditBudgets && kidsWithoutJar.isNotEmpty)
                      IconButton(
                        tooltip: AppLocalizations.of(context)!.addKidWish,
                        onPressed: () => _newGoalSheet(
                          context,
                          kidJarMembers: kidsWithoutJar,
                        ),
                        icon: Icon(Icons.add_circle_outline,
                            color: context.primary, size: 24),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Kids can complete chores, earn stars and save towards their own goals. '
                  '${AppLocalizations.of(context)!.starsHome(s.stars)}',
                  style: TextStyle(
                      fontSize: 12, color: context.inkSoft, height: 1.4),
                ),
                const SizedBox(height: 12),
                for (final g in kidGoals) ...[
                  GoalCard(goal: g, kidFlavored: true),
                  const SizedBox(height: 12),
                ],

                // Mukando is configured in Settings. This screen only shows the
                // circle once the family has explicitly enabled the feature.
                const SizedBox(height: 8),
                if (s.mukandoEnabled)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: kBRadiusM,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.autorenew,
                                  size: 19, color: context.primaryDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!
                                    .circleMember(m.name),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            if (s.canAdmin)
                              IconButton(
                                tooltip: 'Configure Mukando',
                                onPressed: () => _showMukandoSetup(context, s),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                          ],
                        ),
                        if (m.participantIds.isEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                              'Set the contribution, frequency, members and collection order before starting.'),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                              onPressed: () => _showMukandoSetup(context, s),
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Set up Mukando')),
                        ] else ...[
                          const SizedBox(height: 12),
                          // Next collector highlight box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.primarySoft.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      context.primary.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              children: [
                                MemberAvatar(
                                  backgroundColor: context.primarySoft,
                                  icon: iconForKey(s
                                          .member(m.nextCollectorId ?? '')
                                          ?.emoji) ??
                                      Icons.person,
                                  imageUrl: s
                                      .member(m.nextCollectorId ?? '')
                                      ?.avatarUrl,
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Round ${m.currentRound} of ${m.totalRounds} • ${m.nextCollector} collects',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: context.ink,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Round pot: ${s.hideAmounts ? '•••••' : m.roundPot.text} (${m.contribution.text} × ${m.participantIds.length})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: context.hairline),
                                  ),
                                  child: Text(
                                    m.frequency.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: context.primaryDark,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Due date row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Round due: ${DateFormat.yMMMd().format(m.currentDueDate)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      DateTime.now().isAfter(m.currentDueDate)
                                          ? context.expenseRed
                                          : context.inkSoft,
                                ),
                              ),
                              Builder(builder: (ctx) {
                                final paidCount = m.participantIds
                                    .where((id) => s.hasMukandoPaid(id))
                                    .length;
                                return Text(
                                  '$paidCount of ${m.participantIds.length} paid',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: paidCount == m.participantIds.length
                                        ? context.incomeGreen
                                        : context.inkSoft,
                                  ),
                                );
                              }),
                            ],
                          ),
                          const SizedBox(height: 8),
                          MhuriProgress(
                            progress: m.progress.clamp(0.0, 1.0).toDouble(),
                            height: 4,
                          ),
                          const SizedBox(height: 14),
                          // Participant payment list
                          for (var i = 0; i < m.participantIds.length; i++)
                            Builder(builder: (ctx) {
                              final memberId = m.participantIds[i];
                              final isPaid = s.hasMukandoPaid(memberId);
                              final isLate = s.isMukandoPaymentLate(memberId);
                              final memberName = i < m.order.length
                                  ? m.order[i]
                                  : s.member(memberId)?.name ?? 'Member';
                              final mem = s.member(memberId);
                              final payment = s.paymentForMember(memberId);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? context.card
                                      : (isLate
                                          ? context.expenseRed
                                              .withValues(alpha: 0.05)
                                          : context.track),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isPaid
                                        ? context.hairline
                                        : (isLate
                                            ? context.expenseRed
                                                .withValues(alpha: 0.3)
                                            : context.hairline),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isPaid
                                          ? Icons.check_circle
                                          : (isLate
                                              ? Icons.warning_amber_rounded
                                              : Icons.radio_button_unchecked),
                                      size: 20,
                                      color: isPaid
                                          ? context.incomeGreen
                                          : (isLate
                                              ? context.expenseRed
                                              : context.inkSoft),
                                    ),
                                    const SizedBox(width: 10),
                                    MemberAvatar(
                                      backgroundColor: context.primarySoft,
                                      icon: iconForKey(mem?.emoji) ??
                                          kFallbackSemanticIcon,
                                      imageUrl: mem?.avatarUrl,
                                      radius: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            memberName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: context.ink,
                                            ),
                                          ),
                                          Text(
                                            isPaid
                                                ? 'Paid ${payment != null ? DateFormat.MMMd().format(payment.paidAt) : ''}'
                                                : (isLate
                                                    ? 'Late • Overdue'
                                                    : 'Payment due'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isPaid
                                                  ? context.incomeGreen
                                                  : (isLate
                                                      ? context.expenseRed
                                                      : context.inkSoft),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isPaid) ...[
                                      if (s.canAdmin ||
                                          memberId == s.realUser.id)
                                        IconButton(
                                          tooltip: 'Undo payment',
                                          icon:
                                              const Icon(Icons.undo, size: 16),
                                          visualDensity: VisualDensity.compact,
                                          onPressed: () {
                                            s.unrecordMukandoPayment(memberId);
                                          },
                                        ),
                                    ] else ...[
                                      if (s.canAdmin ||
                                          memberId == s.realUser.id)
                                        TextButton(
                                          onPressed: () =>
                                              s.recordMukandoPayment(memberId),
                                          style: TextButton.styleFrom(
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          child: const Text('Mark paid'),
                                        ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: s.currentMukandoRoundComplete
                                ? () {
                                    HapticFeedback.lightImpact();
                                    s.circleCollect(
                                        id: 'mukando_round_${s.circle.currentRound + 1}');
                                    celebrate(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          AppLocalizations.of(context)!.roundOk,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        action: SnackBarAction(
                                          label: AppLocalizations.of(context)!
                                              .undo,
                                          onPressed: s.undoCircleCollect,
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.primary,
                              foregroundColor: context.onSolid,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: kBRadiusM),
                            ),
                            child: Builder(builder: (ctx) {
                              final paidCount = m.participantIds
                                  .where((id) => s.hasMukandoPaid(id))
                                  .length;
                              if (!s.currentMukandoRoundComplete) {
                                return Text(
                                    'Complete Round ($paidCount/${m.participantIds.length} paid)');
                              }
                              return Text(
                                  AppLocalizations.of(context)!.markRound);
                            }),
                          ),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              AppLocalizations.of(context)!.recordsOnly,
                              style: TextStyle(
                                  fontSize: 11, color: context.inkSoft),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ],
          )),
    );
    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Savings')),
        body: content,
      );
    }
    return content;
  }

  void _newGoalSheet(
    BuildContext context, {
    List<Member> kidJarMembers = const [],
    String initialName = '',
  }) {
    final s = AppScope.of(context);
    final isKidJar = kidJarMembers.isNotEmpty;
    String? selectedKidId = isKidJar ? kidJarMembers.first.id : null;
    final nameController = TextEditingController(text: initialName);
    var goalName = initialName;
    var targetText = '';
    var currency = s.displayCurrency;

    String? goalError;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => MhuriSheetShell(
          title: isKidJar
              ? AppLocalizations.of(context)!.addKidWish
              : AppLocalizations.of(context)!.newSavingsGoal,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isKidJar) ...[
                DropdownButtonFormField<String>(
                  initialValue: kidJarMembers.any((m) => m.id == selectedKidId)
                      ? selectedKidId
                      : null,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.childLabel,
                  ),
                  items: [
                    for (final member in kidJarMembers)
                      DropdownMenuItem(
                          value: member.id, child: Text(member.name)),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => selectedKidId = value),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  goalName = value;
                  if (goalError != null) setSheetState(() => goalError = null);
                },
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.goalName,
                  hintText: AppLocalizations.of(context)!.goalNameHint,
                  filled: true,
                  fillColor: context.card,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountInputFormatters,
                onChanged: (value) {
                  targetText = value;
                  if (goalError != null) setSheetState(() => goalError = null);
                },
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.targetAmount,
                  prefixText: '${currency.symbol} ',
                  filled: true,
                  fillColor: context.card,
                ),
              ),
              const SizedBox(height: 12),
              if (s.activeCurrencies.length > 1)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in s.activeCurrencies)
                      ChoiceChip(
                        label: Text(c.short),
                        selected: currency == c,
                        onSelected: (_) => setSheetState(() => currency = c),
                      ),
                  ],
                ),
              if (goalError != null) ...[
                const SizedBox(height: 10),
                ErrorNotice(goalError!),
              ],
              const SizedBox(height: 20),
              PrimaryButton(
                label: AppLocalizations.of(context)!.createGoal,
                onPressed: () {
                  final parsed = double.tryParse(
                    targetText.trim().replaceAll(',', ''),
                  );
                  if (goalName.trim().isEmpty ||
                      parsed == null ||
                      parsed <= 0) {
                    setSheetState(() {
                      goalError =
                          AppLocalizations.of(context)!.goalNameAmountFirst;
                    });
                    return;
                  }
                  s.addGoal(
                    name: goalName,
                    target: Money.fromMajor(parsed, currency),
                    emoji: isKidJar ? 'gift' : 'goal',
                    isKidJar: isKidJar,
                    ownerMemberId: selectedKidId,
                  );
                  Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Kept dormant with the stored campaign model so historical records can be
// restored if this feature returns; there is no route or visible entry point.
// ignore: unused_element
Future<void> _newCampaignSheet(BuildContext context) async {
  final s = AppScope.of(context);
  final name = TextEditingController();
  final target = TextEditingController();
  var deadline = DateTime.now().add(const Duration(days: 30));
  String? error;
  await showMhuriSheet<void>(
    context: context,
    builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => MhuriSheetShell(
              title: 'New family contribution',
              footer: PrimaryButton(
                  label: 'Create',
                  onPressed: () {
                    final amount =
                        double.tryParse(target.text.replaceAll(',', ''));
                    if (name.text.trim().isEmpty ||
                        amount == null ||
                        amount <= 0) {
                      setSheet(() => error = 'Enter a name and target amount.');
                      return;
                    }
                    s.createContributionCampaign(
                        name: name.text,
                        target: Money.fromMajor(amount, s.displayCurrency),
                        deadline: deadline);
                    Navigator.pop(sheetContext);
                  }),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    autofocus: true,
                    decoration:
                        const InputDecoration(labelText: 'Event or cause')),
                const SizedBox(height: 12),
                TextField(
                    controller: target,
                    inputFormatters: amountInputFormatters,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Target',
                        prefixText: '${s.displayCurrency.symbol} ')),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Deadline'),
                    subtitle: Text(DateFormat.yMMMd().format(deadline)),
                    trailing: const Icon(Icons.calendar_today_outlined),
                    onTap: () async {
                      final picked = await showDatePicker(
                          context: sheetContext,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                          initialDate: deadline);
                      if (picked != null) setSheet(() => deadline = picked);
                    }),
                if (error != null) ErrorNotice(error!),
              ]),
            )),
  );
}

// ignore: unused_element
class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.campaign});
  final ContributionCampaign campaign;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final pledged = s.pledgedFor(campaign), paid = s.collectedFor(campaign);
    final creator = s.member(campaign.createdById)?.name ?? 'Former member';
    final remaining = Money(
        (campaign.target.minor - paid.minor).clamp(0, campaign.target.minor),
        campaign.target.currency);
    return InkWell(
        onTap: () => _details(context, s),
        borderRadius: kBRadiusM,
        child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.volunteer_activism_outlined,
                    color: context.primary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(campaign.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.5))),
                Text(DateFormat.MMMd().format(campaign.deadline),
                    style: TextStyle(fontSize: 12, color: context.inkSoft)),
              ]),
              const SizedBox(height: 8),
              MhuriProgress(
                  progress: (paid.minor / campaign.target.minor)
                      .clamp(0, 1)
                      .toDouble(),
                  height: 4),
              const SizedBox(height: 6),
              Text(
                  'Pledged ${pledged.text} · Collected ${paid.text} · Remaining ${remaining.text}',
                  style: TextStyle(fontSize: 12, color: context.inkSoft)),
              const SizedBox(height: 2),
              Text('Created by $creator',
                  style: TextStyle(fontSize: 11.5, color: context.inkSoft)),
            ])));
  }

  Future<void> _details(BuildContext context, AppState s) => showMhuriSheet<
          void>(
      context: context,
      builder: (_) => ListenableBuilder(
          listenable: s,
          builder: (context, _) => MhuriSheetShell(
              title: campaign.name,
              subtitle: 'Due ${DateFormat.yMMMd().format(campaign.deadline)}',
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final member in s.members)
                  _ContributionMember(campaign: campaign, member: member),
              ]))));
}

class _ContributionMember extends StatelessWidget {
  const _ContributionMember({required this.campaign, required this.member});
  final ContributionCampaign campaign;
  final Member member;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context),
        pledged = s.pledgedFor(campaign, member.id),
        paid = s.collectedFor(campaign, member.id);
    final status = paid.minor == 0
        ? 'Not paid'
        : paid.minor < pledged.minor
            ? 'Partly paid'
            : 'Paid';
    return ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(member.name),
        subtitle: Text('Pledged ${pledged.text} · Paid ${paid.text} · $status'),
        trailing: s.canAdmin || member.id == s.realUser.id
            ? IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _entry(context, s))
            : null);
  }

  Future<void> _entry(BuildContext context, AppState s) async {
    final amount = TextEditingController();
    var payment = false;
    await showMhuriSheet<void>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheet) => MhuriSheetShell(
                title: member.name,
                footer: PrimaryButton(
                    label: payment ? 'Record payment' : 'Save pledge',
                    onPressed: () {
                      final value =
                          double.tryParse(amount.text.replaceAll(',', ''));
                      if (value == null || value <= 0) return;
                      final money =
                          Money.fromMajor(value, campaign.target.currency);
                      if (payment) {
                        s.recordContributionPayment(campaign, member.id, money,
                            id: newUuid());
                      } else {
                        s.setContributionPledge(campaign, member.id, money);
                      }
                      Navigator.pop(sheetContext);
                    }),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Pledge')),
                        ButtonSegment(value: true, label: Text('Payment'))
                      ],
                      selected: {
                        payment
                      },
                      onSelectionChanged: (v) =>
                          setSheet(() => payment = v.first)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: amount,
                      autofocus: true,
                      inputFormatters: amountInputFormatters,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '${campaign.target.currency.symbol} ')),
                ]))));
  }
}

Future<void> _newDebtSheet(BuildContext context) async {
  final s = AppScope.of(context);
  final name = TextEditingController(), amount = TextEditingController();
  var direction = DebtDirection.iOwe;
  String? counterpartyMemberId;
  DateTime? dueDate;
  await showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheet) => MhuriSheetShell(
              title: 'Add debt or money owed',
              footer: PrimaryButton(
                  label: 'Save',
                  onPressed: () {
                    final value =
                        double.tryParse(amount.text.replaceAll(',', ''));
                    if (name.text.trim().isEmpty ||
                        value == null ||
                        value <= 0) {
                      return;
                    }
                    s.createDebt(
                        name: name.text,
                        direction: direction,
                        principal: Money.fromMajor(value, s.displayCurrency),
                        counterpartyMemberId: counterpartyMemberId,
                        dueDate: dueDate);
                    Navigator.pop(sheetContext);
                  }),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SegmentedButton<DebtDirection>(
                    segments: const [
                      ButtonSegment(
                          value: DebtDirection.iOwe, label: Text('I owe')),
                      ButtonSegment(
                          value: DebtDirection.owedToMe,
                          label: Text('Owed to me')),
                      ButtonSegment(
                          value: DebtDirection.familyLoan,
                          label: Text('Family loan')),
                    ],
                    selected: {
                      direction
                    },
                    onSelectionChanged: (v) =>
                        setSheet(() => direction = v.first)),
                const SizedBox(height: 12),
                TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                        labelText: 'Who or what is this for?')),
                const SizedBox(height: 12),
                TextField(
                    controller: amount,
                    inputFormatters: amountInputFormatters,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        labelText: 'Original amount',
                        prefixText: '${s.displayCurrency.symbol} ')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: counterpartyMemberId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Family member (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Someone outside the family')),
                    for (final member in s.members)
                      DropdownMenuItem<String?>(
                          value: member.id, child: Text(member.name)),
                  ],
                  onChanged: (value) =>
                      setSheet(() => counterpartyMemberId = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Due date (optional)'),
                  subtitle: Text(dueDate == null
                      ? 'No due date'
                      : DateFormat.yMMMd().format(dueDate!)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: sheetContext,
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 3650)),
                        initialDate: dueDate ??
                            DateTime.now().add(const Duration(days: 30)));
                    if (picked != null) setSheet(() => dueDate = picked);
                  },
                ),
              ]))));
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt});
  final FamilyDebt debt;
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context),
        repaid = s.repaidOn(debt),
        remaining = s.remainingOnDebt(debt);
    final label = switch (debt.direction) {
      DebtDirection.iOwe => 'I owe',
      DebtDirection.owedToMe => 'Owed to me',
      DebtDirection.familyLoan => 'Family loan'
    };
    final counterparty = s.member(debt.counterpartyMemberId ?? '');
    final creator = s.member(debt.createdById)?.name ?? 'Former member';
    return InkWell(
      onTap: () => _details(context, s),
      borderRadius: kBRadiusM,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(debt.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14.5))),
            Text(
              debt.status == 'settled' ? 'Settled' : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: debt.status == 'settled'
                    ? context.primary
                    : context.inkSoft,
              ),
            )
          ]),
          const SizedBox(height: 4),
          Text(
              'Original ${debt.principal.text} · Repaid ${repaid.text} · Remaining ${remaining.text}',
              style: TextStyle(fontSize: 12, color: context.inkSoft)),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Added by $creator',
                style: TextStyle(fontSize: 11.5, color: context.inkSoft)),
          ),
          if (counterparty != null || debt.dueDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${counterparty == null ? '' : counterparty.name}${counterparty != null && debt.dueDate != null ? ' · ' : ''}${debt.dueDate == null ? '' : 'Due ${DateFormat.yMMMd().format(debt.dueDate!)}'}',
                style: TextStyle(fontSize: 11.5, color: context.inkSoft),
              ),
            ),
          if (debt.status == 'active')
            Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                    onPressed: () {
                      if (!s.canRecordDebtRepayments) {
                        _showSavingsRestriction(context,
                            action: 'record a debt repayment');
                        return;
                      }
                      _repay(context, s);
                    },
                    child: const Text('Record repayment',
                        style: TextStyle(fontWeight: FontWeight.w500)))),
        ]),
      ),
    );
  }

  Future<void> _details(BuildContext context, AppState s) {
    return showMhuriSheet<void>(
      context: context,
      builder: (_) => ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final creator = s.member(debt.createdById)?.name ?? 'Former member';
          final counterparty = s.member(debt.counterpartyMemberId ?? '');
          final repayments = s.debtRepayments
              .where((payment) => payment.debtId == debt.id)
              .toList()
            ..sort((a, b) => b.paidAt.compareTo(a.paidAt));
          final direction = switch (debt.direction) {
            DebtDirection.iOwe => 'I owe',
            DebtDirection.owedToMe => 'Owed to me',
            DebtDirection.familyLoan => 'Family loan',
          };
          return MhuriSheetShell(
            title: debt.name,
            subtitle: debt.status == 'settled' ? 'Settled' : direction,
            footer: s.canManageDebts ||
                    (debt.status == 'active' && s.canRecordDebtRepayments)
                ? Row(
                    children: [
                      if (s.canManageDebts) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _delete(context, s),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _edit(context, s),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit'),
                          ),
                        ),
                      ],
                      if (debt.status == 'active' &&
                          s.canRecordDebtRepayments) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _repay(context, s),
                            child: const Text('Repay'),
                          ),
                        ),
                      ],
                    ],
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DebtDetailAmount(
                      label: 'Original',
                      amount: debt.principal.text,
                    ),
                    _DebtDetailAmount(
                      label: 'Repaid',
                      amount: s.repaidOn(debt).text,
                    ),
                    _DebtDetailAmount(
                      label: 'Remaining',
                      amount: s.remainingOnDebt(debt).text,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Added by $creator'),
                if (counterparty != null) ...[
                  const SizedBox(height: 6),
                  Text('Family member: ${counterparty.name}'),
                ],
                if (debt.dueDate != null) ...[
                  const SizedBox(height: 6),
                  Text('Due ${DateFormat.yMMMd().format(debt.dueDate!)}'),
                ],
                const SizedBox(height: 22),
                Text(
                  'Repayment history',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 8),
                if (repayments.isEmpty)
                  Text(
                    'No repayments have been recorded.',
                    style: TextStyle(color: context.inkSoft),
                  )
                else
                  for (final payment in repayments)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.payments_outlined,
                        color: context.primary,
                      ),
                      title: Text(
                        payment.amount.text,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        'Recorded by ${s.member(payment.memberId)?.name ?? 'Former member'} · '
                        '${DateFormat.yMMMd().add_jm().format(payment.paidAt.toLocal())}',
                      ),
                    ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _repay(BuildContext context, AppState s) async {
    final controller = TextEditingController();
    String? error;
    await showMhuriSheet<void>(
        context: context,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, setSheet) => MhuriSheetShell(
                title: 'Record repayment',
                subtitle: '${s.remainingOnDebt(debt).text} remaining',
                footer: PrimaryButton(
                    label: 'Save repayment',
                    onPressed: () {
                      final value =
                          double.tryParse(controller.text.replaceAll(',', ''));
                      if (value == null ||
                          !s.recordDebtRepayment(debt,
                              Money.fromMajor(value, debt.principal.currency),
                              id: newUuid())) {
                        setSheet(() => error =
                            'Enter an amount up to the remaining balance.');
                        return;
                      }
                      Navigator.pop(sheetContext);
                    }),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: controller,
                      autofocus: true,
                      inputFormatters: amountInputFormatters,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Amount',
                          prefixText: '${debt.principal.currency.symbol} ')),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    ErrorNotice(error!)
                  ],
                ]))));
  }

  Future<void> _edit(BuildContext context, AppState s) async {
    final name = TextEditingController(text: debt.name);
    final amount = TextEditingController(
        text: (debt.principal.minor / 100).toStringAsFixed(2));
    var direction = debt.direction;
    var counterpartyMemberId = debt.counterpartyMemberId;
    var dueDate = debt.dueDate;
    String? error;
    await showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => MhuriSheetShell(
          title: 'Edit debt',
          subtitle: 'Repayments and the original recorder stay unchanged.',
          footer: PrimaryButton(
            label: 'Save changes',
            onPressed: () {
              final value = double.tryParse(amount.text.replaceAll(',', ''));
              if (value == null ||
                  !s.updateDebt(
                    debt,
                    name: name.text,
                    direction: direction,
                    principal: Money.fromMajor(value, debt.principal.currency),
                    counterpartyMemberId: counterpartyMemberId,
                    dueDate: dueDate,
                  )) {
                setSheet(() => error =
                    'Enter a name and an amount that is not below the repaid total.');
                return;
              }
              Navigator.pop(sheetContext);
            },
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Who or what is this for?'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DebtDirection>(
                initialValue: direction,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(
                      value: DebtDirection.iOwe, child: Text('I owe')),
                  DropdownMenuItem(
                      value: DebtDirection.owedToMe, child: Text('Owed to me')),
                  DropdownMenuItem(
                      value: DebtDirection.familyLoan,
                      child: Text('Family loan')),
                ],
                onChanged: (value) {
                  if (value != null) setSheet(() => direction = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                inputFormatters: amountInputFormatters,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Original amount',
                  prefixText: '${debt.principal.currency.symbol} ',
                  helperText: s.repaidOn(debt).minor > 0
                      ? 'Cannot be less than ${s.repaidOn(debt).text} already repaid'
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: counterpartyMemberId,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Family member (optional)'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Someone outside the family'),
                  ),
                  for (final member in s.members)
                    DropdownMenuItem<String?>(
                      value: member.id,
                      child: Text(member.name),
                    ),
                ],
                onChanged: (value) =>
                    setSheet(() => counterpartyMemberId = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Due date (optional)'),
                subtitle: Text(dueDate == null
                    ? 'No due date'
                    : DateFormat.yMMMd().format(dueDate!)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dueDate != null)
                      IconButton(
                        tooltip: 'Remove due date',
                        onPressed: () => setSheet(() => dueDate = null),
                        icon: const Icon(Icons.close),
                      ),
                    const Icon(Icons.calendar_today_outlined),
                  ],
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDate: dueDate ?? DateTime.now(),
                  );
                  if (picked != null) setSheet(() => dueDate = picked);
                },
              ),
              if (error != null) ErrorNotice(error!),
            ],
          ),
        ),
      ),
    );
    name.dispose();
    amount.dispose();
  }

  Future<void> _delete(BuildContext sheetContext, AppState s) async {
    final confirmed = await showDialog<bool>(
          context: sheetContext,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this debt?'),
            content: const Text(
              'The debt will disappear from the family list. Its repayment history and audit record will be preserved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete debt'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !s.archiveDebt(debt)) return;
    if (sheetContext.mounted) Navigator.pop(sheetContext);
  }
}

class _DebtDetailAmount extends StatelessWidget {
  const _DebtDetailAmount({required this.label, required this.amount});

  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: kBRadiusS,
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.inkSoft)),
            const SizedBox(height: 2),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class GoalCard extends StatelessWidget {
  final Goal goal;
  final bool kidFlavored;

  const GoalCard({super.key, required this.goal, this.kidFlavored = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final saved = s.savedOn(goal);
    final creator = goal.createdById == null
        ? null
        : s.member(goal.createdById!)?.name ?? 'Former member';
    final ratio =
        goal.target.minor <= 0 ? 0.0 : saved.minor / goal.target.minor;
    final ringColor = kidFlavored
        ? context.accent
        : ratio < 0.35
            ? context.accent
            : context.primary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.hairline)),
      ),
      child: Row(
        children: [
          RingProgress(
            value: ratio,
            size: 44,
            stroke: 5,
            color: ringColor,
            child: Icon(
              iconForKey(goal.emoji) ?? kFallbackSemanticIcon,
              size: 18,
              color: context.primaryDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.hideAmounts
                      ? '••••• saved'
                      : '${saved.text} saved${goal.autoSave != null ? ' · ${goal.autoSave}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
                Text(
                  s.hideAmounts ? 'Goal: •••••' : 'Goal: ${goal.target.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: context.inkSoft),
                ),
                if (creator != null)
                  Text(
                    'Created by $creator',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: context.inkSoft),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () {
                  if (!s.canContributeSavings) {
                    _showSavingsRestriction(context,
                        action: 'add money to a savings goal');
                    return;
                  }
                  _contribute(context);
                },
                style: FilledButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  elevation: 0,
                  visualDensity: VisualDensity.compact,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(AppLocalizations.of(context)!.add),
              ),
              if (s.canManageSavingsGoal(goal)) ...[
                const SizedBox(width: 2),
                SizedBox(
                  width: 32,
                  height: 36,
                  child: PopupMenuButton<String>(
                    tooltip: 'Savings goal actions',
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: context.inkSoft,
                    ),
                    onSelected: (action) => _goalAction(context, s, action),
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit goal')),
                      if (goal.status != 'done')
                        const PopupMenuItem(
                            value: 'complete',
                            child: Text('Mark as completed')),
                      if (s.canAdmin)
                        const PopupMenuItem(
                            value: 'archive', child: Text('Archive goal')),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _goalAction(
      BuildContext context, AppState state, String action) async {
    if (action == 'edit') {
      _editGoal(context, state);
      return;
    }
    if (action == 'complete') {
      state.completeGoal(goal);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Savings goal completed'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: 'Archive ${goal.name}?',
      body:
          'The goal will leave your active list, while its contribution history remains available for financial records.',
      confirmLabel: 'Archive goal',
      danger: true,
    );
    if (confirmed && context.mounted) {
      state.archiveGoal(goal);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Savings goal archived'),
          behavior: SnackBarBehavior.floating));
    }
  }

  void _editGoal(BuildContext context, AppState state) {
    final name = TextEditingController(text: goal.name);
    final target = TextEditingController(
        text: (goal.target.minor / 100).toStringAsFixed(2));
    String? error;
    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => MhuriSheetShell(
          title: 'Edit savings goal',
          footer: PrimaryButton(
            label: 'Save changes',
            onPressed: () {
              final amount = double.tryParse(target.text.replaceAll(',', ''));
              if (name.text.trim().isEmpty || amount == null || amount <= 0) {
                setSheet(() => error = 'Enter a goal name and valid target.');
                return;
              }
              state.updateGoal(goal,
                  name: name.text,
                  target: Money.fromMajor(amount, goal.target.currency));
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(sheetContext);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Savings goal updated'),
                  behavior: SnackBarBehavior.floating));
            },
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Goal')),
            const SizedBox(height: 12),
            TextField(
                controller: target,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountInputFormatters,
                decoration: InputDecoration(
                    labelText: 'Target (${goal.target.currency.symbol})')),
            if (error != null) ErrorNotice(error!),
          ]),
        ),
      ),
    );
  }

  void _contribute(BuildContext context) {
    final s = AppScope.of(context);
    Currency cur = goal.target.currency;
    final controller = TextEditingController();
    bool submitting = false;

    showMhuriSheet<void>(
      context: context,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) {
          String? contributionError;
          return MhuriSheetShell(
            title: AppLocalizations.of(context)!.addToGoal(goal.name),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: amountInputFormatters,
                  onChanged: (_) {
                    if (contributionError != null) {
                      setSheet(() => contributionError = null);
                    }
                  },
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    prefixText: '${cur.symbol} ',
                    filled: true,
                    fillColor: context.card,
                    border:
                        const OutlineInputBorder(borderSide: BorderSide.none),
                    hintText: '0.00',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in s.activeCurrencies) ...[
                      ChoiceChip(
                        label: Text(c.short),
                        selected: cur == c,
                        onSelected: (_) => setSheet(() => cur = c),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context)!
                          .goalBase(goal.target.currency.short),
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
                if (contributionError != null) ...[
                  const SizedBox(height: 10),
                  ErrorNotice(contributionError!),
                ],
                const SizedBox(height: 16),
                PrimaryButton(
                  label: AppLocalizations.of(context)!.saveContribution,
                  busy: submitting,
                  onPressed: () async {
                    final v =
                        double.tryParse(controller.text.replaceAll(',', ''));
                    if (v == null || v <= 0) {
                      setSheet(() => contributionError =
                          AppLocalizations.of(sheetCtx)!.enterAmountFirst);
                      return;
                    }
                    final contribution = Money.fromMajor(v, cur);
                    final available = s.availableToSpend(cur);
                    if (contribution.minor > available.minor) {
                      final shortfall = Money(
                        contribution.minor - available.minor,
                        cur,
                      );
                      setSheet(() => contributionError =
                          AppLocalizations.of(sheetCtx)!
                              .savingsExceedsCashBody(shortfall.text));
                      return;
                    }

                    final before = s.savedOn(goal).minor;
                    final inGoalCurrency =
                        contribution.inCurrency(goal.target.currency, s.rate);
                    final overBy =
                        before + inGoalCurrency.minor - goal.target.minor;
                    if (overBy > 0) {
                      final proceed = await showDialog<bool>(
                            context: sheetCtx,
                            builder: (dialogContext) => AlertDialog(
                              icon: Icon(Icons.flag_outlined,
                                  color: dialogContext.primary),
                              title: Text(AppLocalizations.of(dialogContext)!
                                  .goalOverfundTitle),
                              content: Text(AppLocalizations.of(dialogContext)!
                                  .goalOverfundBody(
                                      Money(overBy, goal.target.currency)
                                          .text)),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: Text(
                                      AppLocalizations.of(dialogContext)!
                                          .adjustAmount),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: Text(
                                      AppLocalizations.of(dialogContext)!
                                          .addAnyway),
                                ),
                              ],
                            ),
                          ) ??
                          false;
                      if (!proceed || !sheetCtx.mounted) return;
                    }

                    setSheet(() => submitting = true);
                    try {
                      s.contribute(goal, contribution, id: newUuid());
                      if (!sheetCtx.mounted) return;
                      Navigator.pop(sheetCtx);
                      if (before < goal.target.minor &&
                          s.savedOn(goal).minor >= goal.target.minor) {
                        celebrate(context); // G2: milestone moment
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!
                              .addedToGoal(goal.name)),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } finally {
                      if (sheetCtx.mounted) {
                        setSheet(() => submitting = false);
                      }
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
