import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/notifications/reminders.dart';
import 'package:mhuri_money/core/observability/reporter.dart';
import 'package:mhuri_money/core/planning/weekly_summary.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/features/onboarding/family_setup_screen.dart';
import 'package:mhuri_money/features/quickadd/quick_add_sheet.dart';
import 'package:mhuri_money/features/reports/weekly_summary_sheet.dart';
import 'package:mhuri_money/features/shell/adult_shell.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

import 'seed.dart';

Widget _wrapWithState(
  AppState state,
  Widget child, {
  double textScale = 1.0,
}) {
  return AppScope(
    notifier: state,
    child: MaterialApp(
      theme: buildAppTheme(),
      localizationsDelegates: mhuriLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: inner!,
      ),
      home: child,
    ),
  );
}

void main() {
  group('Phase 0 — Privacy-safe analytics & redaction', () {
    test('redactFields strips amounts, notes, receipts, family names, and tokens', () {
      final raw = <String, Object?>{
        'duration_ms': 420,
        'entry_type': 'expense',
        'role': 'head',
        'locale': 'en',
        'amount': 125.50,
        'minor': 12550,
        'note': 'Clinic visit',
        'receipt_uri': 'file:///tmp/receipt.jpg',
        'family_name': 'Chikangaiso Family',
        'message': 'Secret note',
        'access_token': 'jwt_secret',
        'user_email': 'user@example.com',
      };
      final safe = redactFields(raw);
      expect(safe['duration_ms'], 420);
      expect(safe['entry_type'], 'expense');
      expect(safe['role'], 'head');
      expect(safe['locale'], 'en');
      expect(safe.containsKey('amount'), isFalse);
      expect(safe.containsKey('minor'), isFalse);
      expect(safe.containsKey('note'), isFalse);
      expect(safe.containsKey('receipt_uri'), isFalse);
      expect(safe.containsKey('family_name'), isFalse);
      expect(safe.containsKey('message'), isFalse);
      expect(safe.containsKey('access_token'), isFalse);
      expect(safe.containsKey('user_email'), isFalse);
    });

    test('InMemoryReporter records redacted product events', () {
      final mem = InMemoryReporter();
      final prev = activeReporter;
      activeReporter = mem;
      addTearDown(() => activeReporter = prev);

      mhuriEvent(MhuriAnalyticsEvents.quickAddCompleted, {
        'duration_ms': 1800,
        'entry_type': 'expense',
        'amount_minor': 5000,
        'note': 'Groceries at OK',
      });

      expect(mem.events, hasLength(1));
      expect(mem.events.single.name, MhuriAnalyticsEvents.quickAddCompleted);
      expect(mem.events.single.fields['duration_ms'], 1800);
      expect(mem.events.single.fields['entry_type'], 'expense');
      expect(mem.events.single.fields.containsKey('amount_minor'), isFalse);
      expect(mem.events.single.fields.containsKey('note'), isFalse);
    });
  });

  group('Phase 1 — Effortless expense entry & real reversible Undo', () {
    testWidgets('Tapping + in AdultShell opens Expense entry directly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      seedMemory(state);
      await tester.pumpWidget(_wrapWithState(state, const AdultShell()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('What are you adding?'), findsOneWidget);
      expect(find.text('Amount spent'), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_add_payment_method_chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick_add_other_action')), findsOneWidget);
    });

    testWidgets(
      'Saving an expense remembers defaults, shows Undo, and Undo tombstones the transaction',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final state = AppState();
        state.members.add(state.user);
        state.addEnvelope(
          name: 'Groceries',
          limit: const Money(20000, Currency.usd),
          emoji: 'cart',
        );
        state.addEnvelope(
          name: 'Transport',
          limit: const Money(10000, Currency.usd),
          emoji: 'car',
        );
        final groceriesId = state.envelopes.first.id;
        final transportId = state.envelopes[1].id;

        await tester.pumpWidget(
          _wrapWithState(
            state,
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showQuickAdd(context),
                    child: const Text('Open Quick Add'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Quick Add'));
        await tester.pumpAndSettle();

        // First budget (Groceries) is auto-selected, No budget chip is visible, and Transport is a 1-tap chip.
        expect(find.byKey(const ValueKey('quick_add_no_budget_chip')), findsOneWidget);
        expect(find.byKey(ValueKey('quick_add_budget_chip_$transportId')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('quick_add_budget_chip_$transportId')));
        await tester.pumpAndSettle();
        // Now Groceries appears as a 1-tap chip; tap it to select Groceries.
        await tester.tap(find.byKey(ValueKey('quick_add_budget_chip_$groceriesId')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, '25');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add expense'));
        await tester.pumpAndSettle();

        expect(state.familyTransactions, hasLength(1));
        expect(state.lastUsedExpenseEnvelopeId, groceriesId);
        expect(state.lastUsedExpenseCurrency, Currency.usd);
        expect(find.text('Undo'), findsOneWidget);

        // Tap Undo on the snackbar -> real reversible tombstone via deleteTx
        await tester.tap(find.text('Undo'));
        await tester.pumpAndSettle();

        expect(state.familyTransactions, isEmpty);
        expect(state.txs, isEmpty);

        // Switching family spaces clears space-scoped entry defaults
        state.clearRecentEntryDefaults();
        expect(state.lastUsedExpenseEnvelopeId, isNull);
        expect(state.lastUsedExpenseCurrency, isNull);
        expect(state.lastUsedPaymentMethod, Method.cash);
      },
    );
  });

  group('Phase 2 & Phase 5 — Calm Home hierarchy & Weekly Mhuri Summary', () {
    test('WeeklySummaryPlanner reconciles transactions, goals, and debts and excludes private accounts', () {
      final now = DateTime(2026, 11, 7, 12);
      final state = AppState(clock: () => now);
      state.members.add(state.user);
      state.addEnvelope(
        name: 'Groceries',
        limit: const Money(10000, Currency.usd),
        emoji: 'cart',
      );
      final envId = state.envelopes.single.id;

      // Private account transaction that must be excluded from household weekly summary
      const privateAcc = Account(
        id: 'priv_1',
        name: 'Personal wallet',
        emoji: 'cash',
        balance: Money(50000, Currency.usd),
        isPrivate: true,
        ownerMemberId: 'me',
      );
      state.accounts.add(privateAcc);
      state.txs.addAll([
        Tx(
          id: 'tx_inc',
          type: TxType.income,
          amount: const Money(50000, Currency.usd),
          memberId: state.user.id,
          method: Method.bankTransfer,
          note: 'Salary',
          when: now.subtract(const Duration(days: 2)),
        ),
        Tx(
          id: 'tx_exp',
          type: TxType.expense,
          amount: const Money(12000, Currency.usd),
          memberId: state.user.id,
          envelopeId: envId,
          method: Method.cash,
          note: 'Supermarket',
          when: now.subtract(const Duration(days: 1)),
        ),
        Tx(
          id: 'tx_priv',
          type: TxType.expense,
          amount: const Money(99900, Currency.usd),
          memberId: state.user.id,
          accountId: privateAcc.id,
          method: Method.cash,
          note: 'Private spend',
          when: now.subtract(const Duration(days: 1)),
        ),
      ]);

      final summary = WeeklySummaryPlanner.compute(state, nowOverride: now);
      expect(summary.hasActivity, isTrue);
      expect(summary.incomeCount, 1);
      expect(summary.expenseCount, 1);
      expect(summary.totalIncome.minor, 50000);
      expect(summary.totalSpent.minor, 12000);
      expect(summary.budgetHighlight?.envelope.name, 'Groceries');
      expect(summary.budgetHighlight?.isOverBudget, isTrue);
      // Supportive, non-shaming copy when over budget
      expect(
        summary.supportiveNextStep,
        contains('above its plan — review together or move money from another budget.'),
      );

      final plainShare = summary.formatShareText(
        familyName: 'Chikangaiso',
        maskAmounts: false,
      );
      expect(plainShare, contains('US\$ 120.00'));

      final maskedShare = summary.formatShareText(
        familyName: 'Chikangaiso',
        maskAmounts: true,
      );
      expect(maskedShare, isNot(contains('US\$ 120.00')));
      expect(maskedShare, contains('••••'));

      // ReminderPlanner schedules weekly_mhuri_summary on Sunday 18:00 when active
      final reminders = ReminderPlanner.plan(
        now: now,
        config: const NotifyConfig(
          enabled: true,
          allowed: {ReminderCategory.family},
        ),
        recurring: const [],
        envelopes: const [],
        chores: const [],
        requests: const [],
        circle: SavingsCircle(
          name: 'Circle',
          contribution: const Money(1000, Currency.usd),
          totalRounds: 4,
          currentRound: 1,
          order: const ['me'],
        ),
        memberNames: const {'me': 'Me'},
        monthStartDay: 1,
        weeklySummary: summary,
      );
      expect(reminders.any((r) => r.key == 'weekly_mhuri_summary'), isTrue);
    });

    testWidgets('Home caps household budget preview to 3 urgent cards and shows Weekly Summary', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      state.members.add(state.user);
      for (var i = 1; i <= 5; i++) {
        state.addEnvelope(
          name: 'Budget $i',
          limit: const Money(10000, Currency.usd),
          emoji: 'cart',
        );
      }
      // Make Budget 5 over-budget so urgency sorting places it in the top 3
      final budget5 = state.envelopes.firstWhere((e) => e.name == 'Budget 5');
      state.addTx(
        type: TxType.expense,
        amount: const Money(15000, Currency.usd),
        memberId: state.user.id,
        envelopeId: budget5.id,
        method: Method.cash,
        note: 'Urgent spend',
      );

      await tester.pumpWidget(_wrapWithState(state, const Scaffold(body: HomeScreen())));
      await tester.pumpAndSettle();

      // Urgent Budget 5 is surfaced in top 3, while 4th/5th unspent budgets are hidden behind See all
      expect(find.text('Budget 5'), findsOneWidget);
      expect(find.text('Budget 4'), findsNothing);
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('weekly_summary_card')), findsOneWidget);
    });

    testWidgets('WeeklySummarySheet requires explicit privacy confirmation before sharing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      seedMemory(state);
      await tester.pumpWidget(
        _wrapWithState(
          state,
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showWeeklySummarySheet(context),
                  child: const Text('Open Weekly Summary'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Weekly Summary'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Mhuri summary'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('weekly_summary_share_button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('weekly_summary_share_button')));
      await tester.pumpAndSettle();

      expect(find.text('Share weekly summary?'), findsOneWidget);
      expect(find.text('Hide exact currency amounts'), findsOneWidget);
    });
  });

  group('Phase 3 & Phase 4 — Quick-start onboarding & text scaling resilience', () {
    testWidgets('Quick start with defaults completes family setup in 1 step with starter budgets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      await tester.pumpWidget(_wrapWithState(state, FamilySetupScreen(state: state)));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Tendai');
      await tester.enterText(find.byType(TextField).at(1), 'Moyo Household');
      await tester.tap(find.byKey(const ValueKey('onboarding_primary_currency_zwg')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('onboarding_quick_start_button')));
      await tester.pumpAndSettle();

      expect(state.onboardingComplete, isTrue);
      expect(state.primaryCurrency, Currency.zwg);
      expect(
        state.envelopes.map((e) => e.name),
        containsAll(['Groceries', 'Rent', 'Transport', 'Electricity']),
      );
    });

    testWidgets('Home and WeeklySummaryPreviewCard render cleanly at 200% text scaling', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final state = AppState();
      seedMemory(state);
      await tester.pumpWidget(
        _wrapWithState(
          state,
          const Scaffold(body: HomeScreen()),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
