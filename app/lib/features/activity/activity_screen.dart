import 'package:flutter/material.dart';

import '../../core/models/models.dart' show Tx, TxType;
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/when.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tx_tile.dart';

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
      backgroundColor: context.bg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
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
    final transactions = s.txs.where((transaction) {
      if (_type != null && transaction.type != _type) return false;
      if (_memberId != null && transaction.memberId != _memberId) return false;
      return _inPeriod(transaction.when, now);
    });
    final rows = <Object>[];
    String? lastDay;
    for (final t in transactions) {
      final day = fmtDay(t.when);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(t);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.activityTitle),
        actions: [
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
                            fontWeight: FontWeight.w800,
                            color: context.inkSoft,
                          ),
                        ),
                      );
                    }
                    return TxTile(
                      tx: row as Tx,
                      dense: true,
                      surface: false,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
