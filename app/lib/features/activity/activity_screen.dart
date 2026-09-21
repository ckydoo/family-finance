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
    final groups = <String, List<Tx>>{};
    for (final t in s.txs) {
      groups.putIfAbsent(fmtDay(t.when), () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.activityTitle)),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: () => s.refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.receipt_long,
                  title: AppLocalizations.of(context)!.noActivityTitle,
                  subtitle: AppLocalizations.of(context)!.noActivityHint,
                ),
              ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.inkSoft,
                  ),
                ),
              ),
              for (final t in entry.value)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TxTile(tx: t, dense: true),
                ),
            ],
          ],
        )),
      ),
    );
  }
}
