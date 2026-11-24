import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/db/app_database.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../l10n/generated/app_localizations.dart';
import 'ask_mhuri_history.dart';
import '../settings/plus_screen.dart';

class AskMhuriScreen extends StatefulWidget {
  const AskMhuriScreen({super.key});

  @override
  State<AskMhuriScreen> createState() => _AskMhuriScreenState();
}

class _AskMhuriScreenState extends State<AskMhuriScreen> {
  static const _suggestions = [
    'Can we afford something extra this month?',
    'How much can we save toward a goal?',
    'What bills are coming up?',
    'Where are we spending the most?',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatTurn> _turns = [];
  final List<AskMhuriConversation> _conversations = [];
  bool _sending = false;
  bool _historyLoading = false;
  bool _quotaReached = false;
  String? _statusMessage;
  String? _conversationId;
  String? _conversationTitle;
  String? _historyUserId;
  String? _historyFamilyId;
  int _scopeGeneration = 0;
  int? _remaining;
  int? _limit;
  String _plan = 'free';

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final userId = state.user.id;
    final familyId = state.sync?.spaceId;
    if (userId == _historyUserId && familyId == _historyFamilyId) return;
    _historyUserId = userId;
    _historyFamilyId = familyId;
    final generation = ++_scopeGeneration;
    _conversationId = null;
    _conversationTitle = null;
    _turns.clear();
    _conversations.clear();
    if (familyId != null && state.db != null) {
      unawaited(_loadInitialHistory(
        state.db!,
        userId,
        familyId,
        generation,
      ));
    }
  }

  String _activeChatKey(String userId, String familyId) =>
      'ask_mhuri_active_${userId}_$familyId';

  Future<void> _loadInitialHistory(
    AppDatabase db,
    String userId,
    String familyId,
    int generation,
  ) async {
    if (mounted) setState(() => _historyLoading = true);
    final store = AskMhuriHistoryStore(db.raw);
    try {
      final conversations = await store.listConversations(
        userId: userId,
        familyId: familyId,
      );
      final active = await db.kvGet(_activeChatKey(userId, familyId));
      if (!mounted || generation != _scopeGeneration) return;
      setState(() {
        _conversations
          ..clear()
          ..addAll(conversations);
        _historyLoading = false;
      });
      if (active == 'new' || conversations.isEmpty) return;
      AskMhuriConversation? selected;
      for (final conversation in conversations) {
        if (conversation.id == active) {
          selected = conversation;
          break;
        }
      }
      selected ??= conversations.first;
      await _openConversation(selected, db, userId, familyId);
    } catch (error) {
      debugPrint('Ask Mhuri history load failed: $error');
      if (mounted && generation == _scopeGeneration) {
        setState(() => _historyLoading = false);
      }
    }
  }

  Future<void> _openConversation(
    AskMhuriConversation conversation,
    AppDatabase db,
    String userId,
    String familyId,
  ) async {
    final messages = await AskMhuriHistoryStore(db.raw).loadMessages(
      conversationId: conversation.id,
      userId: userId,
      familyId: familyId,
    );
    if (!mounted || userId != _historyUserId || familyId != _historyFamilyId) {
      return;
    }
    final turns = <_ChatTurn>[];
    var latestQuestion = '';
    for (final message in messages) {
      final isAssistant = message.role == 'assistant';
      if (!isAssistant) latestQuestion = message.content;
      turns.add(_ChatTurn(
        text: message.content,
        question: isAssistant ? latestQuestion : '',
        isAssistant: isAssistant,
        facts: message.facts,
      ));
    }
    setState(() {
      _conversationId = conversation.id;
      _conversationTitle = conversation.title;
      _turns
        ..clear()
        ..addAll(turns);
      _statusMessage = null;
      _quotaReached = false;
    });
    await db.kvSet(_activeChatKey(userId, familyId), conversation.id);
    _scrollToEnd();
  }

  Future<void> _startNewChat() async {
    if (_sending) return;
    final state = AppScope.of(context);
    final userId = state.user.id;
    final familyId = state.sync?.spaceId;
    setState(() {
      _conversationId = null;
      _conversationTitle = null;
      _turns.clear();
      _statusMessage = null;
      _quotaReached = false;
      _input.clear();
    });
    if (familyId != null) {
      await state.db?.kvSet(_activeChatKey(userId, familyId), 'new');
    }
  }

  Future<void> _showHistory() async {
    final state = AppScope.of(context);
    final db = state.db;
    final userId = state.user.id;
    final familyId = state.sync?.spaceId;
    final l = AppLocalizations.of(context)!;
    if (db == null || familyId == null) return;
    final selection = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(l.chatHistoryTitle,
                          style: TextStyle(
                              fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.newChat),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _historyLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _conversations.isEmpty
                        ? Center(child: Text(l.noSavedChats))
                        : ListView.builder(
                            itemCount: _conversations.length,
                            itemBuilder: (context, index) {
                              final conversation = _conversations[index];
                              return ListTile(
                                leading: const Icon(
                                    Icons.chat_bubble_outline_rounded),
                                title: Text(conversation.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text(
                                    _historyDate(conversation.updatedAtMs)),
                                onTap: () => Navigator.pop(
                                  sheetContext,
                                  conversation.id,
                                ),
                                trailing: PopupMenuButton<String>(
                                  tooltip: l.chatOptions,
                                  onSelected: (action) async {
                                    Navigator.pop(sheetContext);
                                    if (action == 'rename') {
                                      await _renameConversation(
                                        conversation,
                                        db,
                                        userId,
                                        familyId,
                                      );
                                    } else if (action == 'delete') {
                                      await _deleteConversation(
                                        conversation,
                                        db,
                                        userId,
                                        familyId,
                                      );
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    PopupMenuItem(
                                      value: 'rename',
                                      child: Text(l.renameChat),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text(l.delete),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (selection == true) {
      await _startNewChat();
    } else if (selection is String) {
      final chosen = _conversations.where((c) => c.id == selection).firstOrNull;
      if (chosen != null) {
        await _openConversation(chosen, db, userId, familyId);
      }
    }
  }

  Future<void> _renameConversation(
    AskMhuriConversation conversation,
    AppDatabase db,
    String userId,
    String familyId,
  ) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.renameChat),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 52,
          decoration: InputDecoration(labelText: l.chatName),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty || !mounted) return;
    await AskMhuriHistoryStore(db.raw).renameConversation(
      conversationId: conversation.id,
      userId: userId,
      familyId: familyId,
      title: title,
    );
    if (!mounted) return;
    final updated = AskMhuriConversation(
      id: conversation.id,
      title: title.trim(),
      createdAtMs: conversation.createdAtMs,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() {
      final index = _conversations.indexWhere((c) => c.id == conversation.id);
      if (index >= 0) _conversations[index] = updated;
      if (_conversationId == conversation.id)
        _conversationTitle = updated.title;
    });
  }

  Future<void> _deleteConversation(
    AskMhuriConversation conversation,
    AppDatabase db,
    String userId,
    String familyId,
  ) async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.deleteChatQuestion),
        content: Text(
            '“${conversation.title}” and its messages will be deleted from this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AskMhuriHistoryStore(db.raw).deleteConversation(
      conversationId: conversation.id,
      userId: userId,
      familyId: familyId,
    );
    await db.kvDelete(_activeChatKey(userId, familyId));
    if (!mounted) return;
    setState(() {
      _conversations.removeWhere((c) => c.id == conversation.id);
      if (_conversationId == conversation.id) {
        _conversationId = null;
        _conversationTitle = null;
        _turns.clear();
      }
    });
  }

  String _historyDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _send([String? suggested]) async {
    final question = (suggested ?? _input.text).trim();
    final state = AppScope.of(context);
    final engine = state.sync;
    final database = state.db;
    final userId = state.user.id;
    final familyId = state.sync?.spaceId;
    final requestGeneration = _scopeGeneration;
    final requestConversationId = _conversationId ?? newUuid();
    if (question.isEmpty || _sending || engine == null || !state.hasSpace) {
      return;
    }
    final history = _turns
        .skip((_turns.length - 6).clamp(0, _turns.length).toInt())
        .map((turn) => {
              'role': turn.isAssistant ? 'assistant' : 'user',
              'text': turn.text,
            })
        .toList(growable: false);
    setState(() {
      _sending = true;
      _quotaReached = false;
      _statusMessage = null;
      _turns.add(_ChatTurn(text: question));
      _input.clear();
    });
    _scrollToEnd();
    try {
      final result = await engine.askMhuri(question, history: history);
      final facts = result['facts'] is Map
          ? Map<String, Object?>.from(result['facts'] as Map)
          : const <String, Object?>{};
      final answer =
          result['answer']?.toString() ?? 'I could not prepare an answer.';
      AskMhuriConversation? savedConversation;
      if (database != null && familyId != null) {
        try {
          savedConversation =
              await AskMhuriHistoryStore(database.raw).saveExchange(
            conversationId: requestConversationId,
            userId: userId,
            familyId: familyId,
            question: question,
            answer: answer,
            facts: facts,
            createdAtMs: DateTime.now().millisecondsSinceEpoch,
          );
          if (requestGeneration == _scopeGeneration && mounted) {
            await database.kvSet(
              _activeChatKey(userId, familyId),
              savedConversation.id,
            );
            _conversations.removeWhere((c) => c.id == savedConversation!.id);
            _conversations.insert(0, savedConversation);
          }
        } catch (error) {
          debugPrint('Ask Mhuri history save failed: $error');
        }
      }
      if (!mounted) return;
      if (requestGeneration != _scopeGeneration) return;
      setState(() {
        _conversationId = requestConversationId;
        _conversationTitle =
            savedConversation?.title ?? _conversationTitle ?? question;
        _turns.add(_ChatTurn(
          question: question,
          text: answer,
          isAssistant: true,
          facts: facts,
        ));
        _remaining = (result['quota_remaining'] as num?)?.toInt();
        _limit = (result['quota_limit'] as num?)?.toInt();
        _plan = result['plan']?.toString() ?? 'free';
      });
    } catch (error) {
      if (!mounted) return;
      final errorText = error.toString();
      final message = _friendlyError(error);
      setState(() {
        _statusMessage = message;
        _quotaReached = errorText.contains('QUOTA_EXCEEDED');
        if (_quotaReached) _remaining = 0;
        if (_turns.isNotEmpty && !_turns.last.isAssistant) _turns.removeLast();
      });
      _input.text = question;
    } finally {
      if (mounted) {
        if (requestGeneration == _scopeGeneration) {
          setState(() => _sending = false);
          _scrollToEnd();
        }
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('QUOTA_EXCEEDED')) {
      return 'You’ve reached today’s Ask Mhuri limit. Try again after the daily reset.';
    }
    if (text.contains('AI_BUSY')) {
      return 'A few Ask Mhuri requests are still processing. Please try again in a moment.';
    }
    if (text.contains('AI_PROVIDER_TIMEOUT')) {
      return 'That took longer than expected. Your daily allowance was not used; please try again shortly.';
    }
    if (text.contains('AI_REQUEST_TIMEOUT')) {
      return 'This request took too long to complete. Please try again shortly.';
    }
    if (text.contains('AUTH_SERVICE_UNAVAILABLE')) {
      return 'Mhuri could not verify your sign-in just now. Please try again shortly.';
    }
    if (text.contains('QUOTA_FINALIZATION_FAILED')) {
      return 'Mhuri could not confirm this request. No answer was shown; please try again shortly.';
    }
    if (text.contains('AI_NOT_ENABLED') || text.contains('AI_NOT_CONFIGURED')) {
      return 'Ask Mhuri is being prepared and is not available yet.';
    }
    if (text.contains('ROLE_NOT_SUPPORTED')) {
      return 'Ask Mhuri is currently available to adult family roles.';
    }
    if (text.contains('NOT_AUTHENTICATED') ||
        text.contains('FAMILY_REQUIRED')) {
      return 'Please reconnect to your family and try again.';
    }
    if (text.contains('AI_PROVIDER_UNAVAILABLE') ||
        text.contains('AI_REQUEST_FAILED')) {
      return 'Ask Mhuri is temporarily busy. Your question was not saved and your daily limit was not used. Please try again shortly.';
    }
    return 'I couldn’t answer just now. Check your connection and try again.';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        unawaited(_scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final plus = state.hasPlus;
    final dailyLimit = _limit ?? (plus ? 50 : 5);
    final dailyRemaining = _remaining ?? dailyLimit;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, size: 23, color: context.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ask Mhuri',
                      style: TextStyle(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(_conversationTitle ?? 'Family money, made clearer',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context)!.chatHistoryTitle,
            onPressed: _showHistory,
            icon: Badge(
              isLabelVisible: _conversations.isNotEmpty,
              smallSize: 7,
              child: const Icon(Icons.history_rounded),
            ),
          ),
          IconButton(
            tooltip: AppLocalizations.of(context)!.newChat,
            onPressed: _sending ? null : _startNewChat,
            icon: const Icon(Icons.edit_outlined),
          ),
          if (!plus)
            IconButton(
              tooltip: 'Explore Mhuri Plus',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlusScreen()),
              ),
              icon: const Icon(Icons.workspace_premium_outlined),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _QuotaStrip(
              remaining: _remaining,
              limit: dailyLimit,
              plus: _plan == 'plus' || plus,
            ),
            Expanded(
              child: _turns.isEmpty
                  ? _Welcome(onSelect: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                      itemCount: _turns.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _turns.length) {
                          return const _ThinkingBubble();
                        }
                        final turn = _turns[index];
                        return _MessageBubble(turn: turn);
                      },
                    ),
            ),
            if (_statusMessage != null)
              _ErrorNotice(
                message: _statusMessage!,
                showUpgrade: _quotaReached && !plus && _plan != 'plus',
              ),
            const _GroundingNote(),
            _Composer(
              controller: _input,
              sending: _sending,
              enabled:
                  dailyRemaining > 0 || _plan == 'free' && _remaining == null,
              onSend: () => _send(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTurn {
  const _ChatTurn({
    required this.text,
    this.question = '',
    this.isAssistant = false,
    this.facts = const {},
  });
  final String text;
  final String question;
  final bool isAssistant;
  final Map<String, Object?> facts;
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onSelect});
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [context.primarySoft, context.card],
              ),
              borderRadius: kBRadiusL,
              border: Border.all(color: context.hairline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    color: context.primary, size: 26),
                const SizedBox(height: 17),
                Text('Make your next money decision with more clarity.',
                    style: MhuriType.titleL.copyWith(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                    )),
                const SizedBox(height: 9),
                Text(
                  'Ask about your budget, upcoming bills, or a savings goal. Mhuri uses the family information you’ve recorded.',
                  style: TextStyle(color: context.inkSoft, height: 1.45),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.lock_outline_rounded,
                        size: 15, color: context.inkFaint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Private accounts are excluded from shared answers.',
                        style: TextStyle(fontSize: 11, color: context.inkFaint),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          Text('TRY ASKING',
              style: TextStyle(
                color: context.inkFaint,
                fontSize: 10,
                letterSpacing: 1.15,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 10),
          for (final question in _AskMhuriScreenState._suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: context.card,
                borderRadius: kBRadiusM,
                child: InkWell(
                  borderRadius: kBRadiusM,
                  onTap: () => onSelect(question),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: kBRadiusM,
                      border: Border.all(color: context.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(question,
                                style: TextStyle(
                                    color: context.ink, fontSize: 13))),
                        Icon(Icons.arrow_outward_rounded,
                            size: 16, color: context.inkFaint),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _QuotaStrip extends StatelessWidget {
  const _QuotaStrip(
      {required this.remaining, required this.limit, required this.plus});
  final int? remaining;
  final int limit;
  final bool plus;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: context.card,
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Row(
          children: [
            Icon(plus ? Icons.auto_awesome : Icons.chat_bubble_outline_rounded,
                size: 14, color: context.primary),
            const SizedBox(width: 7),
            Text(
                remaining == null
                    ? 'Up to $limit questions a day'
                    : '$remaining of $limit questions left today',
                style: TextStyle(fontSize: 11, color: context.inkSoft)),
            const Spacer(),
            if (plus)
              Text('PLUS',
                  style: TextStyle(
                    color: context.primary,
                    fontSize: 9,
                    letterSpacing: .8,
                    fontWeight: FontWeight.w900,
                  )),
          ],
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.turn});
  final _ChatTurn turn;

  @override
  Widget build(BuildContext context) {
    if (!turn.isAssistant) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(top: 5, bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: context.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(kRadiusM),
              topRight: Radius.circular(kRadiusM),
              bottomLeft: Radius.circular(kRadiusM),
              bottomRight: Radius.circular(kRadiusXS),
            ),
          ),
          child: Text(turn.text,
              style: TextStyle(color: context.onSolid, height: 1.4)),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(top: 4, bottom: 15),
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 13),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(kRadiusXS),
            topRight: Radius.circular(kRadiusM),
            bottomLeft: Radius.circular(kRadiusM),
            bottomRight: Radius.circular(kRadiusM),
          ),
          border: Border.all(color: context.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded,
                  size: 15, color: context.primary),
              const SizedBox(width: 7),
              Text('ASK MHURI',
                  style: TextStyle(
                    color: context.primary,
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                  )),
            ]),
            const SizedBox(height: 9),
            Text(turn.text, style: TextStyle(color: context.ink, height: 1.45)),
            if (turn.facts.isNotEmpty) ...[
              const SizedBox(height: 12),
              _FactsCard(facts: turn.facts, question: turn.question),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactsCard extends StatelessWidget {
  const _FactsCard({required this.facts, required this.question});
  final Map<String, Object?> facts;
  final String question;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[];
    final query = question.toLowerCase();
    void appendTotals(String key, String label) {
      final values = facts[key];
      if (values is List && values.isNotEmpty) {
        final currencies = values
            .whereType<Map>()
            .take(2)
            .map((row) => _amount(row['minor_units'], row['currency']));
        if (currencies.isNotEmpty) rows.add((label, currencies.join('  ·  ')));
      }
    }

    final budgets = facts['budgets'];
    final bills = facts['upcoming_commitments'];
    final goals = facts['savings_goals'];
    final debts = facts['debts'];
    final categories = facts['top_categories'];
    final purchaseScenario = facts['purchase_scenario'];

    void appendPurchaseScenario() {
      if (purchaseScenario is! Map) return;
      if (purchaseScenario['status'] == 'currency_required') {
        rows.add(('Purchase estimate', 'Please confirm the currency'));
        return;
      }
      if (purchaseScenario['status'] == 'insufficient_balance_data') {
        rows.add(('Purchase estimate', 'Not enough recorded balance data'));
        return;
      }
      final currency = purchaseScenario['currency'];
      rows.add((
        'After upcoming bills and purchase',
        _amount(purchaseScenario['estimated_after_purchase_minor'], currency),
      ));
      rows.add((
        'Purchase check',
        purchaseScenario['fits_recorded_cash_estimate'] == true
            ? 'Within recorded estimate'
            : 'Above recorded estimate',
      ));
    }

    void appendBudgets([int count = 2]) {
      if (budgets is List) {
        for (final budget in budgets
            .whereType<Map>()
            .where((budget) => budget['complete'] == true)
            .where((budget) => query
                .contains((budget['name']?.toString() ?? '').toLowerCase()))
            .take(count)) {
          rows.add((
            '${budget['name'] ?? 'Budget'} left',
            _amount(budget['remaining_minor'], budget['currency']),
          ));
        }
      }
    }

    void appendBills([int count = 2]) {
      if (bills is List) {
        for (final bill in bills.whereType<Map>().take(count)) {
          rows.add((
            '${bill['name'] ?? 'Upcoming bill'} · ${_date(bill['due_date'])}',
            _amount(bill['amount_minor'], bill['currency']),
          ));
        }
      }
    }

    void appendGoals([int count = 2]) {
      if (goals is List) {
        for (final goal in goals
            .whereType<Map>()
            .where((goal) => goal['complete'] == true)
            .take(count)) {
          rows.add((
            '${goal['name'] ?? 'Goal'} remaining',
            _amount(goal['remaining_minor'], goal['currency']),
          ));
        }
      }
    }

    void appendDebts([int count = 2]) {
      if (debts is List) {
        for (final debt in debts
            .whereType<Map>()
            .where((debt) => debt['complete'] == true)
            .take(count)) {
          rows.add((
            '${debt['name'] ?? 'Debt'} remaining',
            _amount(debt['remaining_minor'], debt['currency']),
          ));
        }
      }
    }

    void appendCategories([int count = 2]) {
      if (categories is List) {
        for (final category in categories.whereType<Map>().take(count)) {
          rows.add((
            '${category['name'] ?? 'Category'} spent',
            _amount(category['spent_minor'], category['currency']),
          ));
        }
      }
    }

    if (RegExp(r'\b(save|saving|goal|target)\b').hasMatch(query)) {
      appendGoals(3);
      appendTotals(
          'available_after_recorded_savings', 'Available after savings');
    } else if (RegExp(r'\b(debt|loan|repay|owe)\b').hasMatch(query)) {
      appendDebts(3);
      appendTotals(
          'available_after_recorded_savings', 'Available after savings');
    } else if (RegExp(r'\b(bill|due|commitment|rent)\b').hasMatch(query)) {
      appendBills(4);
      appendTotals(
          'available_after_recorded_savings', 'Available after savings');
    } else if (RegExp(r'\b(afford|buy|purchase|spend|extra|payday)\b')
        .hasMatch(query)) {
      appendPurchaseScenario();
      appendTotals(
          'available_after_recorded_savings', 'Available after savings');
      appendBills(2);
      appendBudgets(1);
    } else if (RegExp(
            r'\b(compare|compared|last month|previous|trend|more|less)\b')
        .hasMatch(query)) {
      appendTotals('cycle_spending', 'Spent this period');
      appendTotals('previous_cycle_spending', 'Spent previous period');
      appendCategories(2);
    } else {
      appendTotals('cycle_spending', 'Spent this period');
      appendTotals('cycle_income', 'Income this period');
      appendCategories(3);
    }
    final balances = facts['account_balances_estimate'];
    if (balances is List && balances.isNotEmpty) {
      final first = balances.whereType<Map>().firstOrNull;
      if (first != null) {
        rows.add((
          'Recorded balance estimate',
          _amount(first['minor_units'], first['currency']),
        ));
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: context.bg,
        borderRadius: kBRadiusM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NUMBERS USED',
              style: TextStyle(
                color: context.inkFaint,
                fontSize: 9,
                letterSpacing: .9,
                fontWeight: FontWeight.w800,
              )),
          const SizedBox(height: 7),
          if (rows.isEmpty)
            Text('No matching recorded figures for this question.',
                style: TextStyle(fontSize: 11, color: context.inkSoft))
          else
            for (final row in rows.take(4))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(row.$1,
                            style: TextStyle(
                                fontSize: 11, color: context.inkSoft))),
                    Flexible(
                        child: Text(row.$2,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: context.ink))),
                  ],
                ),
              ),
          const SizedBox(height: 7),
          Text('Based on recorded family data. Some costs may be missing.',
              style: TextStyle(fontSize: 10, color: context.inkFaint)),
        ],
      ),
    );
  }

  static String _amount(Object? minor, Object? currency) {
    final code = currency?.toString().toUpperCase();
    final value = (minor as num?)?.toInt();
    if (value == null) return '—';
    final match =
        Currency.values.where((item) => item.code == code).firstOrNull;
    return match == null
        ? '$code ${(value / 100).toStringAsFixed(2)}'
        : Money(value, match).text;
  }

  static String _date(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (date == null) return 'date not set';
    return '${date.day}/${date.month}';
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: context.card,
            border: Border.all(color: context.hairline),
            borderRadius: kBRadiusM,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.primary,
              ),
            ),
            const SizedBox(width: 9),
            Text('Checking your family’s plan…',
                style: TextStyle(fontSize: 12, color: context.inkSoft)),
          ]),
        ),
      );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.showUpgrade});
  final String message;
  final bool showUpgrade;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 5, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: context.dangerSoft,
          borderRadius: kBRadiusM,
        ),
        child: Row(children: [
          Expanded(
              child: Text(message,
                  style: TextStyle(fontSize: 12, color: context.ink))),
          if (showUpgrade)
            TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlusScreen()),
              ),
              child: const Text('Explore Mhuri Plus'),
            ),
        ]),
      );
}

class _GroundingNote extends StatelessWidget {
  const _GroundingNote();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 5, 18, 8),
        child: Text(
          'Ask Mhuri uses your question, recent chat context, and selected shared financial figures to prepare an answer. Private account details are excluded; estimates use Mhuri records.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: context.inkFaint),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.enabled,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 4, 5, 4),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: kBRadiusL,
            border: Border.all(color: context.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .035),
                blurRadius: 18,
                offset: const Offset(0, 6),
              )
            ],
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                inputFormatters: [LengthLimitingTextInputFormatter(800)],
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Ask about your family’s money…',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled && !sending ? onSend : null,
              style: IconButton.styleFrom(
                backgroundColor: context.primary,
                foregroundColor: context.onSolid,
                disabledBackgroundColor: context.hairline,
              ),
              icon: sending
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_upward_rounded, size: 19),
            ),
          ]),
        ),
      );
}
