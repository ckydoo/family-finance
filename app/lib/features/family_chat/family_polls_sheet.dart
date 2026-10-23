import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../settings/plus_screen.dart';

Future<void> showFamilyPollsSheet(BuildContext context, AppState state) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _FamilyPollsSheet(state: state),
  );
}

class _FamilyPollsSheet extends StatefulWidget {
  const _FamilyPollsSheet({required this.state});
  final AppState state;

  @override
  State<_FamilyPollsSheet> createState() => _FamilyPollsSheetState();
}

class _FamilyPollsSheetState extends State<_FamilyPollsSheet> {
  List<Map<String, Object?>> _polls = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  final Map<String, Set<int>> _selectedOptions = {};

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final engine = state.sync;
    if (engine == null) {
      if (mounted) setState(() { _loading = false; _error = 'Connect to your family to view polls.'; });
      return;
    }
    try {
      final polls = await engine.fetchFamilyChatPolls();
      if (mounted) setState(() { _polls = polls; _error = null; });
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createPoll() async {
    final question = TextEditingController();
    final options = [TextEditingController(), TextEditingController()];
    var allowMultiple = false;
    DateTime? closesAt;
    String? validationError;
    final result = await showDialog<(String, List<String>, bool, DateTime?)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create a family poll'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: question, maxLength: 240,
                  decoration: const InputDecoration(labelText: 'Question')),
              for (var i = 0; i < options.length; i++)
                TextField(controller: options[i], maxLength: 80,
                    decoration: InputDecoration(labelText: 'Option ${i + 1}')),
              if (options.length < 6)
                Align(alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => setDialogState(() => options.add(TextEditingController())),
                    icon: const Icon(Icons.add), label: const Text('Add option'),
                  )),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow multiple choices'),
                value: allowMultiple,
                onChanged: (value) => setDialogState(() => allowMultiple = value),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setDialogState(() => closesAt = picked.add(const Duration(days: 1)));
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(closesAt == null ? 'Optional close date' : 'Closes ${closesAt!.subtract(const Duration(days: 1)).month}/${closesAt!.subtract(const Duration(days: 1)).day}/${closesAt!.subtract(const Duration(days: 1)).year}'),
              ),
              if (validationError != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(validationError!,
                      style: TextStyle(color: context.danger)),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final cleanQuestion = question.text.trim();
                final cleanOptions = options.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
                final normalized = cleanOptions
                    .map((value) => value.toLowerCase())
                    .toSet();
                if (cleanQuestion.isEmpty) {
                  setDialogState(() => validationError = 'Enter a question.');
                  return;
                }
                if (cleanOptions.length < 2) {
                  setDialogState(() => validationError = 'Enter at least two options.');
                  return;
                }
                if (normalized.length != cleanOptions.length) {
                  setDialogState(() => validationError = 'Poll options must be unique.');
                  return;
                }
                Navigator.pop(dialogContext, (cleanQuestion, cleanOptions, allowMultiple, closesAt));
              },
              child: const Text('Create poll'),
            ),
          ],
        ),
      ),
    );
    question.dispose();
    for (final option in options) { option.dispose(); }
    if (result == null || !mounted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await state.sync!.createFamilyChatPoll(
        question: result.$1,
        options: result.$2,
        allowMultiple: result.$3,
        closesAt: result.$4,
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _vote(String pollId, List<int> choices) async {
    setState(() { _busy = true; _error = null; });
    try {
      await state.sync!.voteFamilyChatPoll(pollId, choices);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closePoll(String pollId) async {
    setState(() => _busy = true);
    try {
      await state.sync!.closeFamilyChatPoll(pollId);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPlus = state.hasPlusFeature('family_polls_pins');
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .86),
        decoration: BoxDecoration(color: context.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 42, height: 4, decoration: BoxDecoration(color: context.hairline, borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: Text('Family polls', style: TextStyle(color: context.ink, fontSize: 18, fontWeight: FontWeight.w800))),
            if (hasPlus)
              IconButton(onPressed: _busy ? null : _createPoll, tooltip: 'Create poll', icon: const Icon(Icons.add_circle_outline)),
            IconButton(onPressed: () => Navigator.pop(context), tooltip: 'Close', icon: const Icon(Icons.close)),
          ]),
          if (!hasPlus)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(children: [
                Text('Polls are a Plus feature. Existing family chat stays free.', style: TextStyle(color: context.inkSoft)),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlusScreen()));
                  },
                  icon: const Icon(Icons.workspace_premium_outlined), label: const Text('Explore Plus'),
                ),
              ]),
            ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: TextStyle(color: context.danger)),
          ),
          if (_busy) const LinearProgressIndicator(),
          Flexible(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _polls.isEmpty
                    ? Center(child: Text(hasPlus ? 'No polls yet. Ask your family a question.' : 'No family polls yet.', style: TextStyle(color: context.inkSoft)))
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _polls.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) => _pollCard(context, _polls[index]),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _pollCard(BuildContext context, Map<String, Object?> poll) {
    final id = poll['id']?.toString() ?? '';
    final question = poll['question']?.toString() ?? '';
    final options = (poll['options'] as List? ?? const []).map((e) => e.toString()).toList();
    final myVotes = (poll['my_votes'] as List? ?? const []).map((e) => int.tryParse(e.toString())).whereType<int>().toSet();
    final countsRaw = poll['counts'];
    final counts = countsRaw is Map ? countsRaw : const {};
    final closed = poll['closed_at'] != null ||
        (DateTime.tryParse(poll['closes_at']?.toString() ?? '')?.isBefore(DateTime.now()) ?? false);
    final allowMultiple = poll['allow_multiple'] == true;
    final pending = _selectedOptions[id] ?? myVotes;
    final totalVotes = counts.values.fold<int>(
      0,
      (sum, v) => sum + (int.tryParse(v.toString()) ?? 0),
    );
    final creator = poll['created_by']?.toString();
    final canClose = creator == state.realUser.id ||
        {Role.owner, Role.admin, Role.adult}.contains(state.authRole);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.hairline)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question, style: TextStyle(color: context.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (var i = 0; i < options.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              pending.contains(i)
                  ? Icons.check_circle
                  : allowMultiple ? Icons.circle_outlined : Icons.radio_button_unchecked,
              size: 19,
              color: pending.contains(i) ? context.primary : context.inkSoft,
            ),
            title: Text(options[i]),
            trailing: Text(
              totalVotes > 0
                  ? '${counts[i.toString()] ?? 0} (${(((int.tryParse((counts[i.toString()] ?? 0).toString()) ?? 0) * 100) / totalVotes).round()}%)'
                  : '${counts[i.toString()] ?? 0}',
            ),
            onTap: closed || _busy
                ? null
                : () {
                    if (allowMultiple) {
                      setState(() {
                        final selected = _selectedOptions.putIfAbsent(
                          id,
                          () => Set<int>.from(myVotes),
                        );
                        if (!selected.add(i)) selected.remove(i);
                      });
                    } else {
                      _vote(id, [i]);
                    }
                  },
          ),
        if (allowMultiple && !closed && pending.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.tonal(
              onPressed: _busy ? null : () => _vote(id, pending.toList()..sort()),
              child: Text(myVotes.isEmpty ? 'Submit vote' : 'Update vote'),
            ),
          ),
        Row(children: [
          Expanded(
            child: Text(
              closed
                  ? 'Closed · $totalVotes total votes'
                  : myVotes.isNotEmpty
                      ? 'Vote recorded ($totalVotes total) · tap to update'
                      : allowMultiple
                          ? 'Choose options, then submit'
                          : 'One vote per family member',
              style: TextStyle(color: context.inkSoft, fontSize: 11),
            ),
          ),
          if (!closed && canClose)
            TextButton(onPressed: _busy ? null : () => _closePoll(id), child: const Text('Close poll')),
        ]),
      ]),
    );
  }

  String _message(Object error) {
    final text = error.toString();
    if (text.contains('PLUS_FEATURE_REQUIRED')) return 'An active Plus subscription is required for this action.';
    if (text.contains('ALREADY_VOTED')) return 'Your vote is already recorded.';
    if (text.contains('POLL_CLOSED')) return 'This poll is closed.';
    if (text.contains('PIN_LIMIT_REACHED')) return 'This family has reached the 20 pinned-message limit.';
    return text.replaceFirst('SyncException(', '').replaceFirst('Exception: ', '');
  }
}
