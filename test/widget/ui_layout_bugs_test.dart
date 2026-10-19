import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/models/medical_id.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/medical_id_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/protocol_retriever.dart';
import 'package:carepulse/services/red_flag_engine.dart';
import 'package:carepulse/services/triage_clarifier.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/cpr_controller.dart';
import 'package:carepulse/state/theme_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/benchmark_screen.dart';
import 'package:carepulse/ui/screens/cpr_screen.dart';
import 'package:carepulse/ui/screens/emergency_home_screen.dart';
import 'package:carepulse/ui/screens/guides_screen.dart';
import 'package:carepulse/ui/screens/history_screen.dart';
import 'package:carepulse/ui/screens/main_shell.dart';
import 'package:carepulse/ui/screens/medical_id_screen.dart';
import 'package:carepulse/ui/screens/model_setup_screen.dart';
import 'package:carepulse/ui/screens/profile_screen.dart';
import 'package:carepulse/ui/screens/protocol_detail_screen.dart';
import 'package:carepulse/ui/screens/sos_screen.dart';
import 'package:carepulse/ui/widgets/glass_card.dart';
import 'package:carepulse/ui/widgets/settings_sheet.dart';

class FakeReadyDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;
  @override
  Future<String> getModelPath() async => '/fake/model.gguf';
}

class FakeNotReadyDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => false;
  @override
  Future<bool> hasUnverifiedModel() async => false;
  @override
  Future<int> getPartialBytes() async => 0;
  @override
  Future<bool> hasPartialDownload() async => false;
}

class FakeEngineService extends TriageEngineService {
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
    yield '1. IMMEDIATE ACTION: Keep patient calm and apply direct pressure.';
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
    SharedPreferences.setMockInitialValues({'onboarding_v1_seen': true});
  });

  void setIPhone16(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3.0;
  }

  Widget wrapWithTheme({
    required Widget child,
    required ThemeMode mode,
    required double textScale,
    TriageController? triageController,
    AppSettingsController? settingsController,
  }) {
    final tCtrl = triageController ??
        TriageController(
          downloadService: FakeReadyDownloadService(),
          engineService: FakeEngineService(),
          protocolRepository: repo,
          protocolRetriever: retriever,
          redFlagEngine: redFlagEngine,
          triageClarifier: clarifier,
          historyStore: HistoryStore(),
        );

    final sCtrl = settingsController ?? AppSettingsController();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController()),
        ChangeNotifierProvider<AppSettingsController>.value(value: sCtrl),
        ChangeNotifierProvider<TriageController>.value(value: tCtrl),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        builder: (context, materialChild) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: materialChild ?? const SizedBox.shrink(),
          );
        },
        home: child,
      ),
    );
  }

  group(
      'Section 6 - iPhone 16 Screen Layout & No Overflow (Light & Dark, Scales 1.0, 1.3, 1.6)',
      () {
    final textScales = [1.0, 1.3, 1.6];
    final themeModes = [ThemeMode.light, ThemeMode.dark];

    for (final scale in textScales) {
      for (final mode in themeModes) {
        final modeName = mode == ThemeMode.light ? 'Light' : 'Dark';

        testWidgets('Assistant (idle) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const EmergencyHomeScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Assistant (with response) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final ctrl = TriageController(
            downloadService: FakeReadyDownloadService(),
            engineService: FakeEngineService(),
            protocolRepository: repo,
            protocolRetriever: retriever,
            redFlagEngine: redFlagEngine,
            triageClarifier: clarifier,
            historyStore: HistoryStore(),
          );
          await ctrl.checkModelStatus();

          await tester.pumpWidget(wrapWithTheme(
            child: const EmergencyHomeScreen(),
            mode: mode,
            textScale: scale,
            triageController: ctrl,
          ));
          await tester.pump();

          final textField = find.byType(TextField);
          await tester.enterText(textField, 'chest pain');
          await tester.tap(find.byIcon(Icons.send_rounded));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('Assistant (with clarifying card) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final ctrl = TriageController(
            downloadService: FakeReadyDownloadService(),
            engineService: FakeEngineService(),
            protocolRepository: repo,
            protocolRetriever: retriever,
            redFlagEngine: redFlagEngine,
            triageClarifier: clarifier,
            historyStore: HistoryStore(),
          );
          await ctrl.checkModelStatus();

          await tester.pumpWidget(wrapWithTheme(
            child: const EmergencyHomeScreen(),
            mode: mode,
            textScale: scale,
            triageController: ctrl,
          ));
          await tester.pump();

          final textField = find.byType(TextField);
          await tester.enterText(textField, 'he is not well');
          await tester.tap(find.byIcon(Icons.send_rounded));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('Guides Screen - $modeName scale $scale', (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const GuidesScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('Protocol Detail Screen - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final protocol = repo.allProtocols.first;
          await tester.pumpWidget(wrapWithTheme(
            child: ProtocolDetailScreen(protocol: protocol),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
        });

        testWidgets('CPR Screen (idle and running) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final cprController = CprController();
          await tester.pumpWidget(wrapWithTheme(
            child: CprScreen(controller: cprController),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Start CPR

          await tester.tap(find.text('Start CPR'));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(cprController.isRunning, isTrue);

          // Stop CPR
          cprController.stop();
        });

        testWidgets('SOS Screen (no contacts) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final emptyStore = MedicalIdStore();
          await emptyStore.saveMedicalId(const MedicalId());

          await tester.pumpWidget(wrapWithTheme(
            child: SosScreen(store: emptyStore),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('SOS Screen (with contacts) - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final filledStore = MedicalIdStore();
          await filledStore.saveMedicalId(const MedicalId(
            bloodGroup: 'O+',
            contacts: [
              EmergencyContact(
                  name: 'Jane Doe', phone: '+1234567890', relation: 'Spouse'),
              EmergencyContact(
                  name: 'Dr. Smith',
                  phone: '+1987654321',
                  relation: 'Physician'),
            ],
          ));

          await tester.pumpWidget(wrapWithTheme(
            child: SosScreen(store: filledStore),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Medical ID Screen - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const MedicalIdScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Medical Profile Screen - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const ProfileScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('History Screen - $modeName scale $scale', (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const HistoryScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Benchmark Screen - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: const BenchmarkScreen(),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });

        testWidgets('Model Setup Screen - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final ctrl = TriageController(
            downloadService: FakeNotReadyDownloadService(),
            protocolRepository: repo,
          );

          await tester.pumpWidget(wrapWithTheme(
            child: const ModelSetupScreen(),
            mode: mode,
            textScale: scale,
            triageController: ctrl,
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
        });

        testWidgets(
            'Settings Sheet with dropdown opened - $modeName scale $scale',
            (tester) async {
          setIPhone16(tester);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(wrapWithTheme(
            child: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => showCarePulseSettingsSheet(ctx),
                    child: const Text('Open Settings'),
                  ),
                ),
              ),
            ),
            mode: mode,
            textScale: scale,
          ));
          await tester.pumpAndSettle();

          // Open settings sheet
          await tester.tap(find.text('Open Settings'));
          await tester.pumpAndSettle();
          expect(find.text('Settings & About'), findsOneWidget);

          // Open dropdown selector
          final dropdownFinder = find.byType(DropdownButtonFormField<String>);
          if (dropdownFinder.evaluate().isNotEmpty) {
            await tester.tap(dropdownFinder);
            await tester.pumpAndSettle();
          }

          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('Section 6 - Top Bar and Call Pill Rules', () {
    testWidgets('Exactly one top-bar Call pill per screen on MainShell',
        (tester) async {
      final ctrl = TriageController(
        downloadService: FakeReadyDownloadService(),
        engineService: FakeEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      await ctrl.checkModelStatus();

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>(
              create: (_) => ThemeController()),
          ChangeNotifierProvider<AppSettingsController>(
              create: (_) => AppSettingsController()),
          ChangeNotifierProvider<TriageController>.value(value: ctrl),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MainShell(),
        ),
      ));
      await tester.pumpAndSettle();

      // Top bar call pill is found exactly once
      expect(find.byKey(const Key('topbar_call')), findsOneWidget);

      // Verify no duplicate Call 112 header pills on any other tab
      final tabs = ['Guides', 'CPR', 'SOS'];
      for (final tab in tabs) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('topbar_call')), findsOneWidget);
      }
    });
  });

  group('Section 6 - GlassScaffold Full Screen Height on Pushed Route', () {
    testWidgets('GlassScaffold fills full screen height on pushed route',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProtocolDetailScreen(protocol: repo.allProtocols.first),
                ),
              );
            },
            child: const Text('Push Route'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Push Route'));
      await tester.pumpAndSettle();

      // Find the GradientBackground in ProtocolDetailScreen
      final gradientFinder = find.byType(GradientBackground);
      expect(gradientFinder, findsOneWidget);

      final renderBox = tester.renderObject<RenderBox>(gradientFinder);
      expect(renderBox.size.height, equals(852.0));
      expect(renderBox.size.width, equals(393.0));
    });
  });

  group('Section 6 - Dropdown Surface Opacity & Guide Titles', () {
    testWidgets('Settings dropdown menu overlay has opaque surface (alpha 255)',
        (tester) async {
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>(
              create: (_) => ThemeController()),
          ChangeNotifierProvider<AppSettingsController>(
              create: (_) => AppSettingsController()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showCarePulseSettingsSheet(ctx),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);

      final dropdownWidget =
          tester.widget<DropdownButton<String>>(dropdownFinder);
      // Verify dropdownColor has alpha 255
      expect((dropdownWidget.dropdownColor!.a * 255.0).round(), equals(255));
    });

    testWidgets(
        'Guide card titles wrap to 2 lines without truncation at text scale 1.0',
        (tester) async {
      final ctrl = TriageController(
        downloadService: FakeReadyDownloadService(),
        protocolRepository: repo,
      );

      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<TriageController>.value(value: ctrl),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const GuidesScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Verify all guide cards have maxLines: 2 for titles
      final titleTexts = tester.widgetList<Text>(find.byType(Text)).where((t) {
        return repo.allProtocols.any((p) => p.title == t.data);
      }).toList();

      expect(titleTexts, isNotEmpty);
      for (final titleWidget in titleTexts) {
        expect(titleWidget.maxLines, equals(2));
      }
    });
  });
}
