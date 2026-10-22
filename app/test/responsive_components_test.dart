import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mhuri_money/core/theme/app_theme.dart';
import 'package:mhuri_money/core/widgets/ui.dart';

void main() {
  testWidgets('shared components fit narrow screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(280, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.8)),
        child: child!,
      ),
      home: const Scaffold(
        body: SingleChildScrollView(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(
                title: 'Recent household activity and updates',
                actionLabel: 'See everything',
                onAction: _noop,
              ),
              SettingsRow(
                'Last successful family synchronization',
                'Yesterday at 11:45 PM',
              ),
              SizedBox(height: 12),
              StatusBanner(
                title: 'Needs attention',
                message:
                    'Several family budgets have reached their monthly limits.',
                actionLabel: 'Review budgets',
                onAction: _noop,
              ),
              SizedBox(height: 12),
              PrimaryButton(
                label: 'Save changes for the whole family',
                icon: Icons.save_outlined,
                onPressed: _noop,
              ),
              SizedBox(height: 8),
              SecondaryButton(
                label: 'Choose a different family member',
                icon: Icons.people_outline,
                onPressed: _noop,
              ),
            ],
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Save changes for the whole family'), findsOneWidget);
  });
}

void _noop() {}
