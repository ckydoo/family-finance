import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path_util;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
import 'family_chat_voice_note.dart';
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

enum _ChatMessageAction {
  edit,
  delete,
  pin,
  unpin,
  upgradeEnhanced,
  upgradePins
}

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
  final AudioPlayer _voicePlayer = AudioPlayer();
  _PendingReference? _pendingReference;
  FamilyChatMessage? _replyingTo;
  bool _searching = false;
  bool _showExpressionTray = false;
  bool _uploadingMedia = false;
  bool _recordingVoice = false;
  bool _finishingVoiceNote = false;
  Duration _recordingElapsed = Duration.zero;
  DateTime? _recordingStartedAt;
  String? _recordingPath;
  AudioRecorder? _voiceRecorder;
  Timer? _recordingTimer;
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

  bool _hasEnhancedChat(AppState state) =>
      state.canWritePlusFeature('enhanced_family_chat');

  Future<void> _showChatUpgrade(String feature) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('A Mhuri Plus feature'),
        content: Text(
            '$feature is included with Mhuri Plus. Your family text chat and replies stay free.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Maybe later'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlusScreen()),
              );
            },
            icon: const Icon(Icons.workspace_premium_outlined),
            label: const Text('Explore Plus'),
          ),
        ],
      ),
    );
  }

  Future<void> _removePin(AppState state, String messageId) async {
    try {
      await state.sync?.setFamilyChatPin(messageId, pinned: false);
      await _loadPinnedMessageIds(state);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(userFacingErrorMessage(
          error,
          fallback: 'Could not remove this pinned message. Please try again.',
        )),
      ));
    }
  }

  static const _maxVoiceNoteDuration = Duration(seconds: 90);

  String _voiceTime(Duration value) {
    final seconds = value.inSeconds.clamp(0, 5999);
    return '${(seconds ~/ 60).toString().padLeft(1, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  Future<void> _toggleVoiceNote(AppState state) async {
    if (!_hasEnhancedChat(state)) {
      await _showChatUpgrade('Voice notes');
      return;
    }
    if (_recordingVoice) {
      await _finishVoiceNote(state);
      return;
    }
    if (_uploadingMedia || _finishingVoiceNote) return;
    final spaceId = state.sync?.spaceId;
    if (spaceId == null ||
        state.env.supabaseUrl == null ||
        state.auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connect to your family before sending a voice note.'),
      ));
      return;
    }
    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) {
        throw const ChatMediaException(
          'Allow microphone access in your device settings to record a voice note.',
        );
      }
      final temporaryDirectory = await getTemporaryDirectory();
      final filePath = path_util.join(
        temporaryDirectory.path,
        'mhuri_voice_${newUuid()}.m4a',
      );
      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 24000,
          numChannels: 1,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: filePath,
      );
      if (!mounted) {
        await recorder.cancel();
        await recorder.dispose();
        return;
      }
      setState(() {
        _voiceRecorder = recorder;
        _recordingPath = filePath;
        _recordingStartedAt = DateTime.now();
        _recordingElapsed = Duration.zero;
        _recordingVoice = true;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        final started = _recordingStartedAt;
        if (!mounted || started == null || !_recordingVoice) return;
        final elapsed = DateTime.now().difference(started);
        setState(() => _recordingElapsed = elapsed);
        if (elapsed >= _maxVoiceNoteDuration) {
          unawaited(_finishVoiceNote(state));
        }
      });
    } catch (error) {
      await recorder.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFacingErrorMessage(
            error,
            fallback: 'Could not start recording. Please try again.',
          )),
        ));
      }
    }
  }

  Future<void> _cancelVoiceNote() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final recorder = _voiceRecorder;
    final filePath = _recordingPath;
    _voiceRecorder = null;
    _recordingPath = null;
    if (mounted) {
      setState(() {
        _recordingVoice = false;
        _recordingStartedAt = null;
        _recordingElapsed = Duration.zero;
      });
    }
    try {
      await recorder?.cancel();
    } catch (_) {
      // Best-effort cleanup when the OS already interrupted recording.
    }
    await recorder?.dispose();
    if (filePath != null) {
      try {
        await File(filePath).delete();
      } catch (_) {
        // A canceled recorder can delete its own temporary file.
      }
    }
  }

  Future<void> _finishVoiceNote(AppState state) async {
    if (_finishingVoiceNote) return;
    final recorder = _voiceRecorder;
    final filePath = _recordingPath;
    if (recorder == null || filePath == null) return;
    _finishingVoiceNote = true;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final duration = _recordingStartedAt == null
        ? _recordingElapsed
        : DateTime.now().difference(_recordingStartedAt!);
    if (mounted) {
      setState(() {
        _recordingVoice = false;
        _uploadingMedia = true;
      });
    }
    _voiceRecorder = null;
    _recordingPath = null;
    ChatMediaUploader? uploader;
    try {
      final stoppedPath = await recorder.stop();
      await recorder.dispose();
      final finalPath = stoppedPath ?? filePath;
      if (duration < const Duration(seconds: 1)) {
        throw const ChatMediaException(
          'Record at least one second before sending a voice note.',
        );
      }
      final file = File(finalPath);
      final bytes = await file.readAsBytes();
      final spaceId = state.sync?.spaceId;
      final baseUrl = state.env.supabaseUrl;
      final auth = state.auth;
      if (spaceId == null || baseUrl == null || auth == null) {
        throw const ChatMediaException(
          'Reconnect to your family before sending the voice note.',
        );
      }
      final messageId = newUuid();
      uploader = ChatMediaUploader(
        baseUrl: baseUrl,
        anonKey: state.env.supabaseAnonKey ?? '',
        tokenGet: auth.validAccessToken,
      );
      final url = await uploader.upload(
        bytes: bytes,
        spaceId: spaceId,
        messageId: messageId,
        extension: 'm4a',
      );
      if (!mounted) return;
      final message = _message(
        state,
        text: '',
        mediaUrl: url,
        mediaType: 'audio',
      );
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
      ));
      setState(() {
        _pendingReference = null;
        _replyingTo = null;
        _recordingStartedAt = null;
      });
      _scrollToLatest();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(userFacingErrorMessage(
            error,
            fallback: 'Could not send the voice note. Please try again.',
          )),
        ));
      }
    } finally {
      uploader?.close();
      try {
        await File(filePath).delete();
      } catch (_) {
        // Local recording is temporary and can be absent after plugin cleanup.
      }
      _finishingVoiceNote = false;
      if (mounted) {
        setState(() {
          _uploadingMedia = false;
          _recordingStartedAt = null;
        });
      }
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
                  child: Column(
                    children: [
                      Text(
                        state.canWritePlusFeature('family_polls_pins')
                            ? 'No pinned messages yet. Long-press any message to pin important family updates.'
                            : 'Pinned messages are a Mhuri Plus feature. Family chat stays free.',
                        style: TextStyle(color: context.inkSoft),
                        textAlign: TextAlign.center,
                      ),
                      if (!state.canWritePlusFeature('family_polls_pins'))
                        TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const PlusScreen(),
                            ));
                          },
                          icon: const Icon(Icons.workspace_premium_outlined),
                          label: const Text('Explore Mhuri Plus'),
                        ),
                    ],
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
                            fontStyle:
                                isDeleted ? FontStyle.italic : FontStyle.normal,
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
                        trailing: canUnpin
                            ? TextButton.icon(
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _removePin(state, msgId);
                                },
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Remove'),
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

  Future<void> _runAdvancedSearch(AppState state,
      {bool loadMore = false}) async {
    if (!state.canWritePlusFeature('advanced_chat_search')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Advanced chat search is a Mhuri Plus feature.'),
          action: SnackBarAction(
            label: 'Explore Mhuri Plus',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PlusScreen(),
            )),
          ),
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
              ? 'Advanced search requires Mhuri Plus.'
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
    _recordingTimer?.cancel();
    final recorder = _voiceRecorder;
    final recordingPath = _recordingPath;
    if (recorder != null) {
      unawaited(() async {
        try {
          await recorder.cancel();
        } catch (_) {}
        await recorder.dispose();
      }());
    }
    if (recordingPath != null) {
      unawaited(
          File(recordingPath).delete().catchError((_) => File(recordingPath)));
    }
    unawaited(_voicePlayer.dispose());
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
    if (message.mediaType == 'audio') return 'Voice note';
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
    final enhancedChat = _hasEnhancedChat(state);
    final pollsAndPins = state.canWritePlusFeature('family_polls_pins');
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
                trailing: enhancedChat ? null : const _PlusLock(),
                onTap: () => Navigator.pop(
                    sheetContext,
                    enhancedChat
                        ? _ChatMessageAction.edit
                        : _ChatMessageAction.upgradeEnhanced),
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
                trailing: isPinned || pollsAndPins ? null : const _PlusLock(),
                onTap: () => Navigator.pop(
                    sheetContext,
                    isPinned
                        ? _ChatMessageAction.unpin
                        : pollsAndPins
                            ? _ChatMessageAction.pin
                            : _ChatMessageAction.upgradePins),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == _ChatMessageAction.upgradeEnhanced ||
        action == _ChatMessageAction.upgradePins) {
      await _showChatUpgrade(action == _ChatMessageAction.upgradeEnhanced
          ? 'Editing messages'
          : 'Pinned messages');
      return;
    }
    if (action == _ChatMessageAction.pin ||
        action == _ChatMessageAction.unpin) {
      if (action == _ChatMessageAction.unpin) {
        await _removePin(state, message.id);
        return;
      }
      try {
        await state.sync?.setFamilyChatPin(message.id, pinned: true);
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
    if (_pendingReference != null && !_hasEnhancedChat(state)) {
      unawaited(_showChatUpgrade('Sharing a chat reference'));
      return;
    }
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
    if (!_hasEnhancedChat(state)) {
      unawaited(_showChatUpgrade('Emoji and stickers'));
      return;
    }
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
    if (!_hasEnhancedChat(state)) {
      await _showChatUpgrade('Photo sharing and chat references');
      return;
    }
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
    if (!_hasEnhancedChat(state)) {
      await _showChatUpgrade('Photo sharing');
      return;
    }
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
    ChatMediaUploader? uploader;
    try {
      final extension =
          file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      uploader = ChatMediaUploader(
        baseUrl: baseUrl,
        anonKey: anonKey ?? '',
        tokenGet: auth.validAccessToken,
      );
      final url = await uploader.upload(
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
      uploader?.close();
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

  String _privateMediaUrl(AppState state, String url) {
    final base = Uri.tryParse(state.env.supabaseUrl ?? '');
    final target = Uri.tryParse(url);
    if (base == null ||
        !base.hasAuthority ||
        target == null ||
        !target.hasAuthority ||
        target.origin != base.origin) {
      final origin = base?.hasAuthority == true ? base!.origin : '';
      return '$origin/storage/v1/object/authenticated/chat-media/invalid';
    }
    final path = target.path.replaceFirst(
      '/storage/v1/object/public/chat-media/',
      '/storage/v1/object/authenticated/chat-media/',
    );
    if (!path.startsWith('/storage/v1/object/authenticated/chat-media/')) {
      return '${base.origin}/storage/v1/object/authenticated/chat-media/invalid';
    }
    return target.replace(path: path).toString();
  }

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

  Future<Map<String, String>> _freshMediaHeaders(AppState state) async {
    final auth = state.auth;
    final token = auth == null ? null : await auth.validAccessToken();
    if (token == null || token.isEmpty) {
      throw const ChatMediaException(
        'Your session expired. Sign in again to play this voice note.',
      );
    }
    return {
      'apikey': state.env.supabaseAnonKey ?? '',
      'Authorization': 'Bearer $token',
    };
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
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.push_pin_outlined),
                  if (!state.canWritePlusFeature('family_polls_pins'))
                    const Positioned(
                      right: -5,
                      bottom: -4,
                      child: _PlusLock(size: 10),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Family polls',
            onPressed: () =>
                showFamilyPollsSheet(context, AppScope.of(context)),
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.poll_outlined),
                if (!state.canWritePlusFeature('family_polls_pins'))
                  const Positioned(
                    right: -5,
                    bottom: -4,
                    child: _PlusLock(size: 10),
                  ),
              ],
            ),
          ),
          if (_searching && state.canWritePlusFeature('advanced_chat_search'))
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
                        style: TextStyle(fontSize: 12, color: context.inkSoft),
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
                                (advancedResults != null &&
                                    _advancedHasMore)) &&
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
                                        color:
                                            _highlightedMessageId == message.id
                                                ? context.primary
                                                : isMine
                                                    ? context.primary
                                                    : context.hairline,
                                        width:
                                            _highlightedMessageId == message.id
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
                                        if (message.mediaUrl != null &&
                                            message.mediaType == 'audio') ...[
                                          FamilyChatVoiceNote(
                                            key: ValueKey(message.mediaUrl),
                                            url: _privateMediaUrl(
                                                state, message.mediaUrl!),
                                            headersGet: () =>
                                                _freshMediaHeaders(state),
                                            player: _voicePlayer,
                                            isMine: isMine,
                                          ),
                                          if (message.text.isNotEmpty)
                                            const SizedBox(height: 8),
                                        ] else if (message.mediaUrl !=
                                            null) ...[
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
                                                      state, message.mediaUrl!),
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
                    if (_recordingVoice)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: context.hairline),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Discard voice note',
                              onPressed: _cancelVoiceNote,
                              icon: const Icon(Icons.close_rounded),
                            ),
                            Icon(Icons.fiber_manual_record,
                                size: 14, color: context.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recording ${_voiceTime(_recordingElapsed)} · max 1:30',
                                style: TextStyle(
                                    color: context.ink,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton.filled(
                              tooltip: 'Send voice note',
                              onPressed: _finishingVoiceNote
                                  ? null
                                  : () => _finishVoiceNote(state),
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      )
                    else
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
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        const Icon(Icons.add_rounded),
                                        if (!_hasEnhancedChat(state)) ...[
                                          const SizedBox(width: 2),
                                          const _PlusLock(size: 12),
                                        ],
                                      ]),
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
                            onPressed: _uploadingMedia
                                ? null
                                : () => _toggleVoiceNote(state),
                            tooltip: _hasEnhancedChat(state)
                                ? 'Record voice note'
                                : 'Voice notes · Mhuri Plus',
                            icon: _uploadingMedia
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                        const Icon(Icons.mic_none_rounded),
                                        if (!_hasEnhancedChat(state)) ...[
                                          const SizedBox(width: 2),
                                          const _PlusLock(size: 12),
                                        ],
                                      ]),
                          ),
                          IconButton(
                            onPressed: () {
                              if (!_hasEnhancedChat(state)) {
                                unawaited(
                                    _showChatUpgrade('Emoji and stickers'));
                                return;
                              }
                              setState(() =>
                                  _showExpressionTray = !_showExpressionTray);
                            },
                            tooltip: 'Emoji and stickers',
                            icon:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(_showExpressionTray
                                  ? Icons.keyboard_rounded
                                  : Icons.sentiment_satisfied_alt_rounded),
                              if (!_hasEnhancedChat(state)) ...[
                                const SizedBox(width: 2),
                                const _PlusLock(size: 12),
                              ],
                            ]),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed:
                                _uploadingMedia ? null : () => _send(state),
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

class _PlusLock extends StatelessWidget {
  const _PlusLock({this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) => Icon(
        Icons.lock_outline_rounded,
        size: size,
        color: context.primary,
      );
}
