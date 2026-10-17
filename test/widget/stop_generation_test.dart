import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/profile_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/theme_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/emergency_home_screen.dart';

class ReadyModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';
}

class ControllableEngineService extends TriageEngineService {
  final StreamController<String> _controller =
      StreamController<String>.broadcast();
  bool stopCalled = false;
  final Completer<void> streamStarted = Completer<void>();

  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  Future<void> stopGeneration() async {
    stopCalled = true;
    await super.stopGeneration();
  }

  void emitToken(String token) {
    _controller.add(token);
  }

  void finish() {
    _controller.close();
  }

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? context,
  }) {
    if (!streamStarted.isCompleted) streamStarted.complete();
    return _controller.stream;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'While generating, send button becomes Stop button and tapping it stops and displays Stopped note',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final engineService = ControllableEngineService();
    final triageController = TriageController(
      downloadService: ReadyModelDownloadService(),
      engineService: engineService,
      protocolRepository: repo,
    );
    await triageController.checkModelStatus();

    final settings = AppSettingsController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsController>.value(value: settings),
          ChangeNotifierProvider<ThemeController>.value(
              value: ThemeController()),
          ChangeNotifierProvider<TriageController>.value(
              value: triageController),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EmergencyHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify initial Send button exists with semantic label Send
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Send'), findsOneWidget);

    // Enter query and submit
    await tester.enterText(
        find.byType(TextField), 'boiling water spilled on my arm');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await engineService.streamStarted.future;
    await tester.pump();

    // Emit token so there's partial text
    engineService.emitToken('1. IMMEDIATE ACTION: Cool the burn.');
    await tester.pump();

    // While generating, send button should become Stop button (square icon, semantic label Stop)
    expect(triageController.isGenerating, isTrue);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    expect(find.bySemanticsLabel('Stop'), findsOneWidget);

    // Tap the Stop button
    await tester.tap(find.byIcon(Icons.stop_rounded));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();

    // Generation is stopped
    expect(triageController.isGenerating, isFalse);
    expect(triageController.wasStopped, isTrue);
    expect(engineService.stopCalled, isTrue);

    // Button reverts back to Send
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    // Partial text is preserved
    expect(find.textContaining('Cool the burn'), findsOneWidget);

    // Response card shows quiet "Stopped" note
    expect(find.text('Stopped'), findsOneWidget);
    expect(
        find.byIcon(Icons.stop_rounded), findsOneWidget); // inside stopped chip
  });
}
