import 'package:flutter/material.dart';

import '../../core/models/models.dart' show Tx;
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/when.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/tx_tile.dart';

/// Full transaction feed grouped by day (spec §7.4).
class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final rows = <Object>[];
    String? lastDay;
    for (final t in s.txs) {
      final day = fmtDay(t.when);
      if (day != lastDay) {
        rows.add(day);
        lastDay = day;
      }
      rows.add(t);
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.activityTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => s.refresh(),
          child: rows.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 44, 20, 24),
                  children: [
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
