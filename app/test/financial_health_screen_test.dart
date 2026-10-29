import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/models/models.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/state/app_state.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/features/reports/financial_health_screen.dart';

void main() {
  testWidgets('Financial Health never exposes internal source IDs',
      (tester) async {
    final now = DateTime(2026, 10, 27, 12);
    final state = AppState(clock: () => now);
    state.txs.add(Tx(
      id: 'internal-transaction-uuid-123',
      memberId: state.user.id,
      type: TxType.expense,
      amount: const Money(2500, Currency.usd),
      method: Method.cash,
      note: 'Family groceries',
      when: now,
    ));

    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const FinancialHealthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('internal-transaction-uuid-123'), findsNothing);
    await tester.tap(find.byType(ExpansionTile).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('internal-transaction-uuid-123'), findsNothing);
    expect(find.textContaining('Family groceries'), findsWidgets);
  });
}
