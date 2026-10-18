import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/guides_screen.dart';

class FakeModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'GuidesScreen displays searchable list and opens protocol details',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final controller = TriageController(
      downloadService: FakeModelDownloadService(),
      protocolRepository: repo,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<TriageController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GuidesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial list shows items (AppBar was removed in favor of shell top bar)
    expect(find.text('Search guides, symptoms, injuries...'), findsOneWidget);
    expect(find.text('Severe Bleeding'), findsOneWidget);

    // Search filter for snake
    await tester.enterText(find.byType(TextField), 'snake');
    await tester.pumpAndSettle();

    expect(find.text('Snakebite'), findsOneWidget);
    expect(find.text('Severe Bleeding'), findsNothing);

    // Tap to open detail screen
    await tester.tap(find.text('Snakebite'));
    await tester.pumpAndSettle();

    // Verify 3 steps rendered
    expect(find.text('IMMEDIATE ACTION'), findsOneWidget);
    expect(find.text('CRITICAL PRECAUTION'), findsOneWidget);
    expect(find.text('MONITOR & STABILIZE'), findsOneWidget);
    expect(find.text('DO NOT'), findsOneWidget);
  });
}
