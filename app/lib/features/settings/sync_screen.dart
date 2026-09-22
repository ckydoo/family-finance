import 'package:flutter/material.dart';

import '../../core/state/app_state.dart';
import '../../core/sync/outbox.dart' show OutboxOp;
import '../../core/sync/sync_engine.dart' show SyncStatus;
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';

/// Sync & data — the honest state of where this family's data lives.
///
/// Replaces the old "Backup — coming soon" placeholder: there is no separate
/// backup to turn on. Changes save on this device immediately and sync to the
/// family's cloud account (Supabase) whenever there is a connection. This
/// screen shows exactly that: connection, last sync, pending changes, and a
/// CSV export that is a real, user-controlled copy.
class SyncScreen extends StatelessWidget {
  const SyncScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final status = s.syncStatus;
    final last = s.lastSyncAt;
    final error = s.syncLastError;
    final host = s.syncHost;

    final (statusLabel, statusColor) = switch (status) {
      SyncStatus.syncing => (l.syncStateSyncing, Colors.blue),
      SyncStatus.error => (l.syncStateError, Colors.orange),
      SyncStatus.offline => (l.syncStateOffline, Colors.grey),
      SyncStatus.needsSignIn => (l.syncStateNeedsSignIn, Colors.deepPurple),
      SyncStatus.idle => (l.syncStateSaved, Colors.green),
      null => (l.syncStateSaved, Colors.green),
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.syncDataTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // ── status card ────────────────────────────────────────────
            MhuriCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration:
                            BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(statusLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton(
                        onPressed: () => s.syncNow(),
                        child: Text(l.syncNowBtn),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _row(l.syncLastSync,
                      last == null ? l.syncNever : fmtSyncTime(last)),
                  _row(l.syncPendingLabel,
                      s.pendingOps == 0 ? l.syncUpToDate : '${s.pendingOps}'),
                  if (error != null && error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${l.syncErrorLabel}: $error',
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.orange.shade800),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── parked changes: problems to resolve, never silent ──────
            FutureBuilder<List<OutboxOp>>(
              future: s.sync?.parked() ?? Future.value(const []),
              builder: (context, snap) {
                final parked = snap.data ?? const <OutboxOp>[];
                if (parked.isEmpty) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange, width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.syncProblemsTitle,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.orange.sh900)),
                      const SizedBox(height: 4),
                      Text(l.syncProblemsBody,
                          style: TextStyle(
                              fontSize: 12.5, color: context.inkSoft)),
                      const SizedBox(height: 8),
                      for (final op in parked)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const Icon(Icons.sync_problem,
                              size: 20, color: Colors.orange),
                          title: Text(_parkedTitle(l, op),
                              style: const TextStyle(fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                              '${l.syncTries(op.attempts)} · '
                              '${_fmt(DateTime.fromMillisecondsSinceEpoch(op.createdMs))}',
                              style: TextStyle(
                                  fontSize: 12, color: context.inkSoft)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: l.syncRetryThis,
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: () async {
                                  final engine = s.sync!;
                                  await engine.retryParked(op.rowId);
                                  await engine.syncNow(force: true);
                                },
                              ),
                              IconButton(
                                tooltip: l.syncDiscardThis,
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                onPressed: () => _confirmDiscard(context, s, op),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            // ── where the data lives ───────────────────────────────────
            MhuriCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.syncWhereTitle,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    host == null
                        ? l.syncNotConnected
                        : '${l.syncConnectedTo} $host',
                    style: TextStyle(fontSize: 13, color: context.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l.syncBackupNote,
                    style: TextStyle(fontSize: 13, color: context.inkSoft),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── your copy: CSV export ──────────────────────────────────
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.receipt_long, size: 20),
              title: Text(l.exportCsvSettings,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.ink)),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final l2 = AppLocalizations.of(context)!;
                final path = await s.exportCsv();
                messenger.showSnackBar(SnackBar(
                  content: Text(
                      path != null ? l2.exportedPath(path) : l2.exportReal),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(k, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text(v,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  String _fmt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)} ${_month(t.month)} ${t.year}, '
        '${two(t.hour)}:${two(t.minute)}';
  }

  String _month(int m) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  /// A parked change described with the user's own words (name/reason/note)
  /// and its kind — never a raw table name or UUID.
  String _parkedTitle(AppLocalizations l, OutboxOp op) {
    final kind = switch (op.entity) {
      'tx' => l.syncKindTx,
      'envelope' => l.syncKindEnvelope,
      'goal' => l.syncKindGoal,
      'list_item' => l.syncKindItem,
      'kid_request' => l.syncKindRequest,
      _ => l.syncKindOther,
    };
    final hint = (op.payload['name'] ??
            op.payload['reason'] ??
            op.payload['note'] ??
            '')
        .toString();
    return hint.isEmpty ? kind : '$kind · $hint';
  }

  Future<void> _confirmDiscard(
      BuildContext context, AppState s, OutboxOp op) async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.syncDiscardTitle),
        content: Text(l.syncDiscardBody(_parkedTitle(l, op))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.syncDiscardThis)),
        ],
      ),
    );
    if (ok == true) {
      await s.sync?.discardParked(op.rowId);
    }
  }
}
