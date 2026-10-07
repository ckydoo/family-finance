import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../family_chat/family_chat_screen.dart';

class FamilyTasksScreen extends StatefulWidget {
  const FamilyTasksScreen({super.key});

  @override
  State<FamilyTasksScreen> createState() => _FamilyTasksScreenState();
}

class _FamilyTasksScreenState extends State<FamilyTasksScreen> {
  String _statusLabel(FamilyTaskStatus status) => switch (status) {
        FamilyTaskStatus.open => 'Open',
        FamilyTaskStatus.inProgress => 'In progress',
        FamilyTaskStatus.done => 'Done',
      };

  Future<void> _taskSheet(AppState state, FamilyTask task) async {
    final assignee = task.assigneeMemberId == null
        ? null
        : state.member(task.assigneeMemberId!);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: SafeArea(
          top: false,
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
                        fontWeight: FontWeight.w800,
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
                  if (task.dueDate != null)
                    Chip(
                      label: Text(
                        'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                      ),
                    ),
                  Chip(label: Text(_statusLabel(task.status))),
                  Chip(label: Text('${task.points} pts')),
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
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        state.toggleFamilyTaskCompletion(task);
                      },
                      icon: Icon(task.isDone ? Icons.refresh_rounded : Icons.check_rounded),
                      label: Text(task.isDone ? 'Reopen task' : 'Mark done'),
                    ),
                  ),
                ],
              ),
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
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  state.updateFamilyTask(task.copyWith(isArchived: true));
                },
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
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');
    String? assigneeId = task?.assigneeMemberId ??
        (state.members.isNotEmpty ? state.members.first.id : null);
    DateTime? dueDate = task?.dueDate;
    int points = task?.points ?? 1;
    var status = task?.status ?? FamilyTaskStatus.open;

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
                      DropdownButtonFormField<String>(
                        initialValue: assigneeId,
                        decoration: const InputDecoration(labelText: 'Assignee'),
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
                        onChanged: (value) => setState(() => assigneeId = value),
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
                    Row(
                      children: [
                        const Text('Points'),
                        const Spacer(),
                        IconButton(
                          onPressed: () => setState(() => points = (points - 1).clamp(0, 20)),
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
                          onPressed: () => setState(() => points = (points + 1).clamp(0, 20)),
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
      state.updateFamilyTask(task.copyWith(
        title: title,
        note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
        assigneeMemberId: assigneeId,
        dueDate: dueDate,
        status: status,
        points: points,
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
        status: status,
        points: points,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tasks = state.familyTasks
        .where((task) => !task.isArchived)
        .toList()
      ..sort((a, b) {
        final aDue = a.dueDate ?? DateTime(2100);
        final bDue = b.dueDate ?? DateTime(2100);
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return aDue.compareTo(bDue);
      });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family tasks'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _taskEditor(state),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Add task'),
      ),
      body: SafeArea(
        child: tasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No family tasks yet. Add the next check-in or task here.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final assignee = task.assigneeMemberId == null
                      ? null
                      : state.member(task.assigneeMemberId!);

                  return InkWell(
                    onTap: () => _taskSheet(state, task),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: task.isDone ? context.primarySoft : context.hairline,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: task.isDone,
                            onChanged: (_) => state.toggleFamilyTaskCompletion(task),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: task.isDone ? context.inkSoft : context.ink,
                                    decoration: task.isDone
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                  ),
                                ),
                                if (task.note != null && task.note!.isNotEmpty) ...[
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
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (assignee != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(assignee.name),
                                      ),
                                    if (task.dueDate != null)
                                      Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                                        ),
                                      ),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(_statusLabel(task.status)),
                                    ),
                                    Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text('${task.points} pts · ${state.stars} stars total'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FamilyChatScreen(
                                      initialTask: task,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline_rounded),
                                tooltip: 'Discuss task',
                              ),
                              IconButton(
                                onPressed: () => _taskEditor(state, task: task),
                                icon: const Icon(Icons.edit_outlined),
                                tooltip: 'Edit task',
                              ),
                              IconButton(
                                onPressed: () => state.updateFamilyTask(
                                  task.copyWith(isArchived: true),
                                ),
                                icon: const Icon(Icons.close_rounded),
                                tooltip: 'Archive task',
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
    );
  }
}
