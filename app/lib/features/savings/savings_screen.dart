import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

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

    return SafeArea(
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
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.ink),
                    ),
                  ),
                  if (familyGoals.isNotEmpty)
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.newSavingsGoal,
                      onPressed: () => _newGoalSheet(context),
                      icon: Icon(Icons.add_circle,
                          color: context.primary, size: 30),
                    ),
                ],
              ),
              Text(
                'Save towards the things that matter to your family.',
                style: TextStyle(fontSize: 13, color: context.inkSoft),
              ),
              const SizedBox(height: 16),
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
                        onPressed: () => _newGoalSheet(
                          context,
                          initialName: idea == 'Other' ? '' : idea,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _newGoalSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(AppLocalizations.of(context)!.createSavingsGoal),
                ),
                const SizedBox(height: 12),
              ],
              for (final g in familyGoals) ...[
                GoalCard(goal: g),
                const SizedBox(height: 12),
              ],

              // ── Kid jars ────────────────────────────────────────────────────
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.kidsJars,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: context.ink),
                    ),
                  ),
                  if (s.canEditBudgets && kidsWithoutJar.isNotEmpty)
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.addKidWish,
                      onPressed: () => _newGoalSheet(
                        context,
                        kidJarMembers: kidsWithoutJar,
                      ),
                      icon: Icon(Icons.add_circle,
                          color: context.primary, size: 28),
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
                    borderRadius: BorderRadius.circular(20),
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
                                fontWeight: FontWeight.w800,
                                color: context.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Round ${m.currentRound} of ${m.totalRounds} - '
                        '${m.nextCollector} collects ${m.contribution.text}',
                        style: TextStyle(fontSize: 13, color: context.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.memberPot(
                            s.hideAmounts ? '•••••' : m.potSoFar.text,
                            m.contribution.text,
                            m.order.length),
                        style: TextStyle(fontSize: 12, color: context.inkSoft),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: m.progress,
                          minHeight: 8,
                          backgroundColor: context.track,
                          color: context.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: () {
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
                                label: AppLocalizations.of(context)!.undo,
                                onPressed: s.undoCircleCollect,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.primary,
                          foregroundColor: context.onSolid,
                          minimumSize: const Size.fromHeight(46),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(AppLocalizations.of(context)!.markRound),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          AppLocalizations.of(context)!.recordsOnly,
                          style:
                              TextStyle(fontSize: 11, color: context.inkSoft),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          )),
    );
  }

  void _newGoalSheet(
    BuildContext context, {
    List<Member> kidJarMembers = const [],
    String initialName = '',
  }) {
    final s = AppScope.of(context);
    final isKidJar = kidJarMembers.isNotEmpty;
    Member? selectedKid = isKidJar ? kidJarMembers.first : null;
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
                DropdownButtonFormField<Member>(
                  initialValue: selectedKid,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.childLabel,
                  ),
                  items: [
                    for (final member in kidJarMembers)
                      DropdownMenuItem(value: member, child: Text(member.name)),
                  ],
                  onChanged: (value) =>
                      setSheetState(() => selectedKid = value),
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
                    ownerMemberId: selectedKid?.id,
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

class GoalCard extends StatelessWidget {
  final Goal goal;
  final bool kidFlavored;

  const GoalCard({super.key, required this.goal, this.kidFlavored = false});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final saved = s.savedOn(goal);
    final ratio =
        goal.target.minor <= 0 ? 0.0 : saved.minor / goal.target.minor;
    final ringColor = kidFlavored
        ? context.accent
        : ratio < 0.35
            ? context.accent
            : context.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kidFlavored ? const Color(0xFFFDF6E3) : context.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          RingProgress(
            value: ratio,
            size: 56,
            color: ringColor,
            child: Icon(
              iconForKey(goal.emoji) ?? Icons.flag,
              size: 21,
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
                    fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => _contribute(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: context.onSolid,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Add'),
              ),
              if (s.canEditBudgets)
                PopupMenuButton<String>(
                  tooltip: 'Savings goal actions',
                  onSelected: (action) => _goalAction(context, s, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'edit', child: Text('Edit goal')),
                    if (goal.status != 'done')
                      const PopupMenuItem(
                          value: 'complete', child: Text('Mark as completed')),
                    if (s.canAdmin)
                      const PopupMenuItem(
                          value: 'archive', child: Text('Archive goal')),
                  ],
                ),
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
                      fontSize: 26, fontWeight: FontWeight.w800),
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
