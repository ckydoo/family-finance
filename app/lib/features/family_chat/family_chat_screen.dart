import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/chat_media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/ui.dart';
import '../budgets/budgets_screen.dart' show showEnvelopeDetailSheet;
import '../family_tasks/family_tasks_screen.dart';
import '../lists/lists_screen.dart';
import 'family_polls_sheet.dart';
import '../settings/plus_screen.dart';

class FamilyChatScreen extends StatefulWidget {
  const FamilyChatScreen({
    super.key,
    this.initialTask,
    this.initialBudget,
    this.initialShoppingItem,
  });

  final FamilyTask? initialTask;
  final Envelope? initialBudget;
  final ListItem? initialShoppingItem;

  @override
  State<FamilyChatScreen> createState() => _FamilyChatScreenState();
}

enum _ChatMessageAction { edit, delete, pin, unpin, upgrade }

enum _ChatAttachmentAction { budget, shopping, gallery }

class _PendingReference {
  const _PendingReference({
    required this.type,
    required this.id,
    required this.title,
    required this.meta,
  });

  final ChatReferenceType type;
  final String id;
  final String title;
  final String meta;
}

class _FamilyChatScreenState extends State<FamilyChatScreen> {
  final _controller = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();
  _PendingReference? _pendingReference;
  FamilyChatMessage? _replyingTo;
  bool _searching = false;
  bool _showExpressionTray = false;
  bool _uploadingMedia = false;
  String _query = '';
  String? _advancedSenderId;
  DateTime? _advancedFrom;
  DateTime? _advancedBefore;
  String _advancedKind = 'any';
  List<FamilyChatMessage>? _advancedResults;
  bool _advancedSearchRunning = false;
  int _advancedOffset = 0;
  bool _advancedHasMore = false;
  int _visibleCount = 50;
  Future<Map<String, String>>? _mediaHeaderFuture;
  Timer? _chatRefreshTimer;
  Set<String> _pinnedMessageIds = {};
  List<Map<String, Object?>> _pins = const [];
  String? _highlightedMessageId;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    final budget = widget.initialBudget;
    final item = widget.initialShoppingItem;
    if (task != null) {
      _pendingReference = _taskReference(task);
    } else if (budget != null) {
      _pendingReference = _budgetReference(budget);
    } else if (item != null) {
      _pendingReference = _shoppingReference(item);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.of(context);
      state.markFamilyChatRead();
      unawaited(state.sync?.refreshChat());
      unawaited(_loadPinnedMessageIds(state));
      _chatRefreshTimer = Timer.periodic(
        const Duration(milliseconds: 1200),
        (_) {
          if (!mounted) return;
          final currentState = AppScope.of(context);
          unawaited(currentState.sync?.refreshChat());
          _refreshTick++;
          if (_refreshTick % 4 == 0) {
            unawaited(_loadPinnedMessageIds(currentState));
          }
        },
      );
    });
  }

  Future<void> _loadPinnedMessageIds(AppState state) async {
    try {
      final pins = await state.sync?.fetchFamilyChatPins() ?? const [];
      if (!mounted) return;
      setState(() {
        _pins = pins;
        _pinnedMessageIds = {
          for (final pin in pins)
            if (pin['message_id'] != null) pin['message_id'].toString(),
        };
      });
    } catch (_) {
      // Existing chat stays usable if pin loading is unavailable.
    }
  }

  bool _canUnpin(
    AppState state,
    String messageId,
    FamilyChatMessage? message,
  ) {
    if (const {Role.owner, Role.admin, Role.adult}.contains(state.authRole)) {
      return true;
    }
    if (message != null && message.senderId == state.realUser.id) {
      return true;
    }
    for (final pin in _pins) {
      if (pin['message_id']?.toString() == messageId &&
          pin['pinned_by']?.toString() == state.realUser.id) {
        return true;
      }
    }
    return false;
  }

  void _jumpToMessage(AppState state, String messageId) {
    final allSorted = [...state.familyChatMessages]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final idx = allSorted.indexWhere((m) => m.id == messageId);
    if (idx < 0 || allSorted[idx].deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Original message is unavailable or was deleted.'),
        ),
      );
      return;
    }
    final fromNewest = allSorted.length - idx;
    setState(() {
      _searching = false;
      _query = '';
      _advancedResults = null;
      if (fromNewest > _visibleCount) {
        _visibleCount = fromNewest + 10;
      }
      _highlightedMessageId = messageId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final reverseIndex = (fromNewest - 1).clamp(0, allSorted.length);
      final targetOffset =
          (reverseIndex * 76.0).clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _showPinnedMessagesHub(AppState state) async {
    await _loadPinnedMessageIds(state);
    if (!mounted) return;
    final byId = {
      for (final msg in state.familyChatMessages) msg.id: msg,
    };
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.push_pin, color: context.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pinned messages (${_pins.length})',
                      style: TextStyle(
                        color: context.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_pins.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    state.hasPlusFeature('family_polls_pins')
                        ? 'No pinned messages yet. Long-press any message to pin important family updates.'
                        : 'Pinned messages are a Mhuri Plus feature.',
                    style: TextStyle(color: context.inkSoft),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _pins.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: context.hairline),
                    itemBuilder: (_, index) {
                      final pin = _pins[index];
                      final msgId = pin['message_id']?.toString() ?? '';
                      final msg = byId[msgId];
                      final isDeleted = msg == null || msg.deleted;
                      final canUnpin = _canUnpin(state, msgId, msg);
                      final preview = isDeleted
                          ? 'Original message was deleted'
                          : _replyPreview(msg);
                      final sender = isDeleted
                          ? 'Unavailable'
                          : (msg.senderName ??
                              state.member(msg.senderId)?.name ??
                              'Family member');
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          isDeleted
                              ? Icons.chat_bubble_outline
                              : Icons.push_pin_outlined,
                          color: isDeleted ? context.inkSoft : context.primary,
                        ),
                        title: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDeleted ? context.inkSoft : context.ink,
                            fontStyle: isDeleted
                                ? FontStyle.italic
                                : FontStyle.normal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          sender,
                          style:
                              TextStyle(color: context.inkSoft, fontSize: 12),
                        ),
                        onTap: isDeleted
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                _jumpToMessage(state, msgId);
                              },
                        trailing: canUnpin &&
                                state.hasPlusFeature('family_polls_pins')
                            ? IconButton(
                                tooltip: 'Unpin',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await state.sync
                                      ?.setFamilyChatPin(msgId, pinned: false);
                                  await _loadPinnedMessageIds(state);
                                },
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAdvancedFilters(AppState state) async {
    var sender = _advancedSenderId ?? '';
    var from = _advancedFrom;
    var before = _advancedBefore;
    var kind = _advancedKind;
    final result = await showDialog<(String, DateTime?, DateTime?, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Advanced message search'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: sender,
              decoration: const InputDecoration(labelText: 'Sender'),
              items: [
                const DropdownMenuItem(value: '', child: Text('Anyone')),
                for (final member in state.members)
                  DropdownMenuItem(value: member.id, child: Text(member.name)),
              ],
              onChanged: (value) => setDialogState(() => sender = value ?? ''),
            ),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Message type'),
              items: const [
                DropdownMenuItem(value: 'any', child: Text('Any type')),
                DropdownMenuItem(value: 'text', child: Text('Text')),
                DropdownMenuItem(
                    value: 'media', child: Text('Photo or attachment')),
                DropdownMenuItem(value: 'sticker', child: Text('Sticker')),
                DropdownMenuItem(value: 'system', child: Text('Family update')),
              ],
              onChanged: (value) => setDialogState(() => kind = value ?? 'any'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: from ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => from = picked);
                },
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text(from == null
                    ? 'From date'
                    : DateFormat.yMMMd().format(from!)),
              )),
              IconButton(
                  onPressed: () => setDialogState(() => from = null),
                  tooltip: 'Clear start date',
                  icon: const Icon(Icons.close, size: 18)),
            ]),
            Row(children: [
              Expanded(
                  child: TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: before ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setDialogState(() => before = picked);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(before == null
                    ? 'Through date'
                    : DateFormat.yMMMd().format(before!)),
              )),
              IconButton(
                  onPressed: () => setDialogState(() => before = null),
                  tooltip: 'Clear end date',
                  icon: const Icon(Icons.close, size: 18)),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext,
                  (sender, from, before?.add(const Duration(days: 1)), kind)),
              child: const Text('Search'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _advancedSenderId = result.$1.isEmpty ? null : result.$1;
      _advancedFrom = result.$2;
      _advancedBefore = result.$3;
      _advancedKind = result.$4;
    });
    await _runAdvancedSearch(state);
  }

  Future<void> _runAdvancedSearch(AppState state, {bool loadMore = false}) async {
    if (!state.hasPlusFeature('advanced_chat_search')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Advanced search requires an active Plus subscription.'),
        ));
      }
      return;
    }
    if (loadMore && !_advancedHasMore) return;
    setState(() => _advancedSearchRunning = true);
    try {
      const pageSize = 50;
      final offset = loadMore ? _advancedOffset : 0;
      final results = await state.sync!.searchFamilyChatMessages(
        text: _query.trim().isEmpty ? null : _query.trim(),
        senderId: _advancedSenderId,
        from: _advancedFrom,
        before: _advancedBefore,
        kind: _advancedKind,
        limit: pageSize,
        offset: offset,
      );
      if (mounted) {
        setState(() {
          final merged = loadMore
              ? <FamilyChatMessage>[...?_advancedResults, ...results]
              : results;
          final byId = <String, FamilyChatMessage>{
            for (final message in merged) message.id: message,
          };
          _advancedResults = byId.values.toList();
          _advancedOffset = offset + results.length;
          _advancedHasMore = results.length == pageSize;
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().contains('PLUS_FEATURE_REQUIRED')
              ? 'Advanced search requires Plus.'
              : 'Could not search server history. Check your connection and try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _advancedSearchRunning = false);
    }
  }

  @override
  void dispose() {
    _chatRefreshTimer?.cancel();
    _controller.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openTasks() => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const FamilyTasksScreen()),
      );

  void _openReferencedTask(AppState state, FamilyChatMessage message) {
    FamilyTask? task;
    for (final candidate in state.familyTasks) {
      if (candidate.id == message.referenceId) {
        task = candidate;
        break;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyTasksScreen(initialTask: task),
      ),
    );
  }

  _PendingReference _taskReference(FamilyTask task) => _PendingReference(
        type: ChatReferenceType.task,
        id: task.id,
        title: task.title,
        meta: [
          if (task.dueDate != null)
            'Due ${DateFormat('MMM d').format(task.dueDate!)}',
          '${task.points} pts',
        ].join(' • '),
      );

  _PendingReference _budgetReference(Envelope budget) => _PendingReference(
        type: ChatReferenceType.budget,
        id: budget.id,
        title: budget.name,
        meta: '${budget.limit.text} budget',
      );

  _PendingReference _shoppingReference(ListItem item) => _PendingReference(
        type: ChatReferenceType.shoppingList,
        id: item.id,
        title: item.name,
        meta:
            'Qty ${item.qty} · ${item.est.minor == 0 ? 'price not set' : item.est.text}',
      );

  void _openReference(AppState state, FamilyChatMessage message) {
    switch (message.referenceType) {
      case ChatReferenceType.task:
        _openReferencedTask(state, message);
        return;
      case ChatReferenceType.budget:
        final budget = state.envelopes
            .where((candidate) => candidate.id == message.referenceId)
            .firstOrNull;
        if (budget != null) showEnvelopeDetailSheet(context, budget);
        return;
      case ChatReferenceType.shoppingList:
        Navigator.of(context).push(
          MaterialPageRoute<void>(
              builder: (_) => const ListsScreen(standalone: true)),
        );
        return;
      default:
        break;
    }
  }

  IconData _referenceIcon(ChatReferenceType? type) => switch (type) {
        ChatReferenceType.budget => Icons.savings_outlined,
        ChatReferenceType.shoppingList => Icons.shopping_cart_outlined,
        _ => Icons.task_rounded,
      };

  String _referenceLabel(ChatReferenceType? type) => switch (type) {
        ChatReferenceType.budget => 'budget',
        ChatReferenceType.shoppingList => 'shopping item',
        _ => 'task',
      };

  FamilyChatMessage _message(
    AppState state, {
    required String text,
    String? mediaUrl,
    String? mediaType,
    String? sticker,
  }) {
    final reference = _pendingReference;
    final reply = _replyingTo;
    // RLS requires sender_id = auth.uid(); always use the authenticated
    // identity rather than any device-local profile state.
    final sender = state.realUser;
    return FamilyChatMessage(
      id: newUuid(),
      familyId: state.sync?.spaceId ?? state.space.name,
      senderId: sender.id,
      text: text,
      createdAt: DateTime.now(),
      senderName: sender.name,
      senderAvatar: sender.avatarUrl,
      status: ChatMessageStatus.pending,
      referenceType: reference?.type,
      referenceId: reference?.id,
      referenceTitle: reference?.title,
      referenceMeta: reference?.meta,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      sticker: sticker,
      replyToId: reply?.id,
      replySenderName: reply?.senderName ??
          (reply == null ? null : state.member(reply.senderId)?.name),
      replyPreview: reply == null ? null : _replyPreview(reply),
    );
  }

  String _replyPreview(FamilyChatMessage message) {
    final text = message.text.trim();
    if (text.isNotEmpty) return text;
    if (message.sticker?.isNotEmpty == true) return message.sticker!;
    if (message.mediaType == 'image') return 'Photo';
    if (message.referenceTitle?.isNotEmpty == true) {
      return message.referenceTitle!;
    }
    return 'Message';
  }

  void _startReply(FamilyChatMessage message) {
    HapticFeedback.selectionClick();
    setState(() {
      _replyingTo = message;
      _showExpressionTray = false;
    });
    _composerFocus.requestFocus();
  }

  FamilyChatMessage _updatedMessage(
    FamilyChatMessage message, {
    String? text,
    bool? deleted,
    DateTime? editedAt,
  }) =>
      FamilyChatMessage(
        id: message.id,
        familyId: message.familyId,
        senderId: message.senderId,
        text: text ?? message.text,
        createdAt: message.createdAt,
        isSystem: message.isSystem,
        senderName: message.senderName,
        senderAvatar: message.senderAvatar,
        status: message.status,
        referenceType: message.referenceType,
        referenceId: message.referenceId,
        referenceTitle: message.referenceTitle,
        referenceMeta: message.referenceMeta,
        mediaUrl: message.mediaUrl,
        mediaType: message.mediaType,
        sticker: message.sticker,
        replyToId: message.replyToId,
        replySenderName: message.replySenderName,
        replyPreview: message.replyPreview,
        editedAt: editedAt ?? message.editedAt,
        deleted: deleted ?? message.deleted,
      );

  Future<void> _showMessageActions(
    AppState state,
    FamilyChatMessage message,
  ) async {
    if (message.isSystem) return;
    final isPinned = _pinnedMessageIds.contains(message.id);
    final canEditDelete = message.senderId == state.realUser.id;
    final canEdit = message.mediaUrl == null && message.sticker == null;
    final action = await showMhuriSheet<_ChatMessageAction>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Message options',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canEditDelete && canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () =>
                    Navigator.pop(sheetContext, _ChatMessageAction.edit),
              ),
            if (canEditDelete)
              ListTile(
                leading: Icon(Icons.delete_outline, color: context.danger),
                title: Text(
                  'Delete message',
                  style: TextStyle(color: context.danger),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, _ChatMessageAction.delete),
              ),
            if (!isPinned || _canUnpin(state, message.id, message))
              ListTile(
                leading:
                    Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(isPinned ? 'Unpin message' : 'Pin message'),
                onTap: () => Navigator.pop(
                    sheetContext,
                    isPinned
                        ? state.hasPlusFeature('family_polls_pins')
                            ? _ChatMessageAction.unpin
                            : _ChatMessageAction.upgrade
                        : state.hasPlusFeature('family_polls_pins')
                            ? _ChatMessageAction.pin
                            : _ChatMessageAction.upgrade),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ChatMessageAction.upgrade) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const PlusScreen()));
      return;
    }
    if (action == _ChatMessageAction.pin ||
        action == _ChatMessageAction.unpin) {
      try {
        await state.sync?.setFamilyChatPin(message.id,
            pinned: action == _ChatMessageAction.pin);
        await _loadPinnedMessageIds(state);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error.toString().contains('PIN_LIMIT_REACHED')
                ? 'Your family has reached the pinned-message limit.'
                : 'Could not update pinned message. Check your connection and Plus access.'),
          ));
        }
      }
      return;
    }
    if (action == _ChatMessageAction.delete) {
      final confirmed = await confirmDialog(
        context,
        title: 'Delete message?',
        body: 'This message will be removed from the family chat.',
        confirmLabel: 'Delete',
        danger: true,
      );
      if (!confirmed || !mounted) return;
      state.addChatMessage(_updatedMessage(message, deleted: true));
      if (_replyingTo?.id == message.id) {
        setState(() => _replyingTo = null);
      }
      return;
    }

    var draft = message.text;
    final edited = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextFormField(
          initialValue: message.text,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Message'),
          onChanged: (value) => draft = value,
          onFieldSubmitted: (value) =>
              Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, draft.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (edited == null ||
        edited.isEmpty ||
        edited == message.text ||
        !mounted) {
      return;
    }
    state.addChatMessage(_updatedMessage(
      message,
      text: edited,
      editedAt: DateTime.now(),
    ));
  }

  void _send(AppState state) {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingReference == null) return;
    final reference = _pendingReference;
    final message = _message(
      state,
      text: text.isEmpty && reference != null
          ? '${_referenceLabel(reference.type)[0].toUpperCase()}${_referenceLabel(reference.type).substring(1)}: ${reference.title}'
          : text,
    );
    state.addChatMessage(message);
    _controller.clear();
    setState(() {
      _pendingReference = null;
      _replyingTo = null;
      _showExpressionTray = false;
    });
    _scrollToLatest();
  }

  void _sendSticker(AppState state, String sticker) {
    state.addChatMessage(_message(state, text: '', sticker: sticker));
    setState(() {
      _pendingReference = null;
      _replyingTo = null;
      _showExpressionTray = false;
    });
    _scrollToLatest();
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final next = _controller.text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _attachmentMenu(AppState state) async {
    final action = await showMhuriSheet<_ChatAttachmentAction>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Share with the family',
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.task_alt_rounded),
            title: const Text('Family tasks'),
            onTap: () {
              Navigator.pop(sheetContext);
              _openTasks();
            },
          ),
          ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Budget'),
            onTap: () => Navigator.pop(
              sheetContext,
              _ChatAttachmentAction.budget,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Shopping item'),
            onTap: () => Navigator.pop(
              sheetContext,
              _ChatAttachmentAction.shopping,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Photo library'),
            onTap: () => Navigator.pop(
              sheetContext,
              _ChatAttachmentAction.gallery,
            ),
          ),
        ]),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _ChatAttachmentAction.budget:
        await _pickBudget(state);
        return;
      case _ChatAttachmentAction.shopping:
        await _pickShoppingItem(state);
        return;
      case _ChatAttachmentAction.gallery:
        await _pickAndSendPhoto(state);
        return;
    }
  }

  Future<void> _pickBudget(AppState state) async {
    final budget = await showMhuriSheet<Envelope>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Reference a budget',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final budget in state.envelopes.where((e) => !e.isArchived))
              ListTile(
                leading: const Icon(Icons.savings_outlined),
                title: Text(budget.name),
                subtitle: Text(budget.limit.text),
                onTap: () => Navigator.pop(sheetContext, budget),
              ),
          ],
        ),
      ),
    );
    if (budget != null && mounted) {
      setState(() => _pendingReference = _budgetReference(budget));
      _composerFocus.requestFocus();
    }
  }

  Future<void> _pickShoppingItem(AppState state) async {
    final item = await showMhuriSheet<ListItem>(
      context: context,
      builder: (sheetContext) => MhuriSheetShell(
        title: 'Reference a shopping item',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final item in state.items.where((i) => i.deletedAt == null))
              ListTile(
                leading: const Icon(Icons.shopping_cart_outlined),
                title: Text(item.name),
                subtitle: Text('Qty ${item.qty}'),
                onTap: () => Navigator.pop(sheetContext, item),
              ),
          ],
        ),
      ),
    );
    if (item != null && mounted) {
      setState(() => _pendingReference = _shoppingReference(item));
      _composerFocus.requestFocus();
    }
  }

  Future<void> _pickAndSendPhoto(AppState state) async {
    final spaceId = state.sync?.spaceId;
    final baseUrl = state.env.supabaseUrl;
    final anonKey = state.env.supabaseAnonKey;
    final auth = state.auth;
    if (spaceId == null || baseUrl == null || auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Connect to your family before sharing photos.')));
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (file == null || !mounted) return;
    setState(() => _uploadingMedia = true);
    final messageId = newUuid();
    try {
      final extension = file.name.split('.').last;
      final url = await ChatMediaUploader(
        baseUrl: baseUrl,
        anonKey: anonKey ?? '',
        tokenGet: auth.validAccessToken,
      ).upload(
        bytes: await file.readAsBytes(),
        spaceId: spaceId,
        messageId: messageId,
        extension: extension,
      );
      if (!mounted) return;
      final caption = _controller.text.trim();
      final message =
          _message(state, text: caption, mediaUrl: url, mediaType: 'image');
      state.addChatMessage(FamilyChatMessage(
        id: messageId,
        familyId: message.familyId,
        senderId: message.senderId,
        text: message.text,
        createdAt: message.createdAt,
        senderName: message.senderName,
        senderAvatar: message.senderAvatar,
        status: message.status,
        referenceType: message.referenceType,
        referenceId: message.referenceId,
        referenceTitle: message.referenceTitle,
        referenceMeta: message.referenceMeta,
        mediaUrl: message.mediaUrl,
        mediaType: message.mediaType,
        replyToId: message.replyToId,
        replySenderName: message.replySenderName,
        replyPreview: message.replyPreview,
        editedAt: message.editedAt,
      ));
      _controller.clear();
      setState(() => _pendingReference = null);
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFacingErrorMessage(
            error,
            fallback:
                'Could not upload photo. Please check your connection and try again.',
          )),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploadingMedia = false);
    }
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _privateMediaUrl(String url) => url.replaceFirst(
      '/storage/v1/object/public/chat-media/',
      '/storage/v1/object/authenticated/chat-media/');

  Future<Map<String, String>> _mediaHeaders(AppState state) {
    return _mediaHeaderFuture ??= (() async {
      final auth = state.auth;
      final token = auth == null ? null : await auth.validAccessToken();
      if (token == null || token.isEmpty) {
        throw const ChatMediaException(
            'Your session expired. Sign in again to view this photo.');
      }
      return {
        'apikey': state.env.supabaseAnonKey ?? '',
        'Authorization': 'Bearer $token',
      };
    })();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.unreadChatCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppScope.of(context).markFamilyChatRead();
      });
    }
    final query = _query.trim().toLowerCase();
    final advancedResults = _advancedResults;
    final sourceMessages = advancedResults ?? state.familyChatMessages;
    final matching = sourceMessages
        .where((message) =>
            (message.deleted && advancedResults == null && query.isEmpty) ||
            (!message.deleted &&
                (advancedResults != null ||
                    query.isEmpty ||
                    message.text.toLowerCase().contains(query) ||
                    (message.sticker?.toLowerCase().contains(query) ?? false) ||
                    (message.senderName?.toLowerCase().contains(query) ??
                        false) ||
                    (message.referenceTitle?.toLowerCase().contains(query) ??
                        false))))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final hasEarlier =
        advancedResults == null && matching.length > _visibleCount;
    final messages = hasEarlier
        ? matching.sublist(matching.length - _visibleCount)
        : matching;
    final familyName = state.spaceName?.trim().isNotEmpty == true
        ? state.spaceName!
        : state.space.name;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() {
                  _query = value;
                  _advancedResults = null;
                  _advancedOffset = 0;
                  _advancedHasMore = false;
                }),
                onSubmitted: (_) {
                  if (_advancedSenderId != null ||
                      _advancedFrom != null ||
                      _advancedBefore != null ||
                      _advancedKind != 'any') {
                    _runAdvancedSearch(state);
                  }
                },
              )
            : Text(familyName),
        actions: [
          IconButton(
            tooltip: 'Pinned messages',
            onPressed: () => _showPinnedMessagesHub(state),
            icon: Badge(
              isLabelVisible: _pinnedMessageIds.isNotEmpty,
              label: Text('${_pinnedMessageIds.length}'),
              child: const Icon(Icons.push_pin_outlined),
            ),
          ),
          IconButton(
            tooltip: 'Family polls',
            onPressed: () =>
                showFamilyPollsSheet(context, AppScope.of(context)),
            icon: const Icon(Icons.poll_outlined),
          ),
          if (_searching && state.hasPlusFeature('advanced_chat_search'))
            IconButton(
              tooltip: 'Advanced search filters',
              onPressed: _advancedSearchRunning
                  ? null
                  : () => _showAdvancedFilters(state),
              icon: _advancedSearchRunning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.tune),
            ),
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search messages',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query = '';
                _advancedSenderId = null;
                _advancedFrom = null;
                _advancedBefore = null;
                _advancedKind = 'any';
                _advancedResults = null;
                _advancedOffset = 0;
                _advancedHasMore = false;
              }
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_pinnedMessageIds.isNotEmpty && !_searching)
              InkWell(
                onTap: () => _showPinnedMessagesHub(state),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.primarySoft,
                    border: Border(
                      bottom: BorderSide(color: context.hairline),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.push_pin, size: 16, color: context.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_pinnedMessageIds.length} pinned message${_pinnedMessageIds.length == 1 ? '' : 's'} · Tap to view or jump',
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: context.inkSoft,
                      ),
                    ],
                  ),
                ),
              ),
            if (_searching &&
                (_advancedSenderId != null ||
                    _advancedFrom != null ||
                    _advancedBefore != null ||
                    _advancedKind != 'any'))
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: context.card,
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined,
                        size: 16, color: context.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Server filters active (${_advancedKind != 'any' ? _advancedKind : 'filtered'})',
                        style:
                            TextStyle(fontSize: 12, color: context.inkSoft),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _advancedSenderId = null;
                        _advancedFrom = null;
                        _advancedBefore = null;
                        _advancedKind = 'any';
                        _advancedResults = null;
                        _advancedOffset = 0;
                        _advancedHasMore = false;
                      }),
                      child: const Text('Clear filters'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? EmptyHint(
                      _searching ||
                              _query.trim().isNotEmpty ||
                              _advancedResults != null
                          ? 'No messages match your search.'
                          : 'No family chat yet. Start the next money check-in here.',
                      icon: _searching ||
                              _query.trim().isNotEmpty ||
                              _advancedResults != null
                          ? Icons.search_off_rounded
                          : Icons.chat_bubble_outline_rounded,
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: messages.length +
                          (hasEarlier ||
                                  (advancedResults != null && _advancedHasMore)
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if ((hasEarlier ||
                                (advancedResults != null && _advancedHasMore)) &&
                            index == messages.length) {
                          return Center(
                            child: TextButton(
                              onPressed: _advancedSearchRunning
                                  ? null
                                  : advancedResults != null
                                      ? () => _runAdvancedSearch(state,
                                          loadMore: true)
                                      : () =>
                                          setState(() => _visibleCount += 50),
                              child: Text(advancedResults != null
                                  ? 'Load more server results'
                                  : 'Load earlier messages'),
                            ),
                          );
                        }
                        final messageIndex = messages.length - 1 - index;
                        final message = messages[messageIndex];
                        final older = messageIndex > 0
                            ? messages[messageIndex - 1]
                            : null;
                        final localDay = message.createdAt.toLocal();
                        final olderDay = older?.createdAt.toLocal();
                        final showDay = olderDay == null ||
                            localDay.year != olderDay.year ||
                            localDay.month != olderDay.month ||
                            localDay.day != olderDay.day;
                        final dayLabel = DateFormat('EEEE, MMM d')
                            .format(message.createdAt.toLocal());
                        if (message.isSystem) {
                          return Column(
                            children: [
                              if (showDay) _ChatDayLabel(dayLabel),
                              Semantics(
                                label: 'Mhuri update: ${message.text}',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8, horizontal: 20),
                                  child: Column(children: [
                                    Text(
                                      message.text,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: context.inkSoft,
                                      ),
                                    ),
                                    if (message.referenceMeta?.isNotEmpty ==
                                        true)
                                      Text(
                                        message.referenceMeta!,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: context.inkFaint,
                                        ),
                                      ),
                                  ]),
                                ),
                              ),
                            ],
                          );
                        }
                        final sender = state.member(message.senderId);
                        final isMine = message.senderId == state.user.id;
                        final senderName = message.senderName ??
                            sender?.name ??
                            'Family member';
                        if (message.deleted) {
                          return Column(
                            children: [
                              if (showDay) _ChatDayLabel(dayLabel),
                              _DeletedChatMessage(
                                isMine: isMine,
                                senderName: senderName,
                                createdAt: message.createdAt,
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            if (showDay) _ChatDayLabel(dayLabel),
                            GestureDetector(
                              onLongPress: () =>
                                  _showMessageActions(state, message),
                              child: Dismissible(
                                key: ValueKey('reply-${message.id}'),
                                direction: DismissDirection.startToEnd,
                                dismissThresholds: const {
                                  DismissDirection.startToEnd: 0.18,
                                },
                                confirmDismiss: (_) async {
                                  _startReply(message);
                                  return false;
                                },
                                background: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Icon(
                                      Icons.reply_rounded,
                                      color: context.primary,
                                    ),
                                  ),
                                ),
                                child: Align(
                                  alignment: isMine
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(maxWidth: 320),
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isMine
                                          ? context.primary
                                          : context.card,
                                      borderRadius:
                                          BorderRadius.circular(14).copyWith(
                                        bottomLeft:
                                            Radius.circular(isMine ? 14 : 5),
                                        bottomRight:
                                            Radius.circular(isMine ? 5 : 14),
                                      ),
                                      border: Border.all(
                                        color: _highlightedMessageId ==
                                                message.id
                                            ? context.primary
                                            : isMine
                                                ? context.primary
                                                : context.hairline,
                                        width: _highlightedMessageId ==
                                                message.id
                                            ? 2.2
                                            : 1.0,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!isMine)
                                          Text(
                                            senderName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: context.inkSoft,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        if (message.replyToId != null) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isMine
                                                  ? context.onSolid
                                                      .withValues(alpha: 0.14)
                                                  : context.primarySoft,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  message.replySenderName ??
                                                      'Family member',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isMine
                                                        ? context.onSolid
                                                        : context.primary,
                                                  ),
                                                ),
                                                Text(
                                                  message.replyPreview ??
                                                      'Message',
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isMine
                                                        ? context.onSolid
                                                            .withValues(
                                                                alpha: 0.8)
                                                        : context.inkSoft,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                        if (message.mediaUrl != null) ...[
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            child: FutureBuilder<
                                                Map<String, String>>(
                                              future: _mediaHeaders(state),
                                              builder: (context, snapshot) {
                                                if (snapshot.hasError) {
                                                  return _ChatImageError(
                                                      isMine: isMine);
                                                }
                                                if (!snapshot.hasData) {
                                                  return const SizedBox(
                                                    width: 240,
                                                    height: 160,
                                                    child: Center(
                                                        child:
                                                            CircularProgressIndicator()),
                                                  );
                                                }
                                                return Image.network(
                                                  _privateMediaUrl(
                                                      message.mediaUrl!),
                                                  headers: snapshot.data,
                                                  width: 240,
                                                  height: 220,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context,
                                                          child, progress) =>
                                                      progress == null
                                                          ? child
                                                          : const SizedBox(
                                                              width: 240,
                                                              height: 160,
                                                              child: Center(
                                                                  child:
                                                                      CircularProgressIndicator()),
                                                            ),
                                                  errorBuilder: (_, __, ___) =>
                                                      _ChatImageError(
                                                          isMine: isMine),
                                                );
                                              },
                                            ),
                                          ),
                                          if (message.text.isNotEmpty)
                                            const SizedBox(height: 8),
                                        ],
                                        if (message.sticker != null)
                                          Semantics(
                                            label: 'Sticker ${message.sticker}',
                                            child: Text(message.sticker!,
                                                style: const TextStyle(
                                                    fontSize: 54)),
                                          ),
                                        if (message.text.isNotEmpty)
                                          Text(
                                            message.text,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isMine
                                                  ? context.onSolid
                                                  : context.ink,
                                              height: 1.4,
                                            ),
                                          ),
                                        if (message.referenceType != null &&
                                            message.referenceTitle != null) ...[
                                          const SizedBox(height: 8),
                                          Semantics(
                                            button: true,
                                            label:
                                                'Open ${_referenceLabel(message.referenceType)} ${message.referenceTitle}',
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () => _openReference(
                                                  state, message),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isMine
                                                      ? context.onSolid
                                                          .withValues(
                                                              alpha: 0.14)
                                                      : context.primarySoft,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _referenceIcon(message
                                                          .referenceType),
                                                      size: 14,
                                                      color: isMine
                                                          ? context.onSolid
                                                          : context.primary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            message
                                                                .referenceTitle!,
                                                            style: TextStyle(
                                                              fontSize: 11.5,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: isMine
                                                                  ? context
                                                                      .onSolid
                                                                  : context.ink,
                                                            ),
                                                          ),
                                                          if (message.referenceMeta !=
                                                                  null &&
                                                              message
                                                                  .referenceMeta!
                                                                  .isNotEmpty)
                                                            Text(
                                                              message
                                                                  .referenceMeta!,
                                                              style: TextStyle(
                                                                fontSize: 10.5,
                                                                color: isMine
                                                                    ? context
                                                                        .onSolid
                                                                        .withValues(
                                                                            alpha:
                                                                                0.8)
                                                                    : context
                                                                        .inkSoft,
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    if (message.referenceType ==
                                                            ChatReferenceType
                                                                .task ||
                                                        message.referenceType ==
                                                            ChatReferenceType
                                                                .budget ||
                                                        message.referenceType ==
                                                            ChatReferenceType
                                                                .shoppingList) ...[
                                                      const SizedBox(width: 6),
                                                      Icon(
                                                          Icons
                                                              .chevron_right_rounded,
                                                          size: 16,
                                                          color: isMine
                                                              ? context.onSolid
                                                              : context
                                                                  .primary),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_pinnedMessageIds
                                                .contains(message.id)) ...[
                                              Icon(Icons.push_pin,
                                                  size: 12,
                                                  color: isMine
                                                      ? context.onSolid
                                                      : context.primary),
                                              const SizedBox(width: 3),
                                            ],
                                            Text(
                                              DateFormat('MMM d, h:mm a')
                                                  .format(message.createdAt
                                                      .toLocal()),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: isMine
                                                    ? context.onSolid
                                                        .withValues(alpha: 0.75)
                                                    : context.inkSoft,
                                              ),
                                            ),
                                            if (message.editedAt != null)
                                              Text(
                                                ' · Edited',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: isMine
                                                      ? context.onSolid
                                                          .withValues(
                                                              alpha: 0.75)
                                                      : context.inkSoft,
                                                ),
                                              ),
                                            if (isMine &&
                                                !message.isSystem) ...[
                                              const SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: message.status ==
                                                        ChatMessageStatus.failed
                                                    ? () =>
                                                        state.retryChatMessage(
                                                            message)
                                                    : null,
                                                child: Tooltip(
                                                  message: message.status ==
                                                          ChatMessageStatus
                                                              .failed
                                                      ? 'Not sent. Tap to retry.'
                                                      : 'Message status',
                                                  child: Icon(
                                                    switch (message.status) {
                                                      ChatMessageStatus
                                                            .pending =>
                                                        Icons.schedule_rounded,
                                                      ChatMessageStatus
                                                            .failed =>
                                                        Icons
                                                            .error_outline_rounded,
                                                      ChatMessageStatus.sent =>
                                                        Icons.check_rounded,
                                                      ChatMessageStatus
                                                          .delivered ||
                                                      ChatMessageStatus.read =>
                                                        Icons.done_all_rounded,
                                                    },
                                                    size: 14,
                                                    color: message.status ==
                                                            ChatMessageStatus
                                                                .failed
                                                        ? context.danger
                                                        : message.status ==
                                                                ChatMessageStatus
                                                                    .read
                                                            ? Colors
                                                                .lightBlueAccent
                                                            : context.onSolid
                                                                .withValues(
                                                                    alpha:
                                                                        0.75),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
                    if (_replyingTo != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                        decoration: BoxDecoration(
                          color: context.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.reply_rounded, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _replyingTo!.senderName ??
                                        state
                                            .member(_replyingTo!.senderId)
                                            ?.name ??
                                        'Family member',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _replyPreview(_replyingTo!),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: context.inkSoft,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Cancel reply',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _replyingTo = null),
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                          ],
                        ),
                      ),
                    if (_pendingReference != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InputChip(
                            label: Text(_pendingReference!.title),
                            avatar: Icon(
                              _referenceIcon(_pendingReference!.type),
                              size: 16,
                            ),
                            onDeleted: () =>
                                setState(() => _pendingReference = null),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _uploadingMedia
                              ? null
                              : () => _attachmentMenu(state),
                          tooltip: 'Add photo or reference',
                          icon: _uploadingMedia
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.2),
                                )
                              : const Icon(Icons.add_rounded),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _composerFocus,
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
                        IconButton(
                          onPressed: () => setState(
                              () => _showExpressionTray = !_showExpressionTray),
                          tooltip: 'Emoji and stickers',
                          icon: Icon(_showExpressionTray
                              ? Icons.keyboard_rounded
                              : Icons.sentiment_satisfied_alt_rounded),
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
                    if (_showExpressionTray) ...[
                      const SizedBox(height: 8),
                      _ExpressionTray(
                        onEmoji: _insertEmoji,
                        onSticker: (sticker) => _sendSticker(state, sticker),
                      ),
                    ],
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

class _DeletedChatMessage extends StatelessWidget {
  const _DeletedChatMessage({
    required this.isMine,
    required this.senderName,
    required this.createdAt,
  });

  final bool isMine;
  final String senderName;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) => Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 15, color: context.inkFaint),
                  const SizedBox(width: 6),
                  Text(
                    'Message was deleted',
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: context.inkSoft,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('MMM d, h:mm a').format(createdAt.toLocal()),
                style: TextStyle(fontSize: 10.5, color: context.inkFaint),
              ),
            ],
          ),
        ),
      );
}

class _ChatImageError extends StatelessWidget {
  const _ChatImageError({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        height: 120,
        child: Center(
          child: Icon(
            Icons.lock_outline_rounded,
            color: isMine ? context.onSolid : context.inkSoft,
          ),
        ),
      );
}

class _ExpressionTray extends StatelessWidget {
  const _ExpressionTray({required this.onEmoji, required this.onSticker});

  final ValueChanged<String> onEmoji;
  final ValueChanged<String> onSticker;

  static const emojis = [
    '😀',
    '😂',
    '🥰',
    '😊',
    '🙏',
    '👏',
    '👍',
    '❤️',
    '🎉',
    '💪',
    '🤝',
    '💡',
    '💰',
    '🛒',
    '🏠',
    '✅',
  ];
  static const stickers = ['🎉', '🙌', '💚', '💸', '🫶', '🔥', '👏🏾', '🏆'];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
        decoration: BoxDecoration(
          color: context.bg,
          borderRadius: kBRadiusM,
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Emoji',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 2,
              runSpacing: 2,
              children: [
                for (final emoji in emojis)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Insert $emoji',
                    onPressed: () => onEmoji(emoji),
                    icon: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
              ],
            ),
            Divider(height: 14, color: context.hairline),
            Text('Stickers',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.inkSoft)),
            const SizedBox(height: 4),
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stickers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (_, index) => InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSticker(stickers[index]),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Text(stickers[index],
                          style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ChatDayLabel extends StatelessWidget {
  const _ChatDayLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.inkSoft,
          ),
        ),
      );
}
