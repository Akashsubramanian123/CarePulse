import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/ui/widgets/streaming_response_card.dart';

void main() {
  testWidgets('StreamingResponseCard displays source chip and parsed steps',
      (WidgetTester tester) async {
    const stepsText = '1. IMMEDIATE ACTION: Apply direct pressure to wound.\n'
        '2. CRITICAL PRECAUTION: Do not remove soaked cloths.\n'
        '3. MONITOR & STABILIZE: Keep person calm and check pulse.';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StreamingResponseCard(
              query: 'Spurting blood from arm',
              responseText: stepsText,
              isGenerating: false,
              sourceLabel: 'Verified protocol',
              onClear: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify source chip
    expect(find.text('Verified protocol'), findsOneWidget);

    // Verify 3 steps
    expect(find.text('IMMEDIATE ACTION'), findsOneWidget);
    expect(find.text('CRITICAL PRECAUTION'), findsOneWidget);
    expect(find.text('MONITOR & STABILIZE'), findsOneWidget);

    // Verify step contents
    expect(find.text('Apply direct pressure to wound.'), findsOneWidget);
    expect(find.text('Do not remove soaked cloths.'), findsOneWidget);
    expect(find.text('Keep person calm and check pulse.'), findsOneWidget);
  });
}
