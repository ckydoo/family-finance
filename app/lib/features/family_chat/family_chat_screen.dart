import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/ui.dart';

class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({super.key, this.initialTask});

  final FamilyTask? initialTask;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  FamilyTask? _pendingTask;

  @override
  void initState() {
    super.initState();
    _pendingTask = widget.initialTask;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _attachTask(AppState state) {
    final tasks = state.familyTasks
        .where((task) => !task.isArchived && !task.isDone)
        .toList()
      ..sort((a, b) {
        final aDue = a.dueDate ?? DateTime(2100);
        final bDue = b.dueDate ?? DateTime(2100);
        return aDue.compareTo(bDue);
      });

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No open family tasks to attach yet.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Attach task'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final assignee = task.assigneeMemberId == null
                  ? null
                  : state.member(task.assigneeMemberId!);
              return ListTile(
                title: Text(task.title),
                subtitle: Text(
                  [
                    if (assignee != null) assignee.name,
                    if (task.dueDate != null)
                      'Due ${DateFormat('MMM d').format(task.dueDate!)}',
                    '${task.points} pts',
                  ].join(' • '),
                ),
                onTap: () {
                  setState(() => _pendingTask = task);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _send(AppState state) {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingTask == null) return;
    final familyId = state.sync?.spaceId ?? state.space.name;
    final task = _pendingTask;
    final message = FamilyChatMessage(
      id: newUuid(),
      familyId: familyId,
      senderId: state.user.id,
      text: text.isEmpty && task != null ? 'Task update: ${task.title}' : text,
      createdAt: DateTime.now(),
      senderName: state.user.name,
      senderAvatar: state.user.avatarUrl,
      status: ChatMessageStatus.sent,
      referenceType: task == null ? null : ChatReferenceType.task,
      referenceId: task?.id,
      referenceTitle: task?.title,
      referenceMeta: task == null
          ? null
          : [
              if (task.dueDate != null)
                'Due ${DateFormat('MMM d').format(task.dueDate!)}',
              '${task.points} pts',
            ].join(' • '),
    );
    state.addChatMessage(message);
    _controller.clear();
    setState(() => _pendingTask = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final messages = state.familyChatMessages;
    final familyName = state.spaceName?.trim().isNotEmpty == true
        ? state.spaceName!
        : state.space.name;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family chat'),
        actions: [
          if (state.hasSpace)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  familyName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty
                  ? const EmptyHint(
                      'No family chat yet. Start the next money check-in here.',
                      icon: Icons.chat_bubble_outline_rounded,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[messages.length - 1 - index];
                        final sender =
                            state.member(message.senderId) ?? state.user;
                        final isMine = sender.id == state.user.id;
                        return Align(
                          alignment: isMine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 320),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMine ? context.primary : context.card,
                              borderRadius: BorderRadius.circular(18).copyWith(
                                bottomLeft: Radius.circular(isMine ? 18 : 6),
                                bottomRight: Radius.circular(isMine ? 6 : 18),
                              ),
                              border: Border.all(
                                color:
                                    isMine ? context.primary : context.hairline,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMine)
                                  Text(
                                    sender.name,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: context.inkSoft,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Text(
                                  message.text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color:
                                        isMine ? context.onSolid : context.ink,
                                    height: 1.4,
                                  ),
                                ),
                                if (message.referenceType != null &&
                                    message.referenceTitle != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? context.onSolid.withValues(alpha: 0.14)
                                          : context.primarySoft,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.task_rounded,
                                          size: 14,
                                          color: isMine
                                              ? context.onSolid
                                              : context.primary,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                message.referenceTitle!,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isMine
                                                      ? context.onSolid
                                                      : context.ink,
                                                ),
                                              ),
                                              if (message.referenceMeta != null &&
                                                  message.referenceMeta!.isNotEmpty)
                                                Text(
                                                  message.referenceMeta!,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: isMine
                                                        ? context.onSolid
                                                            .withValues(alpha: 0.8)
                                                        : context.inkSoft,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('MMM d, h:mm a')
                                      .format(message.createdAt.toLocal()),
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isMine
                                        ? context.onSolid
                                            .withValues(alpha: 0.75)
                                        : context.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                decoration: BoxDecoration(
                  color: context.card,
                  border: Border(top: BorderSide(color: context.hairline)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pendingTask != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InputChip(
                            label: Text(_pendingTask!.title),
                            avatar: const Icon(Icons.task_rounded, size: 16),
                            onDeleted: () => setState(() => _pendingTask = null),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _attachTask(state),
                          tooltip: 'Attach task',
                          icon: const Icon(Icons.task_alt_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Message the family…',
                              filled: true,
                              fillColor: context.bg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _send(state),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _send(state),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            minimumSize: const Size(54, 48),
                          ),
                          child: const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
