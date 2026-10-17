import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_clarifier.dart';
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

class NotReadyModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => false;

  @override
  Future<bool> hasUnverifiedModel() async => false;

  @override
  Future<int> getPartialBytes() async => 0;

  @override
  Future<bool> hasPartialDownload() async => false;
}

class FakeClarifierEngineService extends TriageEngineService {
  String? lastPassedQuery;
  String? lastPassedContext;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    dynamic profile,
    String? context,
  }) async* {
    lastPassedQuery = query;
    lastPassedContext = context;
    yield '1. IMMEDIATE ACTION: Simulated triage response.';
  }
}

void main() {
  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;
  late TriageClarifier clarifier;

  setUpAll(() async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = await file.readAsString();
    repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);
    retriever = ProtocolRetriever(repo);
    redFlagEngine = RedFlagEngine();
    clarifier = TriageClarifier(
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createWidget({
    required TriageController triageController,
    required AppSettingsController settingsController,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
        ChangeNotifierProvider<AppSettingsController>.value(
          value: settingsController,
        ),
        ChangeNotifierProvider<TriageController>.value(
          value: triageController,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        home: const Scaffold(body: EmergencyHomeScreen()),
      ),
    );
  }

  testWidgets(
      'Vague query displays glass question card with Yes, No, Not sure, and Skip buttons with >=48px height',
      (WidgetTester tester) async {
    final settings = AppSettingsController();
    final triageController = TriageController(
      downloadService: ReadyModelDownloadService(),
      engineService: FakeClarifierEngineService(),
      protocolRepository: repo,
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
      triageClarifier: clarifier,
      historyStore: HistoryStore(),
      settingsController: settings,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(createWidget(
      triageController: triageController,
      settingsController: settings,
    ));
    await tester.pump();

    // Enter vague query
    final textField = find.byType(TextField);
    await tester.enterText(textField, 'he is not well');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Glass question card should be visible
    expect(find.byKey(const Key('triage_clarification_card')), findsOneWidget);
    expect(find.text('Is the person awake and responding?'), findsOneWidget);

    // Verify Yes, No, Not sure, and Skip
    final yesFinder = find.widgetWithText(ElevatedButton, 'Yes');
    final noFinder = find.widgetWithText(ElevatedButton, 'No');
    final notSureFinder = find.widgetWithText(ElevatedButton, 'Not sure');
    final skipFinder = find.text('Skip');

    expect(yesFinder, findsOneWidget);
    expect(noFinder, findsOneWidget);
    expect(notSureFinder, findsOneWidget);
    expect(skipFinder, findsOneWidget);

    // Check tap target size >= 48
    final yesSize = tester.getSize(yesFinder);
    expect(yesSize.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets(
      'Tapping No on awake question shows unresponsive protocol + Call banner + emergency note',
      (WidgetTester tester) async {
    final settings = AppSettingsController();
    final triageController = TriageController(
      downloadService: ReadyModelDownloadService(),
      engineService: FakeClarifierEngineService(),
      protocolRepository: repo,
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
      triageClarifier: clarifier,
      historyStore: HistoryStore(),
      settingsController: settings,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(createWidget(
      triageController: triageController,
      settingsController: settings,
    ));
    await tester.pump();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'he is not well');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Tap No
    await tester.tap(find.widgetWithText(ElevatedButton, 'No'));
    await tester.pumpAndSettle();

    // Question card removed
    expect(find.byKey(const Key('triage_clarification_card')), findsNothing);

    // Shows unresponsive protocol with verified protocol source & call banner
    expect(find.text('Verified protocol'), findsOneWidget);
    expect(find.textContaining('112'), findsWidgets);
    expect(
        find.text(
            'Treating this as an emergency because the answer was No or Not sure.'),
        findsOneWidget);
  });

  testWidgets(
      'Tapping Yes on awake advances to breathing question, then Skip runs normal flow',
      (WidgetTester tester) async {
    final engine = FakeClarifierEngineService();
    final settings = AppSettingsController();
    final triageController = TriageController(
      downloadService: ReadyModelDownloadService(),
      engineService: engine,
      protocolRepository: repo,
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
      triageClarifier: clarifier,
      historyStore: HistoryStore(),
      settingsController: settings,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(createWidget(
      triageController: triageController,
      settingsController: settings,
    ));
    await tester.pump();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'he is not well');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Tap Yes on awake
    await tester.tap(find.widgetWithText(ElevatedButton, 'Yes'));
    await tester.pumpAndSettle();

    // Question 2: Breathing
    expect(find.text('Is the person breathing normally?'), findsOneWidget);

    // Tap Skip
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Question card gone, normal engine executed
    expect(find.byKey(const Key('triage_clarification_card')), findsNothing);
    expect(engine.lastPassedQuery, 'he is not well');
  });

  testWidgets(
      'Yes + Yes when model is not ready shows friendly message pointing to Guides',
      (WidgetTester tester) async {
    final settings = AppSettingsController();
    final triageController = TriageController(
      downloadService: NotReadyModelDownloadService(),
      engineService: FakeClarifierEngineService(),
      protocolRepository: repo,
      protocolRetriever: retriever,
      redFlagEngine: redFlagEngine,
      triageClarifier: clarifier,
      historyStore: HistoryStore(),
      settingsController: settings,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(createWidget(
      triageController: triageController,
      settingsController: settings,
    ));
    await tester.pump();

    final textField = find.byType(TextField);
    await tester.enterText(textField, 'he is not well');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    // Awake -> Yes
    await tester.tap(find.widgetWithText(ElevatedButton, 'Yes'));
    await tester.pumpAndSettle();

    // Breathing -> Yes
    await tester.tap(find.widgetWithText(ElevatedButton, 'Yes'));
    await tester.pumpAndSettle();

    // Friendly message appears pointing to Guides
    expect(find.textContaining('The offline AI model is not downloaded yet'),
        findsOneWidget);
    expect(find.textContaining('explore the Guides tab'), findsOneWidget);
  });
}
