import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/chat_media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../core/widgets/ui.dart';
import '../family_tasks/family_tasks_screen.dart';

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
  bool _searching = false;
  bool _showExpressionTray = false;
  bool _uploadingMedia = false;
  String _query = '';
  int _visibleCount = 50;
  Future<Map<String, String>>? _mediaHeaderFuture;

  @override
  void initState() {
    super.initState();
    _pendingTask = widget.initialTask;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) AppScope.of(context).markFamilyChatRead();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
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

  FamilyChatMessage _message(
    AppState state, {
    required String text,
    String? mediaUrl,
    String? mediaType,
    String? sticker,
  }) {
    final task = _pendingTask;
    return FamilyChatMessage(
      id: newUuid(),
      familyId: state.sync?.spaceId ?? state.space.name,
      senderId: state.user.id,
      text: text,
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
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      sticker: sticker,
    );
  }

  void _send(AppState state) {
    final text = _controller.text.trim();
    if (text.isEmpty && _pendingTask == null) return;
    final task = _pendingTask;
    final message = _message(state,
        text:
            text.isEmpty && task != null ? 'Task update: ${task.title}' : text);
    state.addChatMessage(message);
    _controller.clear();
    setState(() {
      _pendingTask = null;
      _showExpressionTray = false;
    });
    _scrollToLatest();
  }

  void _sendSticker(AppState state, String sticker) {
    state.addChatMessage(_message(state, text: '', sticker: sticker));
    setState(() {
      _pendingTask = null;
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
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo library'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ]),
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndSendPhoto(state, source);
  }

  Future<void> _pickAndSendPhoto(AppState state, ImageSource source) async {
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
      source: source,
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
        tokenGet: auth.refreshAccessToken,
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
      ));
      _controller.clear();
      setState(() => _pendingTask = null);
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
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
      final token = auth == null ? null : await auth.refreshAccessToken();
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
    final query = _query.trim().toLowerCase();
    final matching = state.familyChatMessages
        .where((message) =>
            !message.deleted &&
            (query.isEmpty ||
                message.text.toLowerCase().contains(query) ||
                (message.sticker?.contains(query) ?? false) ||
                (message.senderName?.toLowerCase().contains(query) ?? false) ||
                (message.referenceTitle?.toLowerCase().contains(query) ??
                    false)))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final hasEarlier = matching.length > _visibleCount;
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
                onChanged: (value) => setState(() => _query = value),
              )
            : Text(familyName),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search messages',
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query = '';
            }),
            icon: Icon(_searching ? Icons.close : Icons.search),
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
                      itemCount: messages.length + (hasEarlier ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (hasEarlier && index == messages.length) {
                          return Center(
                            child: TextButton(
                              onPressed: () =>
                                  setState(() => _visibleCount += 50),
                              child: const Text('Load earlier messages'),
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
                        final sender =
                            state.member(message.senderId) ?? state.user;
                        final isMine = sender.id == state.user.id;
                        return Column(
                          children: [
                            if (showDay) _ChatDayLabel(dayLabel),
                            Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 320),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isMine ? context.primary : context.card,
                                  borderRadius:
                                      BorderRadius.circular(18).copyWith(
                                    bottomLeft:
                                        Radius.circular(isMine ? 18 : 6),
                                    bottomRight:
                                        Radius.circular(isMine ? 6 : 18),
                                  ),
                                  border: Border.all(
                                    color: isMine
                                        ? context.primary
                                        : context.hairline,
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
                                    if (message.mediaUrl != null) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child:
                                            FutureBuilder<Map<String, String>>(
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
                                              loadingBuilder:
                                                  (context, child, progress) =>
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
                                            style:
                                                const TextStyle(fontSize: 54)),
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
                                        button: message.referenceType ==
                                            ChatReferenceType.task,
                                        label:
                                            'Open task ${message.referenceTitle}',
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          onTap: message.referenceType ==
                                                  ChatReferenceType.task
                                              ? () => _openReferencedTask(
                                                  state, message)
                                              : null,
                                          child: Container(
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
                                                  BorderRadius.circular(12),
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
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        message.referenceTitle!,
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: isMine
                                                              ? context.onSolid
                                                              : context.ink,
                                                        ),
                                                      ),
                                                      if (message.referenceMeta !=
                                                              null &&
                                                          message.referenceMeta!
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
                                                    ChatReferenceType.task) ...[
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                      Icons
                                                          .chevron_right_rounded,
                                                      size: 16,
                                                      color: isMine
                                                          ? context.onSolid
                                                          : context.primary),
                                                ],
                                              ],
                                            ),
                                          ),
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
                    if (_pendingTask != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InputChip(
                            label: Text(_pendingTask!.title),
                            avatar: const Icon(Icons.task_rounded, size: 16),
                            onDeleted: () =>
                                setState(() => _pendingTask = null),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _uploadingMedia
                              ? null
                              : () => _attachmentMenu(state),
                          tooltip: 'Add photo or task',
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
