import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/money/money.dart';
import 'package:mhuri_money/core/widgets/motion.dart';

void main() {
  testWidgets('unchanged money does not restart from zero on parent rebuild',
      (tester) async {
    final rebuild = ValueNotifier<int>(0);
    addTearDown(rebuild.dispose);

    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: rebuild,
        builder: (_, __, ___) => const CountUpText(
          amount: Money(1000000, Currency.usd),
          style: TextStyle(),
        ),
      ),
    ));

    expect(find.text(r'US$ 10,000.00'), findsOneWidget);
    rebuild.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(r'US$ 10,000.00'), findsOneWidget);
    expect(find.text(r'US$ 0.00'), findsNothing);
  });
}
