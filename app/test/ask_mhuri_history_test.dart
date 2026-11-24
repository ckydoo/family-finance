import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/db/app_database.dart';
import 'package:mhuri_money/features/ai/ask_mhuri_history.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database raw;
  late AskMhuriHistoryStore history;

  setUp(() async {
    raw = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => AppDatabase.createSchema(db),
      ),
    );
    history = AskMhuriHistoryStore(raw);
  });

  tearDown(() async => raw.close());

  test('saves exchanges and reloads them in conversation order', () async {
    const facts = <String, Object?>{
      'currency': 'USD',
      'balances': [
        {'name': 'Groceries', 'amount': 42},
      ],
    };
    final first = await history.saveExchange(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
      question: '  How much   can we save? ',
      answer: 'You can save 42 USD.',
      facts: facts,
      createdAtMs: 1000,
    );
    final updated = await history.saveExchange(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
      question: 'What about next month?',
      answer: 'Review next month’s bills first.',
      facts: const {},
      createdAtMs: 2000,
    );

    expect(first.title, 'How much can we save?');
    expect(updated.title, first.title);
    expect(updated.createdAtMs, 1000);
    expect(updated.updatedAtMs, 2000);

    final messages = await history.loadMessages(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
    );
    expect(messages.map((message) => message.content), [
      '  How much   can we save? ',
      'You can save 42 USD.',
      'What about next month?',
      'Review next month’s bills first.',
    ]);
    expect(messages[1].facts, facts);

    final conversations = await history.listConversations(
      userId: 'user-1',
      familyId: 'family-1',
    );
    expect(conversations, hasLength(1));
    expect(conversations.single.id, 'chat-1');
  });

  test('history is scoped to both user and family and supports rename/delete',
      () async {
    await history.saveExchange(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
      question: 'Bills?',
      answer: 'Rent is due.',
      facts: const {},
      createdAtMs: 1000,
    );

    expect(
      await history.listConversations(userId: 'user-2', familyId: 'family-1'),
      isEmpty,
    );
    expect(
      await history.listConversations(userId: 'user-1', familyId: 'family-2'),
      isEmpty,
    );
    expect(
      await history.loadMessages(
        conversationId: 'chat-1',
        userId: 'user-2',
        familyId: 'family-1',
      ),
      isEmpty,
    );

    await history.renameConversation(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
      title: ' Monthly bills ',
    );
    expect(
      (await history.listConversations(
        userId: 'user-1',
        familyId: 'family-1',
      ))
          .single
          .title,
      'Monthly bills',
    );

    await history.deleteConversation(
      conversationId: 'chat-1',
      userId: 'user-1',
      familyId: 'family-1',
    );
    expect(
      await history.listConversations(userId: 'user-1', familyId: 'family-1'),
      isEmpty,
    );
    expect(
      await history.loadMessages(
        conversationId: 'chat-1',
        userId: 'user-1',
        familyId: 'family-1',
      ),
      isEmpty,
    );
  });
}
