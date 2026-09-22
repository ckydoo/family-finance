import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/money/money.dart';
import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/motion.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/ring_progress.dart';

/// Savings goals, kid jars and the savings-circle tracker (spec Module E, §7.5).
class SavingsScreen extends StatelessWidget {
  const SavingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final familyGoals = s.goals.where((g) => !g.isKidJar).toList();
    final kidGoals = s.goals.where((g) => g.isKidJar).toList();
    final m = s.circle;

    return SafeArea(
      child: RefreshIndicator(
          onRefresh: () => s.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
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
              const SizedBox(height: 16),
              if (familyGoals.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EmptyState(
                    icon: Icons.track_changes,
                    title: AppLocalizations.of(context)!.noGoals,
                    subtitle: AppLocalizations.of(context)!.noGoalsHint,
                  ),
                ),
              if (familyGoals.isEmpty) ...[
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
              Text(
                "Kids' jars",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)!.starsHome(s.stars),
                style: TextStyle(fontSize: 12, color: context.inkSoft),
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
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFE3F7),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
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
                        'Round ${m.currentRound} of ${m.totalRounds} — '
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
                          s.circleCollect();
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

  void _newGoalSheet(BuildContext context) {
    final s = AppScope.of(context);
    var goalName = '';
    var targetText = '';
    var currency = Currency.usd;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: context.track,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  AppLocalizations.of(context)!.newSavingsGoal,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (value) => goalName = value,
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
                  onChanged: (value) => targetText = value,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.targetAmount,
                    prefixText: '${currency.symbol} ',
                    filled: true,
                    fillColor: context.card,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('USD'),
                      selected: currency == Currency.usd,
                      onSelected: (_) =>
                          setSheetState(() => currency = Currency.usd),
                    ),
                    ChoiceChip(
                      label: const Text('ZiG'),
                      selected: currency == Currency.zwg,
                      onSelected: (_) =>
                          setSheetState(() => currency = Currency.zwg),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    final parsed = double.tryParse(
                      targetText.trim().replaceAll(',', ''),
                    );
                    if (goalName.trim().isEmpty ||
                        parsed == null ||
                        parsed <= 0) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context)!.goalNameAmountFirst,
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    s.addGoal(
                      name: goalName,
                      target: Money.fromMajor(parsed, currency),
                    );
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.createGoal),
                ),
              ],
            ),
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
                  '${saved.text} of ${goal.target.text}'
                  '${goal.autoSave != null ? ' · ${goal.autoSave}' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.inkSoft),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  void _contribute(BuildContext context) {
    final s = AppScope.of(context);
    Currency cur = goal.target.currency;
    final controller = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheet) => SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            decoration: BoxDecoration(
              color: context.bg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.addToGoal(goal.name),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.ink,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                    ChoiceChip(
                      label: const Text('USD'),
                      selected: cur == Currency.usd,
                      onSelected: (_) => setSheet(() => cur = Currency.usd),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('ZiG'),
                      selected: cur == Currency.zwg,
                      onSelected: (_) => setSheet(() => cur = Currency.zwg),
                    ),
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context)!
                          .goalBase(goal.target.currency.short),
                      style: TextStyle(fontSize: 12, color: context.inkSoft),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    final v =
                        double.tryParse(controller.text.replaceAll(',', ''));
                    if (v == null || v <= 0) return;
                    final before = s.savedOn(goal).minor;
                    s.contribute(goal, Money.fromMajor(v, cur));
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
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.primary,
                    foregroundColor: context.onSolid,
                    minimumSize: const Size.fromHeight(50),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(AppLocalizations.of(context)!.saveContribution),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
