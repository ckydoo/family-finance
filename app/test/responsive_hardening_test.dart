import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/l10n/localization_delegates.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/features/budgets/budgets_screen.dart';
import 'package:mhuri_money/features/home/home_screen.dart';
import 'package:mhuri_money/features/lists/lists_screen.dart';
import 'package:mhuri_money/features/quickadd/quick_add_sheet.dart';
import 'package:mhuri_money/features/savings/savings_screen.dart';
import 'package:mhuri_money/features/settings/settings_screen.dart';
import 'package:mhuri_money/features/shell/adult_shell.dart';
import 'package:mhuri_money/l10n/generated/app_localizations.dart';

void main() {
  Widget harness(AppState state, Widget child) => AppScope(
        notifier: state,
        child: MaterialApp(
          localizationsDelegates: mhuriLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
      );

  void viewport(WidgetTester tester, Size size, {double textScale = 1}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
  }

  AppState populatedState() {
    final state = AppState();
    for (var i = 0; i < 12; i++) {
      state.addEnvelope(
        name: 'Family budget category number ${i + 1}',
        limit: Money.fromMajor(100 + i, Currency.usd),
      );
      state.goals.add(Goal(
        id: 'responsive-goal-$i',
        name: 'Family savings goal number ${i + 1}',
        emoji: 'goal',
        target: Money.fromMajor(200 + i, Currency.usd),
      ));
      state.addItem(
        'A realistically long shopping item name number ${i + 1}',
        1,
        Money.fromMajor(5 + i, Currency.usd),
      );
    }
    state.addTx(
      type: TxType.income,
      amount: Money.fromMajor(1000, Currency.usd),
      memberId: state.user.id,
      method: Method.bankTransfer,
      note: 'Income',
    );
    return state;
  }

  for (final size in const [
    Size(360, 640),
    Size(360, 720),
    Size(360, 800),
    Size(375, 812),
    Size(390, 844),
    Size(393, 873),
    Size(412, 915),
    Size(430, 932),
    Size(768, 1024),
  ]) {
    testWidgets(
        'main scrolling screens remain usable at ${size.width}x${size.height}',
        (tester) async {
      viewport(tester, size);
      final state = populatedState();
      for (final screen in const <Widget>[
        HomeScreen(),
        BudgetsScreen(),
        SavingsScreen(),
        ListsScreen(),
      ]) {
        await tester.pumpWidget(harness(state, screen));
        await tester.pumpAndSettle();
        expect(find.byType(Scrollable), findsWidgets);
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('shopping final content and fixed action are both reachable',
      (tester) async {
    viewport(tester, const Size(360, 640), textScale: 1.5);
    final state = populatedState();
    await tester.pumpWidget(harness(state, const ListsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('No shopping to record'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Estimated total'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Estimated total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Quick Add keeps submit action reachable above a keyboard inset',
      (tester) async {
    viewport(tester, const Size(360, 640), textScale: 1.5);
    final state = populatedState();
    await tester.pumpWidget(
      harness(
        state,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showQuickAdd(context),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();

    expect(find.text('Add expense'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Add expense')).dy,
        lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings remains scrollable at 200 percent text',
      (tester) async {
    viewport(tester, const Size(360, 640), textScale: 2);
    final state = populatedState();
    await tester.pumpWidget(harness(state, const SettingsScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('How Mhuri Works (User Guide)'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('How Mhuri Works (User Guide)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every bottom navigation destination remains tappable',
      (tester) async {
    viewport(tester, const Size(360, 640), textScale: 1.5);
    final state = populatedState();
    await tester.pumpWidget(harness(state, const AdultShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Home overflowed');

    for (final label in const ['Budgets', 'Savings', 'Shopping', 'Home']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$label overflowed');
    }
  });
}
