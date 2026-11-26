import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ai/ask_mhuri_local_engine.dart';
import '../../core/db/app_database.dart';
import '../../core/models/models.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/ids.dart';
import '../../l10n/generated/app_localizations.dart';
import '../budgets/budgets_screen.dart';
import '../commitments/commitments_screen.dart';
import '../lists/lists_screen.dart';
import '../reports/reports_screen.dart';
import '../savings/savings_screen.dart';
import '../settings/plus_screen.dart';
import 'ask_mhuri_history.dart';

class AskMhuriScreen extends StatefulWidget {
  const AskMhuriScreen({super.key});

  @override
  State<AskMhuriScreen> createState() => _AskMhuriScreenState();
}

class _AskMhuriScreenState extends State<AskMhuriScreen> {
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
      final source = message.facts['source']?.toString();
      turns.add(_ChatTurn(
        text: message.content,
        question: isAssistant ? latestQuestion : '',
        isAssistant: isAssistant,
        isLocal: source == 'local' || source == 'local_fallback',
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
                          style: const TextStyle(
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
      if (_conversationId == conversation.id) {
        _conversationTitle = updated.title;
      }
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

  Future<AskMhuriConversation?> _persistExchange({
    required AppDatabase? database,
    required String? familyId,
    required String userId,
    required String conversationId,
    required String question,
    required String answer,
    required Map<String, Object?> facts,
    required int requestGeneration,
  }) async {
    if (database == null || familyId == null) return null;
    try {
      final savedConversation =
          await AskMhuriHistoryStore(database.raw).saveExchange(
        conversationId: conversationId,
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
        _conversations.removeWhere((c) => c.id == savedConversation.id);
        _conversations.insert(0, savedConversation);
      }
      return savedConversation;
    } catch (error) {
      debugPrint('Ask Mhuri history save failed: $error');
      return null;
    }
  }

  Future<void> _send([String? suggested, bool forceCloud = false]) async {
    final question = (suggested ?? _input.text).trim();
    if (question.isEmpty || _sending) return;

    final state = AppScope.of(context);
    if (state.authRole == Role.kid || state.authRole == Role.teen) {
      setState(() {
        _statusMessage = 'Ask Mhuri is currently available to adult family roles.';
      });
      return;
    }

    final engine = state.sync;
    final database = state.db;
    final userId = state.user.id;
    final familyId = state.sync?.spaceId;
    final requestGeneration = _scopeGeneration;
    final requestConversationId = _conversationId ?? newUuid();
    final hasPriorTurns = _turns.isNotEmpty;

    // 1. Instant local fast-path (<5ms, 0 daily quota used, works 100% offline).
    if (!forceCloud) {
      final local = AskMhuriLocalEngine.tryAnswer(
        state,
        question,
        hasPriorTurns: hasPriorTurns,
      );
      if (local != null) {
        final localFacts = <String, Object?>{
          ...local.facts,
          'source': 'local',
        };
        if (suggested == null) _input.clear();
        setState(() {
          _statusMessage = null;
          _turns.add(_ChatTurn(text: question));
          _turns.add(_ChatTurn(
            question: question,
            text: local.answer,
            isAssistant: true,
            isLocal: true,
            facts: localFacts,
            followUps: local.followUps,
          ));
          _conversationId = requestConversationId;
          _conversationTitle ??= question;
        });
        _scrollToEnd();
        final saved = await _persistExchange(
          database: database,
          familyId: familyId,
          userId: userId,
          conversationId: requestConversationId,
          question: question,
          answer: local.answer,
          facts: localFacts,
          requestGeneration: requestGeneration,
        );
        if (mounted && requestGeneration == _scopeGeneration && saved != null) {
          setState(() => _conversationTitle = saved.title);
        }
        return;
      }
    }

    // 2. If cloud sync is not set up yet, serve an accurate local household answer
    // immediately rather than dropping the user's question.
    if (engine == null || !state.hasSpace) {
      final fallback = AskMhuriLocalEngine.fallbackAnswer(state, question);
      final localFacts = <String, Object?>{
        ...fallback.facts,
        'source': 'local_fallback',
      };
      if (suggested == null) _input.clear();
      setState(() {
        _statusMessage = null;
        if (!forceCloud) _turns.add(_ChatTurn(text: question));
        _turns.add(_ChatTurn(
          question: question,
          text: fallback.answer,
          isAssistant: true,
          isLocal: true,
          facts: localFacts,
          followUps: fallback.followUps,
        ));
        _conversationId = requestConversationId;
        _conversationTitle ??= question;
      });
      _scrollToEnd();
      return;
    }

    // 3. Cloud AI path (uses fast get_ask_mhuri_context RPC + OpenRouter/Gemini failover).
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
      if (!forceCloud) {
        _turns.add(_ChatTurn(text: question));
        _input.clear();
      }
    });
    _scrollToEnd();

    try {
      final result = await engine.askMhuri(question, history: history);
      final facts = result['facts'] is Map
          ? Map<String, Object?>.from(result['facts'] as Map)
          : const <String, Object?>{};
      final answer =
          result['answer']?.toString() ?? 'I could not prepare an answer.';
      final savedConversation = await _persistExchange(
        database: database,
        familyId: familyId,
        userId: userId,
        conversationId: requestConversationId,
        question: question,
        answer: answer,
        facts: facts,
        requestGeneration: requestGeneration,
      );
      if (!mounted || requestGeneration != _scopeGeneration) return;
      final topic = AskMhuriLocalEngine.inferTopic(question);
      setState(() {
        _conversationId = requestConversationId;
        _conversationTitle =
            savedConversation?.title ?? _conversationTitle ?? question;
        _turns.add(_ChatTurn(
          question: question,
          text: answer,
          isAssistant: true,
          isLocal: false,
          facts: facts,
          followUps: AskMhuriLocalEngine.followUpsFor(topic),
        ));
        _remaining = (result['quota_remaining'] as num?)?.toInt();
        _limit = (result['quota_limit'] as num?)?.toInt();
        _plan = result['plan']?.toString() ?? 'free';
      });
    } catch (error) {
      if (!mounted || requestGeneration != _scopeGeneration) return;
      final errorText = error.toString();
      final isQuota = errorText.contains('QUOTA_EXCEEDED');
      final isAuthOrRole = errorText.contains('ROLE_NOT_SUPPORTED') ||
          errorText.contains('NOT_AUTHENTICATED') ||
          errorText.contains('FAMILY_ACCESS_DENIED');
      final message = _friendlyError(error);

      if (!forceCloud && !isAuthOrRole) {
        // Give an immediate local snapshot so offline or quota-limited users
        // still get their recorded family numbers right away.
        final fallback = AskMhuriLocalEngine.fallbackAnswer(state, question);
        final fallbackFacts = <String, Object?>{
          ...fallback.facts,
          'source': 'local_fallback',
        };
        setState(() {
          _statusMessage = message;
          _quotaReached = isQuota;
          if (_quotaReached) _remaining = 0;
          _conversationId = requestConversationId;
          _conversationTitle ??= question;
          _turns.add(_ChatTurn(
            question: question,
            text: fallback.answer,
            isAssistant: true,
            isLocal: true,
            facts: fallbackFacts,
            followUps: fallback.followUps,
          ));
        });
      } else {
        setState(() {
          _statusMessage = message;
          _quotaReached = isQuota;
          if (_quotaReached) _remaining = 0;
          if (!forceCloud && _turns.isNotEmpty && !_turns.last.isAssistant) {
            _turns.removeLast();
            _input.text = question;
          }
        });
      }
    } finally {
      if (mounted && requestGeneration == _scopeGeneration) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('QUOTA_EXCEEDED')) {
      return 'You’ve reached today’s cloud AI limit — instant local answers remain available anytime.';
    }
    if (text.contains('AI_BUSY')) {
      return 'A few Ask Mhuri requests are still processing. Please try again in a moment.';
    }
    if (text.contains('AI_PROVIDER_TIMEOUT')) {
      return 'Cloud AI took longer than expected. Your daily allowance was not used.';
    }
    if (text.contains('AI_REQUEST_TIMEOUT')) {
      return 'This cloud request took too long. Showing recorded figures from your device.';
    }
    if (text.contains('AUTH_SERVICE_UNAVAILABLE')) {
      return 'Mhuri could not verify your sign-in just now. Showing recorded device figures.';
    }
    if (text.contains('QUOTA_FINALIZATION_FAILED')) {
      return 'Mhuri could not confirm cloud usage just now. Please try again shortly.';
    }
    if (text.contains('AI_NOT_ENABLED') || text.contains('AI_NOT_CONFIGURED')) {
      return 'Cloud AI coaching is not active right now — showing instant answers from your device.';
    }
    if (text.contains('ROLE_NOT_SUPPORTED')) {
      return 'Ask Mhuri is currently available to adult family roles.';
    }
    if (text.contains('NOT_AUTHENTICATED') ||
        text.contains('FAMILY_REQUIRED')) {
      return 'Please reconnect to your family to use cloud AI advice.';
    }
    if (text.contains('AI_PROVIDER_UNAVAILABLE') ||
        text.contains('AI_REQUEST_FAILED')) {
      return 'Cloud AI is temporarily busy (your daily limit was not used). Showing recorded device figures.';
    }
    return 'Offline or unable to reach cloud AI — showing recorded figures from this device.';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        unawaited(_scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l = AppLocalizations.of(context)!;
    final plus = state.hasPlus;
    final dailyLimit = _limit ?? (plus ? 50 : 5);
    final dailyRemaining = _remaining ?? dailyLimit;
    final canEscalateToCloud = !_sending &&
        state.hasSpace &&
        state.sync != null &&
        (dailyRemaining > 0 || (_plan == 'free' && _remaining == null));

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
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (state.hasSpace && state.db != null)
            IconButton(
              tooltip: l.chatHistoryTitle,
              onPressed: _showHistory,
              icon: Badge(
                isLabelVisible: _conversations.isNotEmpty,
                smallSize: 7,
                child: const Icon(Icons.history_rounded),
              ),
            ),
          IconButton(
            tooltip: l.newChat,
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
            if (state.hasSpace)
              _QuotaStrip(
                remaining: _remaining,
                limit: dailyLimit,
                plus: _plan == 'plus' || plus,
              ),
            Expanded(
              child: _turns.isEmpty
                  ? _Welcome(state: state, onSelect: _send)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      itemCount: _turns.length + (_sending ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_sending && index == _turns.length) {
                          return const _ThinkingBubble();
                        }
                        final turn = _turns[index];
                        final isLatestAssistant =
                            turn.isAssistant && index == _turns.length - 1;
                        return _MessageBubble(
                          turn: turn,
                          showFollowUps: isLatestAssistant && !_sending,
                          canAskDeepCloud:
                              turn.isLocal && canEscalateToCloud && isLatestAssistant,
                          onAskDeepCloud: () => _send(turn.question, true),
                          onSelectFollowUp: _send,
                        );
                      },
                    ),
            ),
            if (_statusMessage != null)
              _ErrorNotice(
                message: _statusMessage!,
                showUpgrade: _quotaReached && !plus && _plan != 'plus',
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
              child: Text(
                l.askMhuriPrivacyCaption,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: context.inkFaint),
              ),
            ),
            _Composer(
              controller: _input,
              sending: _sending,
              enabled: !_sending,
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
    this.isLocal = false,
    this.facts = const {},
    this.followUps = const [],
  });

  final String text;
  final String question;
  final bool isAssistant;
  final bool isLocal;
  final Map<String, Object?> facts;
  final List<String> followUps;
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.state, required this.onSelect});

  final AppState state;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = state.primaryCurrency;
    final available = state.availableToSpend(c);
    final spent = state.monthSpend;
    final upcomingCount = state.upcomingCommitments().length +
        state.recurring
            .where((r) =>
                r.active &&
                !r.isArchived &&
                !r.nextDue.isAfter(state.now.add(const Duration(days: 45))))
            .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
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
              Icon(Icons.auto_awesome_rounded, color: context.primary, size: 25),
              const SizedBox(height: 12),
              Text(
                'Make your next money decision with more clarity.',
                style: MhuriType.titleL.copyWith(
                  fontSize: 20,
                  height: 1.22,
                  fontWeight: FontWeight.w700,
                  color: context.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.askMhuriPrompt,
                style: TextStyle(color: context.inkSoft, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.card.withValues(alpha: .88),
                  borderRadius: kBRadiusM,
                  border: Border.all(color: context.hairline),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PulseStat(
                        value: available.text,
                        caption: '${c.short} available',
                      ),
                    ),
                    Container(width: 1, height: 26, color: context.hairline),
                    Expanded(
                      child: _PulseStat(
                        value: spent.text,
                        caption: '${spent.currency.short} spent',
                      ),
                    ),
                    Container(width: 1, height: 26, color: context.hairline),
                    Expanded(
                      child: _PulseStat(
                        value: '$upcomingCount',
                        caption: '${upcomingCount == 1 ? 'bill' : 'bills'} due',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'TRY ASKING',
          style: TextStyle(
            color: context.inkFaint,
            fontSize: 10,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (final question in AskMhuriLocalEngine.starterQuestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: context.card,
              borderRadius: kBRadiusM,
              child: InkWell(
                borderRadius: kBRadiusM,
                onTap: () => onSelect(question),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    borderRadius: kBRadiusM,
                    border: Border.all(color: context.hairline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.bolt_rounded,
                          size: 16, color: context.primary),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          question,
                          style: TextStyle(
                            color: context.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({required this.value, required this.caption});

  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: context.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: context.inkFaint),
            ),
          ],
        ),
      );
}

class _QuotaStrip extends StatelessWidget {
  const _QuotaStrip({
    required this.remaining,
    required this.limit,
    required this.plus,
  });

  final int? remaining;
  final int limit;
  final bool plus;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: context.card,
          border: Border(bottom: BorderSide(color: context.hairline)),
        ),
        child: Row(
          children: [
            Icon(plus ? Icons.auto_awesome : Icons.chat_bubble_outline_rounded,
                size: 14, color: context.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                remaining == null
                    ? 'Instant answers free · Up to $limit deep AI questions/day'
                    : 'Instant answers free · $remaining of $limit AI questions left today',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.inkSoft),
              ),
            ),
            if (plus)
              Text(
                'PLUS',
                style: TextStyle(
                  color: context.primary,
                  fontSize: 9,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.turn,
    required this.showFollowUps,
    required this.canAskDeepCloud,
    required this.onAskDeepCloud,
    required this.onSelectFollowUp,
  });

  final _ChatTurn turn;
  final bool showFollowUps;
  final bool canAskDeepCloud;
  final VoidCallback onAskDeepCloud;
  final ValueChanged<String> onSelectFollowUp;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (!turn.isAssistant) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(top: 4, bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
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

    final topic = AskMhuriLocalEngine.inferTopic(turn.question);
    final followUps = turn.followUps.isNotEmpty
        ? turn.followUps
        : AskMhuriLocalEngine.followUpsFor(topic);

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 380),
            margin: const EdgeInsets.only(top: 2, bottom: 10),
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
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
                Row(
                  children: [
                    Icon(
                      turn.isLocal
                          ? Icons.bolt_rounded
                          : Icons.auto_awesome_rounded,
                      size: 15,
                      color: context.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ASK MHURI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.primary,
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (turn.isLocal) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l.askMhuriInstantBadge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: context.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                _FormattedAnswerText(text: turn.text),
                if (turn.facts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _FactsCard(facts: turn.facts, question: turn.question),
                ],
                const SizedBox(height: 10),
                _ActionShortcutsRow(
                  topic: topic,
                  canAskDeepCloud: canAskDeepCloud,
                  onAskDeepCloud: onAskDeepCloud,
                ),
              ],
            ),
          ),
          if (showFollowUps && followUps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.askMhuriFollowUpLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.inkFaint,
                    ),
                  ),
                  for (final prompt in followUps.take(2))
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: context.card,
                      side: BorderSide(color: context.hairline),
                      label: Text(
                        prompt,
                        style: TextStyle(fontSize: 11.5, color: context.ink),
                      ),
                      onPressed: () => onSelectFollowUp(prompt),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders clean rich text (`**bold**`, `*italic*`, and `- ` / numbered bullets)
/// without raw Markdown asterisks or heavy external dependencies.
class _FormattedAnswerText extends StatelessWidget {
  const _FormattedAnswerText({required this.text});

  final String text;

  static final _bulletPattern = RegExp(r'^(?:[-*•]|\d+\.)\s+(.*)$');
  static final _headingPattern = RegExp(r'^#{1,4}\s+');
  static final _inlineToken = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(color: context.ink, fontSize: 14, height: 1.46);
    final lines = text
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList(growable: false);

    if (lines.isEmpty) {
      return Text(text, style: baseStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: _buildLine(context, lines[i].trimLeft(), baseStyle),
          ),
      ],
    );
  }

  Widget _buildLine(BuildContext context, String rawLine, TextStyle baseStyle) {
    final cleaned = rawLine.replaceFirst(_headingPattern, '');
    final bulletMatch = _bulletPattern.firstMatch(cleaned);
    if (bulletMatch != null) {
      final body = bulletMatch.group(1) ?? '';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: context.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(children: _parseInlineSpans(body, baseStyle)),
              style: baseStyle,
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(children: _parseInlineSpans(cleaned, baseStyle)),
      style: baseStyle,
    );
  }

  static List<InlineSpan> _parseInlineSpans(String input, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final match in _inlineToken.allMatches(input)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: input.substring(cursor, match.start)));
      }
      final boldText = match.group(1);
      final italicText = match.group(2);
      if (boldText != null) {
        spans.add(TextSpan(
          text: boldText,
          style: baseStyle.copyWith(fontWeight: FontWeight.w700),
        ));
      } else if (italicText != null) {
        spans.add(TextSpan(
          text: italicText,
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      cursor = match.end;
    }
    if (cursor < input.length) {
      spans.add(TextSpan(text: input.substring(cursor)));
    }
    return spans.isEmpty ? [TextSpan(text: input)] : spans;
  }
}

class _ActionShortcutsRow extends StatelessWidget {
  const _ActionShortcutsRow({
    required this.topic,
    required this.canAskDeepCloud,
    required this.onAskDeepCloud,
  });

  final AskMhuriTopic topic;
  final bool canAskDeepCloud;
  final VoidCallback onAskDeepCloud;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    void openScreen(Widget screen) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }

    final navButtons = <(IconData, String, VoidCallback)>[
      switch (topic) {
        AskMhuriTopic.budgets => (
            Icons.account_balance_wallet_outlined,
            l.tabBudgets,
            () => openScreen(const BudgetsScreen()),
          ),
        AskMhuriTopic.bills => (
            Icons.event_note_outlined,
            l.upcomingBillsTitle,
            () => openScreen(const CommitmentsScreen()),
          ),
        AskMhuriTopic.savings || AskMhuriTopic.debts => (
            Icons.savings_outlined,
            l.tabSavings,
            () => openScreen(const SavingsScreen()),
          ),
        AskMhuriTopic.shopping => (
            Icons.shopping_cart_outlined,
            l.shopping,
            () => openScreen(const ListsScreen(standalone: true)),
          ),
        AskMhuriTopic.members ||
        AskMhuriTopic.spending ||
        AskMhuriTopic.affordability ||
        AskMhuriTopic.overview =>
          (
            Icons.bar_chart_rounded,
            l.reportsShortcut,
            () => openScreen(const ReportsScreen()),
          ),
      },
      if (topic == AskMhuriTopic.affordability ||
          topic == AskMhuriTopic.spending ||
          topic == AskMhuriTopic.members)
        (
          Icons.account_balance_wallet_outlined,
          l.tabBudgets,
          () => openScreen(const BudgetsScreen()),
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final btn in navButtons)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              side: BorderSide(color: context.hairline),
              textStyle:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
            onPressed: btn.$3,
            icon: Icon(btn.$1, size: 14),
            label: Text(btn.$2),
          ),
        if (canAskDeepCloud)
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
            onPressed: onAskDeepCloud,
            icon: const Icon(Icons.auto_awesome_rounded, size: 14),
            label: Text(l.askMhuriDeepAdvice),
          ),
      ],
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
    final members = facts['member_spending'];
    final shopping = facts['shopping_summary'];
    final purchaseScenario = facts['purchase_scenario'];

    void appendPurchaseScenario() {
      if (purchaseScenario is! Map) return;
      if (purchaseScenario['status'] == 'currency_required') {
        rows.add(('Purchase estimate', 'Please confirm currency'));
        return;
      }
      if (purchaseScenario['status'] == 'insufficient_balance_data') {
        rows.add(('Purchase estimate', 'No recorded balance yet'));
        return;
      }
      final currency = purchaseScenario['currency'];
      rows.add((
        'After upcoming bills & purchase',
        _amount(purchaseScenario['estimated_after_purchase_minor'], currency),
      ));
      rows.add((
        'Purchase check',
        purchaseScenario['fits_recorded_cash_estimate'] == true
            ? 'Within recorded cash'
            : 'Above recorded cash',
      ));
    }

    void appendBudgets([int count = 2]) {
      if (budgets is List) {
        final named = budgets
            .whereType<Map>()
            .where((budget) => budget['complete'] == true)
            .where((budget) => query
                .contains((budget['name']?.toString() ?? '').toLowerCase()))
            .toList();
        final source = named.isNotEmpty
            ? named
            : budgets
                .whereType<Map>()
                .where((budget) => budget['complete'] == true)
                .toList();
        for (final budget in source.take(count)) {
          rows.add((
            '${budget['name'] ?? 'Budget'} left',
            _amount(budget['remaining_minor'], budget['currency']),
          ));
        }
      }
    }

    void appendBills([int count = 3]) {
      if (bills is List) {
        for (final bill in bills.whereType<Map>().take(count)) {
          rows.add((
            '${bill['name'] ?? 'Upcoming bill'} · ${_date(bill['due_date'])}',
            _amount(bill['amount_minor'], bill['currency']),
          ));
        }
      }
    }

    void appendGoals([int count = 3]) {
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

    void appendDebts([int count = 3]) {
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

    void appendMembers([int count = 3]) {
      if (members is List) {
        for (final m in members.whereType<Map>().take(count)) {
          final who = m['is_you'] == true ? '${m['name']} (you)' : '${m['name']}';
          rows.add((
            '$who · ${m['share_percent'] ?? 0}%',
            _amount(m['spent_minor'], m['currency']),
          ));
        }
      }
    }

    void appendShopping() {
      if (shopping is List) {
        for (final s in shopping.whereType<Map>().take(2)) {
          rows.add((
            'Open items (${s['open_items'] ?? 0})',
            _amount(s['estimated_minor'], s['currency']),
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

    final topic = AskMhuriLocalEngine.inferTopic(question);
    switch (topic) {
      case AskMhuriTopic.shopping:
        appendShopping();
        appendBudgets(1);
      case AskMhuriTopic.members:
        appendMembers(3);
        appendTotals('cycle_spending', 'Total shared spend');
      case AskMhuriTopic.savings:
        appendGoals(3);
        appendTotals(
            'available_after_recorded_savings', 'Available after savings');
      case AskMhuriTopic.debts:
        appendDebts(3);
        appendTotals(
            'available_after_recorded_savings', 'Available after savings');
      case AskMhuriTopic.bills:
        appendBills(3);
        appendTotals(
            'available_after_recorded_savings', 'Available after savings');
      case AskMhuriTopic.affordability:
        appendPurchaseScenario();
        appendTotals(
            'available_after_recorded_savings', 'Available after savings');
        appendBills(2);
      case AskMhuriTopic.budgets:
        appendBudgets(3);
        appendTotals('cycle_spending', 'Spent this period');
      case AskMhuriTopic.spending:
        appendTotals('cycle_spending', 'Spent this period');
        appendTotals('previous_cycle_spending', 'Spent previous period');
        appendCategories(2);
      case AskMhuriTopic.overview:
        appendTotals('cycle_spending', 'Spent this period');
        appendTotals('cycle_income', 'Income this period');
        appendCategories(2);
    }

    if (rows.length < 4) {
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
    }

    if (rows.isEmpty) return const SizedBox.shrink();

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
          Text(
            'NUMBERS USED',
            style: TextStyle(
              color: context.inkFaint,
              fontSize: 9,
              letterSpacing: .9,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows.take(4))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: TextStyle(fontSize: 11, color: context.inkSoft),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      row.$2,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            Flexible(
              child: Text(
                'Checking your family’s plan…',
                style: TextStyle(fontSize: 12, color: context.inkSoft),
              ),
            ),
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
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
