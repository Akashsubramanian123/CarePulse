import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/state/cpr_controller.dart';
import 'package:carepulse/ui/screens/cpr_screen.dart';

void main() {
  testWidgets('CprScreen renders safety checklist and starts/pauses CPR',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final cprController = CprController();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: CprScreen(controller: cprController),
      ),
    );
    await tester.pumpAndSettle();

    // Verify safety checklist
    expect(find.text('Safety & Assessment Checklist'), findsOneWidget);
    expect(find.text('Start CPR'), findsOneWidget);

    // Tap Start CPR
    await tester.ensureVisible(find.text('Start CPR'));
    await tester.tap(find.text('Start CPR'));
    await tester.pump();

    expect(cprController.isRunning, isTrue);
    expect(find.text('Pause CPR'), findsOneWidget);

    // Tap Pause CPR
    await tester.tap(find.text('Pause CPR'));
    await tester.pump();

    expect(cprController.isRunning, isFalse);
    expect(find.text('Start CPR'), findsOneWidget);
  });
}
