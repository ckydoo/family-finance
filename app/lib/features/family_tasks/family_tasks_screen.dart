import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../family_chat/family_chat_screen.dart';

class FamilyTasksScreen extends StatefulWidget {
  const FamilyTasksScreen({
    super.key,
    this.startAdding = false,
    this.initialTask,
  });

  final bool startAdding;
  final FamilyTask? initialTask;

  @override
  State<FamilyTasksScreen> createState() => _FamilyTasksScreenState();
}

class _FamilyTasksScreenState extends State<FamilyTasksScreen> {
  _TaskPeriod _period = _TaskPeriod.today;
  _TaskScope _scope = _TaskScope.all;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialTask != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _taskSheet(AppScope.of(context), widget.initialTask!);
      });
    } else if (widget.startAdding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _taskEditor(AppScope.of(context));
      });
    }
  }

  String _statusLabel(FamilyTaskStatus status) => switch (status) {
        FamilyTaskStatus.open => 'Open',
        FamilyTaskStatus.inProgress => 'In progress',
        FamilyTaskStatus.done => 'Done',
        FamilyTaskStatus.awaitingApproval => 'Awaiting approval',
      };

  void _submitTask(AppState state, FamilyTask task) {
    final submitted = state.submitFamilyTask(task);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(submitted
            ? (task.requiresApproval
                ? 'Task submitted for family approval.'
                : 'Task completed. You earned ${task.points} points.')
            : 'This task could not be submitted. Refresh and try again.'),
      ),
    );
  }

  Future<void> _taskSheet(AppState state, FamilyTask task) async {
    final assignee = task.assigneeMemberId == null
        ? null
        : state.member(task.assigneeMemberId!);
    final creator = task.createdByMemberId == null
        ? null
        : state.member(task.createdByMemberId!);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.bg,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (assignee != null)
                    Chip(label: Text('Assigned to ${assignee.name}')),
                  if (creator != null)
                    Chip(label: Text('Added by ${creator.name}')),
                  if (task.dueDate != null)
                    Chip(
                      label: Text(
                        'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                      ),
                    ),
                  Chip(label: Text(_statusLabel(task.status))),
                  Chip(label: Text('${task.points} pts')),
                  if (task.requiresApproval)
                    Chip(
                        label: Text(task.approvedByMemberId == null
                            ? (task.isAwaitingApproval
                                ? 'Approval pending'
                                : 'Approval required')
                            : 'Approved')),
                ],
              ),
              if (task.note != null && task.note!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  task.note!,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.inkSoft,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  if (!task.isComplete)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.canManageFamilyTasks ||
                                state.canSubmitFamilyTasks
                            ? () {
                                Navigator.of(sheetContext).pop();
                                if (!state.canManageFamilyTasks) {
                                  _submitTask(state, task);
                                  return;
                                }
                                final nextStatus =
                                    task.status == FamilyTaskStatus.inProgress
                                        ? (task.requiresApproval
                                            ? FamilyTaskStatus.awaitingApproval
                                            : FamilyTaskStatus.done)
                                        : FamilyTaskStatus.inProgress;
                                state.updateFamilyTask(
                                  task.copyWith(
                                    status: nextStatus,
                                    completedAt:
                                        nextStatus == FamilyTaskStatus.done ||
                                                nextStatus ==
                                                    FamilyTaskStatus
                                                        .awaitingApproval
                                            ? DateTime.now()
                                            : null,
                                    completedByMemberId:
                                        nextStatus == FamilyTaskStatus.done ||
                                                nextStatus ==
                                                    FamilyTaskStatus
                                                        .awaitingApproval
                                            ? (task.assigneeMemberId ??
                                                state.realUser.id)
                                            : null,
                                    approvedByMemberId:
                                        nextStatus == FamilyTaskStatus.done
                                            ? task.approvedByMemberId
                                            : null,
                                    approvedAt:
                                        nextStatus == FamilyTaskStatus.done
                                            ? task.approvedAt
                                            : null,
                                  ),
                                );
                              }
                            : null,
                        icon: Icon(
                          !state.canManageFamilyTasks
                              ? Icons.upload_rounded
                              : task.status == FamilyTaskStatus.inProgress
                                  ? Icons.check_rounded
                                  : Icons.play_arrow_rounded,
                        ),
                        label: Text(
                          !state.canManageFamilyTasks
                              ? 'Submit for approval'
                              : task.status == FamilyTaskStatus.inProgress
                                  ? (task.requiresApproval
                                      ? 'Submit for approval'
                                      : 'Mark done')
                                  : 'Start task',
                        ),
                      ),
                    ),
                  if (task.isComplete && state.canManageFamilyTasks)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: state.canManageFamilyTasks
                            ? () {
                                Navigator.of(sheetContext).pop();
                                state.updateFamilyTask(
                                  task.copyWith(
                                    status: FamilyTaskStatus.open,
                                    approvedByMemberId: null,
                                    approvedAt: null,
                                    completedAt: null,
                                    completedByMemberId: null,
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reopen task'),
                      ),
                    ),
                ],
              ),
              if (task.requiresApproval &&
                  task.status == FamilyTaskStatus.awaitingApproval &&
                  task.approvedByMemberId == null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: state.canApprove
                        ? () {
                            Navigator.of(sheetContext).pop();
                            state.approveFamilyTask(task);
                          }
                        : null,
                    icon: const Icon(Icons.thumb_up_rounded),
                    label: const Text('Approve reward'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FamilyChatScreen(initialTask: task),
                          ),
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: const Text('Discuss'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: state.canManageFamilyTasks
                    ? () {
                        Navigator.of(sheetContext).pop();
                        state.updateFamilyTask(task.copyWith(isArchived: true));
                      }
                    : null,
                icon: const Icon(Icons.archive_rounded),
                label: const Text('Archive'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _taskEditor(AppState state, {FamilyTask? task}) async {
    final editing = task != null;
    if (!state.canManageFamilyTasks) return;
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');
    String? assigneeId = task?.assigneeMemberId ??
        (state.members.isNotEmpty ? state.members.first.id : null);
    DateTime? dueDate = task?.dueDate;
    int points = task?.points ?? 1;
    var status = task?.status ?? FamilyTaskStatus.open;
    bool requiresApproval = task?.requiresApproval ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(editing ? 'Edit family task' : 'Add family task'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        hintText: 'School forms / groceries / check-in',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText: 'Who’s involved and what needs done?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (state.members.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        initialValue: assigneeId,
                        decoration:
                            const InputDecoration(labelText: 'Assignee'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Unassigned'),
                          ),
                          ...state.members.map((m) => DropdownMenuItem(
                                value: m.id,
                                child: Text(m.name),
                              )),
                        ],
                        onChanged: (value) =>
                            setState(() => assigneeId = value),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: dueDate ?? DateTime.now(),
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 3650),
                                ),
                              );
                              if (picked != null) {
                                setState(() => dueDate = picked);
                              }
                            },
                            child: Text(
                              dueDate == null
                                  ? 'Add due date'
                                  : DateFormat('MMM d').format(dueDate!),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Status'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<FamilyTaskStatus>(
                            initialValue: status,
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            items: FamilyTaskStatus.values
                                .map((value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(_statusLabel(value)),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => status = value!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: requiresApproval,
                      onChanged: (value) => setState(() {
                        requiresApproval = value;
                      }),
                      title: const Text('Requires family approval'),
                      subtitle: const Text(
                          'Hold rewards until a parent approves completion.'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Points'),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(
                              () => points = (points - 1).clamp(0, 20)),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '$points',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(
                              () => points = (points + 1).clamp(0, 20)),
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text(editing ? 'Save changes' : 'Save task'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    final title = titleController.text.trim();
    if (title.isEmpty) return;

    if (task != null) {
      final currentTask = task;
      state.updateFamilyTask(currentTask.copyWith(
        title: title,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        assigneeMemberId: assigneeId,
        dueDate: dueDate,
        status: status,
        points: points,
        requiresApproval: requiresApproval,
        completedAt: status == FamilyTaskStatus.open ? null : task.completedAt,
        completedByMemberId:
            status == FamilyTaskStatus.open ? null : task.completedByMemberId,
        approvedByMemberId:
            status == FamilyTaskStatus.open ? null : task.approvedByMemberId,
        approvedAt: status == FamilyTaskStatus.open ? null : task.approvedAt,
      ));
      return;
    }

    state.addFamilyTask(
      FamilyTask(
        id: newUuid(),
        title: title,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
        assigneeMemberId: assigneeId,
        createdByMemberId: state.user.id,
        createdAt: DateTime.now(),
        dueDate: dueDate,
        status: status == FamilyTaskStatus.done && requiresApproval
            ? FamilyTaskStatus.awaitingApproval
            : status,
        points: points,
        requiresApproval: requiresApproval,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final query = _query.trim().toLowerCase();
    final scopedTasks = state.familyTasks.where((task) {
      if (task.isArchived) return false;
      final scopeMatches = switch (_scope) {
        _TaskScope.all => true,
        _TaskScope.mine => task.assigneeMemberId == state.user.id,
        _TaskScope.available => task.assigneeMemberId == null,
      };
      final searchMatches = query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          (task.note?.toLowerCase().contains(query) ?? false);
      return scopeMatches && searchMatches;
    }).toList();

    bool matchesPeriod(FamilyTask task, _TaskPeriod period) => switch (period) {
          _TaskPeriod.today => !task.isDone &&
              (task.dueDate == null || task.dueDate!.isBefore(tomorrow)),
          _TaskPeriod.upcoming => !task.isDone &&
              task.dueDate != null &&
              !task.dueDate!.isBefore(tomorrow),
          _TaskPeriod.completed => task.isDone,
        };

    final counts = {
      for (final period in _TaskPeriod.values)
        period: scopedTasks.where((task) => matchesPeriod(task, period)).length,
    };
    final tasks =
        scopedTasks.where((task) => matchesPeriod(task, _period)).toList()
          ..sort((a, b) {
            final aDue = a.dueDate ?? DateTime(2100);
            final bDue = b.dueDate ?? DateTime(2100);
            if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
            return aDue.compareTo(bDue);
          });

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search tasks',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Tasks & responsibilities'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search tasks',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      floatingActionButton: state.canManageFamilyTasks
          ? FloatingActionButton(
              tooltip: 'Add task',
              onPressed: () => _taskEditor(state),
              child: const Icon(Icons.add_rounded),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Column(
                children: [
                  SegmentedButton<_TaskPeriod>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                          value: _TaskPeriod.today,
                          label: _TaskTabLabel(
                              title: 'Today',
                              count: counts[_TaskPeriod.today]!)),
                      ButtonSegment(
                          value: _TaskPeriod.upcoming,
                          label: _TaskTabLabel(
                              title: 'Upcoming',
                              count: counts[_TaskPeriod.upcoming]!)),
                      ButtonSegment(
                          value: _TaskPeriod.completed,
                          label: _TaskTabLabel(
                              title: 'Completed',
                              count: counts[_TaskPeriod.completed]!)),
                    ],
                    selected: {_period},
                    onSelectionChanged: (value) =>
                        setState(() => _period = value.first),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final scope in _TaskScope.values)
                          ChoiceChip(
                            label: Text(scope.label),
                            selected: _scope == scope,
                            onSelected: (_) => setState(() => _scope = scope),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _period == _TaskPeriod.completed
                                  ? 'No completed tasks here.'
                                  : 'No tasks in this view.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            if (state.canManageFamilyTasks)
                              TextButton.icon(
                                onPressed: () => _taskEditor(state),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add task'),
                              ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: context.hairline),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final assignee = task.assigneeMemberId == null
                            ? null
                            : state.member(task.assigneeMemberId!);

                        return InkWell(
                          onTap: () => _taskSheet(state, task),
                          borderRadius: kBRadiusM,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: task.isComplete,
                                  onChanged: state.canManageFamilyTasks
                                      ? (_) =>
                                          state.toggleFamilyTaskCompletion(task)
                                      : state.canSubmitFamilyTasks &&
                                              !task.isComplete
                                          ? (_) => _submitTask(state, task)
                                          : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        task.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: task.isComplete
                                              ? context.inkSoft
                                              : context.ink,
                                          decoration: task.isComplete
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                      if (task.note != null &&
                                          task.note!.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          task.note!,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: context.inkSoft,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 5),
                                      Text(
                                        [
                                          assignee?.name ?? 'Anyone',
                                          if (task.dueDate != null)
                                            'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                                          '${task.points} pts',
                                          if (task.status ==
                                              FamilyTaskStatus.inProgress)
                                            'In progress',
                                          if (task.isAwaitingApproval)
                                            'Awaiting approval',
                                        ].join(' · '),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.inkSoft,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => FamilyChatScreen(
                                            initialTask: task,
                                          ),
                                        ),
                                      ),
                                      icon: const Icon(
                                          Icons.chat_bubble_outline_rounded),
                                      tooltip: 'Discuss task',
                                    ),
                                    if (state.canManageFamilyTasks)
                                      IconButton(
                                        onPressed: () =>
                                            _taskEditor(state, task: task),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: 'Edit task',
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTabLabel extends StatelessWidget {
  const _TaskTabLabel({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: context.primaryDark,
                ),
              ),
            ),
          ],
        ],
      );
}

enum _TaskPeriod { today, upcoming, completed }

enum _TaskScope { all, mine, available }

extension on _TaskScope {
  String get label => switch (this) {
        _TaskScope.all => 'All',
        _TaskScope.mine => 'Mine',
        _TaskScope.available => 'Available',
      };
}
