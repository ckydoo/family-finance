import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/models/models.dart' show FamilyActivity, TxType;
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/when.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tx_tile.dart';
import '../../core/widgets/ui.dart';

/// Full transaction feed grouped by day (spec §7.4).
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActivityPeriod { all, today, sevenDays, thirtyDays }

class _ActivityScreenState extends State<ActivityScreen> {
  TxType? _type;
  String? _memberId;
  _ActivityPeriod _period = _ActivityPeriod.all;
  bool _searching = false;
  String _query = '';

  bool get _hasFilters =>
      _type != null || _memberId != null || _period != _ActivityPeriod.all;

  bool _inPeriod(DateTime value, DateTime now) {
    final local = value.toLocal();
    return switch (_period) {
      _ActivityPeriod.all => true,
      _ActivityPeriod.today => local.year == now.year &&
          local.month == now.month &&
          local.day == now.day,
      _ActivityPeriod.sevenDays =>
        local.isAfter(now.subtract(const Duration(days: 7))),
      _ActivityPeriod.thirtyDays =>
        local.isAfter(now.subtract(const Duration(days: 30))),
    };
  }

  void _clearFilters() {
    setState(() {
      _type = null;
      _memberId = null;
      _period = _ActivityPeriod.all;
    });
  }

  Future<void> _showFilters(BuildContext context, AppState state) async {
    var type = _type;
    var memberId = _memberId;
    var period = _period;
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Filter activity',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => setSheet(() {
                      type = null;
                      memberId = null;
                      period = _ActivityPeriod.all;
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Transaction type',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: type == null,
                    onSelected: (_) => setSheet(() => type = null),
                  ),
                  ChoiceChip(
                    label: const Text('Income'),
                    selected: type == TxType.income,
                    onSelected: (_) => setSheet(() => type = TxType.income),
                  ),
                  ChoiceChip(
                    label: const Text('Expenses'),
                    selected: type == TxType.expense,
                    onSelected: (_) => setSheet(() => type = TxType.expense),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String?>(
                initialValue: memberId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Family member'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Everyone'),
                  ),
                  for (final member in state.members)
                    DropdownMenuItem<String?>(
                      value: member.id,
                      child: Text(member.name),
                    ),
                ],
                onChanged: (value) => setSheet(() => memberId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<_ActivityPeriod>(
                initialValue: period,
                decoration: const InputDecoration(labelText: 'Date'),
                items: const [
                  DropdownMenuItem(
                      value: _ActivityPeriod.all, child: Text('All time')),
                  DropdownMenuItem(
                      value: _ActivityPeriod.today, child: Text('Today')),
                  DropdownMenuItem(
                      value: _ActivityPeriod.sevenDays,
                      child: Text('Last 7 days')),
                  DropdownMenuItem(
                      value: _ActivityPeriod.thirtyDays,
                      child: Text('Last 30 days')),
                ],
                onChanged: (value) {
                  if (value != null) setSheet(() => period = value);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      _type = type;
                      _memberId = memberId;
                      _period = period;
                    });
                    Navigator.pop(sheetContext);
                  },
                  child: const Text('Apply filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final now = DateTime.now();
    final query = _query.trim().toLowerCase();
    final activities = s.activityFeed.where((activity) {
      if (activity.action.startsWith('contribution.') ||
          activity.action.startsWith('contribution_campaign.')) {
        return false;
      }
      if (_memberId != null && activity.actorId != _memberId) return false;
      if (!_inPeriod(activity.at, now)) return false;
      final searchable = [
        activity.action,
        activity.entity,
        ...activity.detail.values.map((value) => '$value'),
      ].join(' ').toLowerCase();
      if (query.isNotEmpty && !searchable.contains(query)) {
        return false;
      }
      if (_type != null) {
        if (activity.entity != 'transaction') return false;
        final tx = s.txs.where((t) => t.id == activity.entityId).firstOrNull;
        if (tx == null || tx.type != _type) return false;
      }
      return true;
    });
    final rows = <Object>[];
    String? lastDay;
    for (final activity in activities) {
      final day = fmtDay(activity.at);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(activity);
    }

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Search activity', border: InputBorder.none),
                onChanged: (value) => setState(() => _query = value),
              )
            : Text(AppLocalizations.of(context)!.activityTitle),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search activity',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
          IconButton(
            tooltip: 'Filter activity',
            onPressed: () => _showFilters(context, s),
            icon: Badge(
              isLabelVisible: _hasFilters,
              child: Icon(
                _hasFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => s.refresh(),
          child: rows.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
                  children: [
                    if (_hasFilters) ...[
                      const EmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No matching activity',
                        subtitle: 'Try changing or clearing your filters.',
                      ),
                      Center(
                        child: TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear filters'),
                        ),
                      ),
                    ] else
                      EmptyState(
                        icon: Icons.receipt_long,
                        title: AppLocalizations.of(context)!.noActivityTitle,
                        subtitle: AppLocalizations.of(context)!.noActivityHint,
                      ),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    if (row is String) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 8),
                        child: Text(
                          row,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.inkSoft,
                          ),
                        ),
                      );
                    }
                    final activity = row as FamilyActivity;
                    if (activity.entity == 'transaction') {
                      final tx = s.txs
                          .where((t) => t.id == activity.entityId)
                          .firstOrNull;
                      if (tx != null) {
                        return TxTile(tx: tx, dense: true, surface: false);
                      }
                    }
                    return _FamilyActivityTile(activity: activity);
                  },
                ),
        ),
      ),
    );
  }
}

class _FamilyActivityTile extends StatelessWidget {
  const _FamilyActivityTile({required this.activity});
  final FamilyActivity activity;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final actor = state.member(activity.actorId)?.name ??
        (activity.actorId == state.realUser.id
            ? state.realUser.name
            : 'Family');
    final tx = activity.entity == 'transaction'
        ? state.txs.where((t) => t.id == activity.entityId).firstOrNull
        : null;
    final goalId = activity.detail['goal_id']?.toString();
    final goal = goalId == null ? null : state.goal(goalId);
    final campaignId = activity.detail['campaign_id']?.toString();
    final campaign = campaignId == null
        ? null
        : state.contributionCampaigns
            .where((c) => c.id == campaignId)
            .firstOrNull;
    final debtId = activity.detail['debt_id']?.toString();
    final debt = debtId == null
        ? null
        : state.familyDebts.where((d) => d.id == debtId).firstOrNull;
    final amountMinor = (activity.detail['amount_minor'] as num?)?.toInt();
    final currencyCode = activity.detail['currency']?.toString();
    final currency = Currency.values
        .where((c) => c.code.toLowerCase() == currencyCode?.toLowerCase())
        .firstOrNull;
    final amount = amountMinor == null || currency == null
        ? null
        : Money(amountMinor, currency);

    final (icon, title, subtitle, color) = switch (activity.action) {
      'tx.create' when tx?.type == TxType.income => (
          Icons.savings_outlined,
          '$actor recorded income',
          tx?.note ?? 'Money added to the family pool',
          context.incomeGreen,
        ),
      'tx.create' => (
          Icons.receipt_long_outlined,
          '$actor recorded an expense',
          tx?.note ?? 'Family spending',
          context.expenseRed,
        ),
      'tx.update' => (
          Icons.edit_outlined,
          '$actor edited a transaction',
          tx?.note ?? 'Transaction updated',
          context.primary,
        ),
      'tx.delete' => (
          Icons.delete_outline,
          '$actor deleted a transaction',
          'The audit record has been retained',
          context.expenseRed,
        ),
      'envelope.create' => (
          Icons.account_balance_wallet_outlined,
          '$actor created a budget',
          activity.detail['name']?.toString() ?? 'Budget created',
          context.primary,
        ),
      'envelope.update' => (
          Icons.edit_note_outlined,
          '$actor updated a budget',
          activity.detail['name']?.toString() ?? 'Budget updated',
          context.primary,
        ),
      'envelope.archive' => (
          Icons.archive_outlined,
          '$actor archived a budget',
          activity.detail['name']?.toString() ?? 'Budget archived',
          context.expenseRed,
        ),
      'member.role_change' => (
          Icons.admin_panel_settings_outlined,
          '$actor changed a member role',
          '${activity.detail['from'] ?? 'member'} → ${activity.detail['to'] ?? 'member'}',
          context.primary,
        ),
      'goal.contribute' => (
          Icons.flag_outlined,
          '$actor contributed to ${goal?.name ?? 'a savings goal'}',
          'Savings contribution',
          context.primary,
        ),
      'goal.create' => (
          Icons.flag_outlined,
          '$actor created a savings goal',
          activity.detail['name']?.toString() ?? 'Savings goal',
          context.primary,
        ),
      'goal.update' => (
          Icons.edit_outlined,
          '$actor updated a savings goal',
          activity.detail['name']?.toString() ?? 'Savings goal',
          context.primary,
        ),
      'contribution_campaign.create' => (
          Icons.volunteer_activism_outlined,
          '$actor created a family contribution',
          activity.detail['name']?.toString() ?? 'Family contribution',
          context.primary,
        ),
      'contribution_campaign.update' => (
          Icons.edit_outlined,
          '$actor updated a family contribution',
          activity.detail['name']?.toString() ?? 'Family contribution',
          context.primary,
        ),
      'contribution.pledge' => (
          Icons.volunteer_activism_outlined,
          '$actor pledged to ${campaign?.name ?? 'a family contribution'}',
          'Pledge recorded',
          context.primary,
        ),
      'contribution.payment' => (
          Icons.payments_outlined,
          '$actor contributed to ${campaign?.name ?? 'a family contribution'}',
          'Payment received',
          context.incomeGreen,
        ),
      'debt.repayment' => (
          Icons.handshake_outlined,
          '$actor recorded a repayment',
          debt?.name ?? 'Debt repayment',
          context.incomeGreen,
        ),
      'family_debt.create' => (
          Icons.handshake_outlined,
          '$actor added a debt',
          activity.detail['name']?.toString() ?? 'Debt or money owed',
          context.primary,
        ),
      'family_debt.update' => (
          Icons.edit_outlined,
          '$actor updated a debt',
          activity.detail['name']?.toString() ?? 'Debt or money owed',
          context.primary,
        ),
      'family_debt.archive' => (
          Icons.delete_outline,
          '$actor deleted a debt',
          activity.detail['name']?.toString() ?? 'Debt or money owed',
          context.expenseRed,
        ),
      'plan.close' || 'budget_plan.close' => (
          Icons.event_available_outlined,
          '$actor closed the monthly plan',
          activity.detail['cycle_start']?.toString() ?? 'Monthly plan',
          context.primary,
        ),
      'plan.save' || 'budget_plan.save' => (
          Icons.event_note_outlined,
          '$actor updated the monthly plan',
          activity.detail['cycle_start']?.toString() ?? 'Monthly plan',
          context.primary,
        ),
      'request.approve' => (
          Icons.check_circle_outline,
          '$actor approved a request',
          'Family request',
          context.incomeGreen,
        ),
      'request.decline' => (
          Icons.cancel_outlined,
          '$actor declined a request',
          'Family request',
          context.expenseRed,
        ),
      'shopping.item_add' => (
          Icons.add_shopping_cart_outlined,
          '$actor added ${activity.detail['name'] ?? 'an item'}',
          'Shopping list',
          context.primary,
        ),
      'shopping.item_done' => (
          Icons.shopping_bag_outlined,
          '$actor bought ${activity.detail['qty'] ?? 1} × ${activity.detail['name'] ?? 'shopping item'}',
          'Marked as bought',
          context.incomeGreen,
        ),
      'shopping.item_update' => (
          Icons.edit_note_outlined,
          '$actor updated ${activity.detail['name'] ?? 'a shopping item'}',
          'Shopping list',
          context.primary,
        ),
      'family.join' || 'member.join' => (
          Icons.person_add_alt_1_outlined,
          '$actor joined the family',
          'Family membership',
          context.primary,
        ),
      'task.create' => (
          Icons.add_task_outlined,
          '$actor created a family task',
          activity.detail['title']?.toString() ?? 'Family task',
          context.primary,
        ),
      'task.update' => (
          Icons.edit_calendar_outlined,
          '$actor updated a family task',
          activity.detail['title']?.toString() ?? 'Family task',
          context.primary,
        ),
      'task.complete' => (
          Icons.task_alt,
          '$actor completed a family task',
          activity.detail['title']?.toString() ?? 'Family task',
          context.incomeGreen,
        ),
      'task.archive' => (
          Icons.archive_outlined,
          '$actor archived a family task',
          activity.detail['title']?.toString() ?? 'Family task',
          context.expenseRed,
        ),
      'chat.send' => (
          Icons.chat_bubble_outline,
          '$actor sent a family message',
          'Family chat',
          context.primary,
        ),
      'chat.update' => (
          Icons.edit_outlined,
          '$actor edited a family message',
          'Family chat',
          context.primary,
        ),
      'chat.delete' => (
          Icons.delete_outline,
          '$actor deleted a family message',
          'Message content is not included in the audit feed',
          context.expenseRed,
        ),
      'chore.create' || 'chore.update' => (
          Icons.stars_outlined,
          '$actor updated points and rewards',
          activity.detail['name']?.toString() ?? 'Points and rewards',
          context.primary,
        ),
      'earning.create' || 'earning.update' => (
          Icons.emoji_events_outlined,
          '$actor updated a teen earning',
          activity.detail['name']?.toString() ?? 'Teen earning',
          context.primary,
        ),
      'mukando.configure' || 'mukando.create' || 'mukando.update' => (
          Icons.groups_outlined,
          '$actor configured Mukando',
          '${activity.detail['name'] ?? 'Family Mukando'} • ${activity.detail['members_count'] ?? ''} members',
          context.primary,
        ),
      'mukando.pay' => (
          Icons.payments_outlined,
          '$actor recorded a Mukando contribution',
          '${activity.detail['member_name'] ?? 'Member'} paid round ${activity.detail['round'] ?? ''}',
          context.incomeGreen,
        ),
      'mukando.undo_pay' => (
          Icons.undo_outlined,
          '$actor unrecorded a payment',
          'Payment removed for round ${activity.detail['round'] ?? ''}',
          context.expenseRed,
        ),
      'mukando.collect' => (
          Icons.celebration_outlined,
          'Round ${activity.detail['round'] ?? ''} completed',
          '${activity.detail['collector'] ?? 'Collector'} collected the round pot',
          context.primary,
        ),
      'mukando.undo_round' => (
          Icons.history_outlined,
          '$actor reverted a Mukando round',
          'Reverted to round ${activity.detail['round'] ?? ''}',
          context.expenseRed,
        ),
      'shopping.list_create' => (
          Icons.playlist_add,
          '$actor created a shopping list',
          activity.detail['name']?.toString() ?? 'Shopping list',
          context.primary,
        ),
      'shopping.list_update' || 'shopping.list_delete' => (
          Icons.playlist_add_check,
          '$actor updated a shopping list',
          activity.detail['name']?.toString() ?? 'Shopping list',
          context.primary,
        ),
      'profile.update' => (
          Icons.manage_accounts_outlined,
          '$actor updated their profile',
          activity.detail['name']?.toString() ?? 'Member profile',
          context.primary,
        ),
      _ => (
          Icons.history,
          '$actor updated the family',
          activity.action.replaceAll('.', ' '),
          context.primary,
        ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showActivityDetails(
          context,
          state,
          activity,
          actor,
          title,
          subtitle,
          amount,
          icon,
          color,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.hairline))),
          child: Row(children: [
            SizedBox(width: 42, height: 42, child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.ink)),
                  const SizedBox(height: 2),
                  Text('$subtitle · ${fmtWhen(activity.at)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.inkSoft)),
                ])),
            if (amount != null) ...[
              const SizedBox(width: 8),
              Text(amount.text,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            ],
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                size: 16, color: context.inkSoft.withValues(alpha: 0.45)),
          ]),
        ),
      ),
    );
  }

  void _showActivityDetails(
    BuildContext context,
    AppState state,
    FamilyActivity activity,
    String actor,
    String title,
    String subtitle,
    Money? amount,
    IconData icon,
    Color color,
  ) {
    showMhuriSheet<void>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Activity details',
        subtitle: fmtWhen(activity.at),
        footer: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: const Text('Close'),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.track,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _activityRow(
                sheetContext, 'Action', activity.action.replaceAll('.', ' ')),
            _activityRow(sheetContext, 'Performed by', actor),
            if (amount != null)
              _activityRow(sheetContext, 'Amount', amount.text),
            for (final entry in activity.detail.entries)
              if (entry.value != null && entry.value.toString().isNotEmpty)
                _activityRow(
                  sheetContext,
                  _formatKey(entry.key),
                  entry.value.toString(),
                ),
            _activityRow(
              sheetContext,
              'Timestamp',
              DateFormat.yMMMd().add_jms().format(activity.at.toLocal()),
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatKey(String key) {
    if (key.isEmpty) return key;
    final words = key.replaceAll('_', ' ').split(' ');
    return words
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static Widget _activityRow(BuildContext context, String label, String value,
      {bool showDivider = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: context.hairline))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.inkSoft,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
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
