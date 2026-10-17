import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/models/history_entry.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/history_screen.dart';
import 'package:carepulse/ui/widgets/streaming_response_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({HistoryStore? store}) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: HistoryScreen(historyStore: store),
    );
  }

  group('HistoryScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Empty state displays appropriate text and icon',
        (tester) async {
      final store = HistoryStore();

      await tester.pumpWidget(buildTestWidget(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Query History'), findsOneWidget);
      expect(find.text('No queries saved yet'), findsOneWidget);
      expect(find.text('History stays on this device.'), findsWidgets);
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
    });

    testWidgets(
        'List displays entries with date, query, source chip and opens detail view',
        (tester) async {
      final store = HistoryStore();
      final now = DateTime(2025, 5, 20, 14, 30);

      await store.saveEntry(
        HistoryEntry(
          id: 'test_1',
          timestamp: now,
          query: 'Bleeding arm injury',
          response:
              '1. IMMEDIATE ACTION: Apply direct pressure.\n2. CRITICAL PRECAUTION: Elevate arm.\n3. MONITOR & STABILIZE: Bandage wound.',
          answerSource: AnswerSource.verifiedProtocol,
        ),
      );

      await tester.pumpWidget(buildTestWidget(store: store));
      await tester.pumpAndSettle();

      // Displays query and source chip
      expect(find.text('Bleeding arm injury'), findsOneWidget);
      expect(find.text('Verified protocol'), findsOneWidget);
      expect(find.text('2025-05-20 14:30'), findsOneWidget);

      // Tap the item to open detail view
      await tester.tap(find.text('Bleeding arm injury'));
      await tester.pumpAndSettle();

      // Detail screen has opened
      expect(find.text('Query Details'), findsOneWidget);
      expect(find.byType(StreamingResponseCard), findsOneWidget);
      expect(find.text('Read Guidance Aloud'), findsOneWidget);
      expect(find.textContaining('Apply direct pressure'), findsOneWidget);
    });

    testWidgets('Delete button removes individual entry from history',
        (tester) async {
      final store = HistoryStore();
      await store.saveEntry(
        HistoryEntry(
          id: 'item_to_delete',
          timestamp: DateTime.now(),
          query: 'Choking adult',
          response: 'Give back blows and abdominal thrusts.',
          answerSource: AnswerSource.verifiedProtocol,
        ),
      );

      await tester.pumpWidget(buildTestWidget(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Choking adult'), findsOneWidget);

      // Tap delete button
      await tester
          .tap(find.byKey(const ValueKey('delete_history_item_to_delete')));
      await tester.pumpAndSettle();

      // Item is removed, shows empty state
      expect(find.text('Choking adult'), findsNothing);
      expect(find.text('No queries saved yet'), findsOneWidget);
    });

    testWidgets('Clear all shows confirmation dialog and clears entries',
        (tester) async {
      final store = HistoryStore();
      await store.saveEntry(
        HistoryEntry(
          id: 'entry_1',
          timestamp: DateTime.now(),
          query: 'Heat exhaustion',
          response: 'Move to shade and drink water.',
          answerSource: AnswerSource.aiGuidedByProtocol,
        ),
      );
      await store.saveEntry(
        HistoryEntry(
          id: 'entry_2',
          timestamp: DateTime.now(),
          query: 'Ankle sprain',
          response: 'Rest, ice, compression, elevation.',
          answerSource: AnswerSource.aiGenerated,
        ),
      );

      await tester.pumpWidget(buildTestWidget(store: store));
      await tester.pumpAndSettle();

      expect(find.text('Heat exhaustion'), findsOneWidget);
      expect(find.text('Ankle sprain'), findsOneWidget);

      // Tap clear all button in AppBar
      await tester.tap(find.byKey(const ValueKey('history_clear_all_button')));
      await tester.pumpAndSettle();

      // Confirmation dialog is visible
      expect(find.text('Clear All History?'), findsOneWidget);
      expect(
        find.text(
            'Are you sure you want to delete all saved emergency queries? This action cannot be undone.'),
        findsOneWidget,
      );

      // Tap Clear All in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Clear All'));
      await tester.pumpAndSettle();

      // Entries are gone
      expect(find.text('Heat exhaustion'), findsNothing);
      expect(find.text('Ankle sprain'), findsNothing);
      expect(find.text('No queries saved yet'), findsOneWidget);
    });
  });
}
