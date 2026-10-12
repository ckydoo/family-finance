import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ring_progress.dart';
import '../budgets/budgets_screen.dart';
import '../savings/savings_screen.dart';

/// Family Meeting (spec I4) - a guided 15-minute monthly agenda the couple
/// walks through together. The note they agree on is saved on-device.
class FamilyMeetingScreen extends StatefulWidget {
  const FamilyMeetingScreen({super.key});

  @override
  State<FamilyMeetingScreen> createState() => _FamilyMeetingScreenState();
}

class _FamilyMeetingScreenState extends State<FamilyMeetingScreen> {
  final _note = TextEditingController();
  bool _saved = false;
  List<({String date, String note})> _notes = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadNotes());
  }

  Future<void> _loadNotes() async {
    final notes = await AppScope.of(context).meetingNotes();
    if (mounted) setState(() => _notes = notes);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveNote(AppState s) async {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    // kv persist via the state's store (fire-and-forget).
    s.saveLocalNote('meeting_note_$stamp', _note.text.trim());
    final notes = await s.meetingNotes();
    if (mounted) {
      setState(() {
        _saved = true;
        _notes = notes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.meetingTitle)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final l = AppLocalizations.of(context)!;
            const pad = EdgeInsets.fromLTRB(20, 4, 20, 28);
            final left = <Widget>[
              Text(
                l.meetingHint,
                style: TextStyle(fontSize: 13, color: context.inkSoft),
              ),
              const SizedBox(height: 16),
              // ── Step 1 - recap ─────────────────────────────────────────
              _step(
                n: 1,
                title: l.mFigures,
                child: Row(
                  children: [
                    _figure(l.figureIncome, s.monthIncome.text,
                        context.incomeGreen),
                    _figure(
                        l.figureSpent, s.monthSpend.text, context.expenseRed),
                    _figure(l.figureSaved, s.monthSaved.text, context.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Step 2 - envelopes ─────────────────────────────────────
              _step(
                n: 2,
                title: l.mEnvelopeHealth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      RingProgress(
                        value: s.envelopeHealth,
                        size: 60,
                        stroke: 8,
                        color: s.envelopeHealth >= 0.7
                            ? context.primary
                            : context.accent,
                        child: Text(
                          '${(s.envelopeHealth * 100).round()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          l.mReachedTalk,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.inkSoft,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const BudgetsScreen(standalone: true),
                            ),
                          ),
                          icon: const Icon(Icons.tune, size: 17),
                          label: const Text('Review budgets'),
                        ),
                        if (s.currentBudgetPlan == null &&
                            s.previousBudgetPlan != null &&
                            s.canEditBudgets)
                          FilledButton.icon(
                            onPressed: () {
                              s.useLastMonthPlan();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Last month’s plan is ready to review.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.content_copy_outlined,
                                size: 17),
                            label: const Text('Use last month'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ];
            final right = <Widget>[
              // ── Step 3 - goals ─────────────────────────────────────────
              _step(
                n: 3,
                title: l.mGoals,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final g in s.goals.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              iconForKey(g.emoji) ?? kFallbackSemanticIcon,
                              size: 17,
                              color: context.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                g.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.ink,
                                ),
                              ),
                            ),
                            Text(
                              '${s.savedOn(g).text} / ${g.target.text}',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SavingsScreen(
                            standalone: true,
                            initialSection: SavingsSection.goals,
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.track_changes, size: 17),
                      label: const Text('Review goals'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // ── Step 4 - kids & requests ─────────────────────────────
              _step(
                n: 4,
                title: l.mChores,
                child: _familyDecisions(context, s, l),
              ),
              if (_notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                _step(
                  n: 6,
                  title: 'Previous commitments',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final note in _notes.take(4))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${note.date} · ${note.note}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.inkSoft,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // ── Step 5 - one improvement ─────────────────────────────
              _step(
                n: 5,
                title: l.mImprove,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _note,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: l.meetingNoteHint,
                        filled: true,
                        fillColor: context.card,
                        border: const OutlineInputBorder(
                            borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _saveNote(s),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primary,
                            foregroundColor: context.onSolid,
                            shape:
                                RoundedRectangleBorder(borderRadius: kBRadiusM),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(l.meetingSaveNote),
                        ),
                        if (_saved) ...[
                          const SizedBox(width: 10),
                          Text(
                            l.savedTick,
                            style: TextStyle(
                              color: context.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.ink,
                  foregroundColor: context.onSolid,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
                ),
                child: Text(
                  l.meetingDone,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ];
            if (box.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: ListView(padding: pad, children: left)),
                  const VerticalDivider(width: 1, thickness: 1),
                  Expanded(child: ListView(padding: pad, children: right)),
                ],
              );
            }
            return ListView(
              padding: pad,
              children: [...left, const SizedBox(height: 12), ...right],
            );
          },
        ),
      ),
    );
  }

  Widget _step(
          {required int n, required String title, required Widget child}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.successSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.primary,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _figure(String label, String value, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: context.inkSoft)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _familyDecisions(
    BuildContext context,
    AppState s,
    AppLocalizations l,
  ) {
    final requests =
        s.requests.where((r) => r.state == RequestState.pending).toList();
    final proposals =
        s.proposals.where((p) => p.state == RequestState.pending).toList();
    if (requests.isEmpty && proposals.isEmpty) {
      return Text(
        l.mChoresLine(s.stars, 0, 0),
        style: TextStyle(fontSize: 12.5, color: context.inkSoft),
      );
    }
    return Column(
      children: [
        for (final request in requests)
          _decisionRow(
            title:
                '${s.member(request.kidId)?.name ?? 'Child'} · ${request.amount.text}',
            subtitle: request.reason,
            onDecline: s.canApprove
                ? () => setState(() => s.declineRequest(request))
                : null,
            onApprove: s.canApprove
                ? () => setState(() => s.approveRequest(request))
                : null,
          ),
        for (final proposal in proposals)
          _decisionRow(
            title:
                '${s.member(proposal.teenId)?.name ?? 'Teen'} · ${proposal.amount.text}',
            subtitle: proposal.reason,
            onDecline: s.canApprove
                ? () => setState(() => s.declineProposal(proposal))
                : null,
            onApprove: s.canApprove
                ? () => setState(() => s.approveProposal(proposal))
                : null,
          ),
      ],
    );
  }

  Widget _decisionRow({
    required String title,
    required String subtitle,
    required VoidCallback? onDecline,
    required VoidCallback? onApprove,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: context.ink)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: context.inkSoft)),
                ],
              ),
            ),
            TextButton(onPressed: onDecline, child: const Text('Decline')),
            FilledButton(onPressed: onApprove, child: const Text('Approve')),
          ],
        ),
      );
}
