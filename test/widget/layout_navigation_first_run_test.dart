import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/constants/app_constants.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/models/protocol.dart';
import 'package:carepulse/services/history_store.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/profile_service.dart';
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
import 'package:carepulse/ui/screens/medical_id_screen.dart';
import 'package:carepulse/ui/screens/model_setup_screen.dart';
import 'package:carepulse/ui/screens/profile_screen.dart';
import 'package:carepulse/ui/screens/protocol_detail_screen.dart';
import 'package:carepulse/ui/screens/sos_screen.dart';
import 'package:carepulse/ui/widgets/glass_card.dart';
import 'package:carepulse/ui/widgets/settings_sheet.dart';

// --- Fakes ---
class TestModelDownloadService extends ModelDownloadService {
  bool ready = false;
  bool downloading = false;
  bool verifying = false;
  String? error;
  int partialBytes = 0;
  int totalBytes = AppConstants.modelSizeBytes;
  double progress = 0.0;
  bool downloadStarted = false;
  bool pauseCalled = false;
  Completer<void>? downloadCompleter;

  @override
  Future<bool> isModelReady() async => ready;

  @override
  Future<bool> hasUnverifiedModel() async => verifying;

  @override
  Future<int> getPartialBytes() async => partialBytes;

  @override
  Future<bool> hasPartialDownload() async => partialBytes > 0;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';

  Completer<bool>? verifyCompleter;

  @override
  Future<bool> verifyExistingModel() async {
    if (verifyCompleter != null) {
      return await verifyCompleter!.future;
    }
    return false;
  }

  @override
  Future<void> downloadModel({
    required DownloadProgressCallback onProgress,
    CancelToken? cancelToken,
    void Function()? onVerifyingStart,
  }) async {
    downloadStarted = true;
    downloading = true;
    if (error != null) {
      throw Exception(error);
    }
    if (onVerifyingStart != null && verifying) {
      onVerifyingStart();
    }
    final totalMb = totalBytes / 1000000.0;
    onProgress(progress, progress * totalMb, totalMb);
    cancelToken?.whenCancel.then((_) {
      if (downloadCompleter != null && !downloadCompleter!.isCompleted) {
        downloadCompleter!.complete();
      }
    });
    if (downloadCompleter != null && !downloadCompleter!.isCompleted) {
      await downloadCompleter!.future;
    }
    if (cancelToken != null && cancelToken.isCancelled) {
      throw DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.cancel,
      );
    }
  }

  void pauseDownload() {
    pauseCalled = true;
    downloading = false;
    if (downloadCompleter != null && !downloadCompleter!.isCompleted) {
      downloadCompleter!.complete();
    }
  }
}

class TestEngineService extends TriageEngineService {
  bool shouldReturnEmpty = false;
  String generatedText = '1. IMMEDIATE ACTION: Apply pressure to wound.';

  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  double getEstimatedRamUsageMB() => 750.0;

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? context,
  }) async* {
    if (shouldReturnEmpty) {
      return;
    }
    yield generatedText;
  }
}

double linearize(double c) {
  return (c <= 0.03928)
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = relativeLuminance(c1);
  final l2 = relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  late ProtocolRepository repo;
  late ProtocolRetriever retriever;
  late RedFlagEngine redFlagEngine;
  late TriageClarifier clarifier;
  late Protocol sampleProtocol;

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
    sampleProtocol = repo.allProtocols.first;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_v1_seen': true});
  });

  Widget buildTestApp({
    required Widget child,
    required double topInset,
    required double bottomInset,
    required Size screenSize,
    required double textScale,
    TriageController? triageController,
    AppSettingsController? settingsController,
  }) {
    final tCtrl = triageController ??
        TriageController(
          downloadService: TestModelDownloadService()..ready = true,
          engineService: TestEngineService(),
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
          create: (_) => ThemeController(),
        ),
        ChangeNotifierProvider<AppSettingsController>.value(value: sCtrl),
        ChangeNotifierProvider<TriageController>.value(value: tCtrl),
        ChangeNotifierProvider<CprController>(
          create: (_) => CprController(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: screenSize,
            padding: EdgeInsets.only(
              top: topInset,
              bottom: bottomInset,
            ),
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('1. Safe-area and header layout (all screens)', () {
    final testConfigs = [
      (
        name: 'iPhone 16 with Dynamic Island',
        size: const Size(393, 852),
        top: 59.0,
        bottom: 34.0
      ),
      (
        name: 'Small phone punch-hole',
        size: const Size(360, 640),
        top: 24.0,
        bottom: 0.0
      ),
      (
        name: 'Large phone notch',
        size: const Size(430, 932),
        top: 59.0,
        bottom: 34.0
      ),
      (
        name: 'Tablet 800x1280',
        size: const Size(800, 1280),
        top: 24.0,
        bottom: 0.0
      ),
      (
        name: 'Landscape 852x393',
        size: const Size(852, 393),
        top: 0.0,
        bottom: 21.0
      ),
    ];

    final screens = <String, Widget Function()>{
      'HistoryScreen': () => const HistoryScreen(),
      'BenchmarkScreen': () => const BenchmarkScreen(),
      'MedicalIdScreen': () => const MedicalIdScreen(),
      'ProfileScreen': () => const ProfileScreen(),
      'ProtocolDetailScreen': () =>
          ProtocolDetailScreen(protocol: sampleProtocol),
      'ModelSetupScreen': () => const ModelSetupScreen(),
      'GuidesScreen': () => const GuidesScreen(),
      'CprScreen': () => const CprScreen(),
      'SosScreen': () => const SosScreen(),
      'EmergencyHomeScreen': () => const EmergencyHomeScreen(),
    };

    for (final config in testConfigs) {
      for (final scale in [1.0, 1.6]) {
        testWidgets(
            'Layout verification on ${config.name} at scale $scale for all screens',
            (tester) async {
          tester.view.physicalSize = config.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          for (final entry in screens.entries) {
            await tester.pumpWidget(
              buildTestApp(
                child: entry.value(),
                topInset: config.top,
                bottomInset: config.bottom,
                screenSize: config.size,
                textScale: scale,
              ),
            );
            await tester.pumpAndSettle();

            // Verify no rendering exceptions
            expect(tester.takeException(), isNull,
                reason: 'Screen ${entry.key} threw an exception');

            // Find title if screen uses GlassScaffold
            final glassScaffolds = find.byType(GlassScaffold);
            if (glassScaffolds.evaluate().isNotEmpty) {
              final scaffoldWidget =
                  tester.widget<GlassScaffold>(glassScaffolds.first);
              if (scaffoldWidget.title != null) {
                final titleFinder = find.text(scaffoldWidget.title!);
                if (titleFinder.evaluate().isNotEmpty) {
                  final titleRect = tester.getRect(titleFinder.first);
                  // Title must be at or below safe top inset
                  expect(titleRect.top, greaterThanOrEqualTo(config.top - 1.0),
                      reason:
                          '${entry.key} title top (${titleRect.top}) should be >= top padding (${config.top})');
                }
              }
            }

            // Tablet constraint check: if tablet (width 800), content max width is <= 640
            if (config.size.width >= 800) {
              final constrainedBoxes = find.byType(ConstrainedBox);
              bool foundTabletConstraint = false;
              for (final element in constrainedBoxes.evaluate()) {
                final renderBox = element.renderObject as RenderBox?;
                if (renderBox != null && renderBox.hasSize) {
                  if (renderBox.size.width <= 640.1 &&
                      renderBox.size.width > 200) {
                    foundTabletConstraint = true;
                    break;
                  }
                }
              }
              expect(foundTabletConstraint, isTrue,
                  reason:
                      '${entry.key} on tablet should constrain content to max width 640');
            }
          }
        });
      }
    }

    testWidgets('Query History note is a normal text row below top bar',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const HistoryScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      final noteFinder = find.text('History stays on this device.');
      expect(noteFinder, findsWidgets);

      final noteRect = tester.getRect(noteFinder.first);
      // Top bar is at 59..115, note must be below top bar (top >= 115)
      expect(noteRect.top, greaterThanOrEqualTo(59.0 + 56.0 - 1.0));
    });

    testWidgets(
        'BenchmarkScreen shows shortened "Benchmark" in bar and heading inside page',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const BenchmarkScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Shortened top bar title
      final scaffold = tester.widget<GlassScaffold>(find.byType(GlassScaffold));
      expect(scaffold.title, 'Benchmark');

      // Heading inside page body
      expect(find.text('Benchmark & Evaluation'), findsOneWidget);
    });

    testWidgets('Settings sheet Theme SegmentedButton fills full width',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showCarePulseSettingsSheet(context),
              child: const Text('Open Settings'),
            );
          }),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      final segmentedFinder = find.byType(SegmentedButton<ThemeMode>);
      expect(segmentedFinder, findsOneWidget);

      final segRect = tester.getRect(segmentedFinder);
      // Sheet has 24 padding each side, 393 - 48 = 345 width
      expect(segRect.width, greaterThan(320.0));
    });

    test('Query History Clear all and delete icons contrast >= 4.5:1', () {
      final lightTheme = AppTheme.lightTheme;
      final darkTheme = AppTheme.darkTheme;

      final lightError = lightTheme.colorScheme.error;
      final lightSurface = lightTheme.colorScheme.surface;
      final ratioLight = contrastRatio(lightError, lightSurface);
      expect(ratioLight, greaterThanOrEqualTo(4.5));

      final darkError = darkTheme.colorScheme.error;
      final darkSurface = darkTheme.colorScheme.surface;
      final ratioDark = contrastRatio(darkError, darkSurface);
      expect(ratioDark, greaterThanOrEqualTo(4.5));
    });
  });

  group('2. Restore access to profiles', () {
    testWidgets(
        'Assistant status row has assistant_profile_button (48x48) opening Medical Profile',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      final profileBtn = find.byKey(const Key('assistant_profile_button'));
      expect(profileBtn, findsOneWidget);

      // Verify tap target size >= 48x48
      final btnRect = tester.getRect(profileBtn);
      expect(btnRect.width, greaterThanOrEqualTo(48.0));
      expect(btnRect.height, greaterThanOrEqualTo(48.0));

      // Tap button and verify ProfileScreen opens
      await tester.tap(profileBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets(
        'SOS tab has glass card sos_medical_id_button at top of content opening Medical ID',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const SosScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      final sosMedIdBtn = find.byKey(const Key('sos_medical_id_button'));
      expect(sosMedIdBtn, findsOneWidget);

      expect(find.text('Medical ID'), findsOneWidget);
      expect(find.text('Allergies, blood group, contacts'), findsOneWidget);

      await tester.tap(sosMedIdBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MedicalIdScreen), findsOneWidget);
    });

    testWidgets(
        'Settings sheet has Profile section with Medical profile and Medical ID tiles',
        (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: Builder(builder: (context) {
            return ElevatedButton(
              onPressed: () => showCarePulseSettingsSheet(context),
              child: const Text('Open Settings'),
            );
          }),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      final aiProfileTile = find.text('Medical profile (used by the AI)');
      final sosProfileTile =
          find.text('Medical ID (for first responders and SOS)');
      expect(aiProfileTile, findsOneWidget);
      expect(sosProfileTile, findsOneWidget);

      // Tap Medical profile tile
      await tester.tap(aiProfileTile);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      // Back to settings
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Open settings again
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Ensure Medical ID tile is visible
      final medIdTileFinder =
          find.text('Medical ID (for first responders and SOS)');
      await tester.ensureVisible(medIdTileFinder);
      await tester.pumpAndSettle();

      // Tap Medical ID tile
      await tester.tap(medIdTileFinder);
      await tester.pumpAndSettle();
      expect(find.byType(MedicalIdScreen), findsOneWidget);
    });
  });

  group('3. Model-not-ready experience & Onboarding', () {
    testWidgets(
        'Onboarding sheet shows on first launch and does not show after simulated relaunch',
        (tester) async {
      SharedPreferences.setMockInitialValues({}); // first launch

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Welcome bottom sheet appears
      expect(find.text('Welcome to CarePulse'), findsOneWidget);
      expect(find.text('Download AI model now'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);

      // Tap Later to dismiss
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome to CarePulse'), findsNothing);

      // Simulate relaunch: pump again
      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
        ),
      );
      await tester.pumpAndSettle();

      // Sheet should NOT appear again
      expect(find.text('Welcome to CarePulse'), findsNothing);
    });

    testWidgets(
        'Sticky banner appears in needs download, downloading, verifying, error, and hidden when ready',
        (tester) async {
      final downloadService = TestModelDownloadService();
      final tCtrl = TriageController(
        downloadService: downloadService,
        engineService: TestEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );

      // 1. Needs download
      downloadService.ready = false;
      downloadService.partialBytes = 0;
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('AI answers need a one-time'), findsOneWidget);
      expect(find.text('Download AI model'), findsOneWidget);
      expect(find.text('AI model not downloaded'), findsOneWidget); // Pill

      // Model setup box at bottom of Assistant is GONE
      expect(find.text('Offline AI model setup'), findsNothing);

      // 2. Partial download exists -> "Resume download (42%)"
      downloadService.partialBytes =
          (0.42 * AppConstants.modelSizeBytes).round();
      await tCtrl.checkModelStatus();
      await tester.pumpAndSettle();

      expect(find.textContaining('Resume download (42%)'), findsOneWidget);

      // 3. Downloading state -> progress bar, percent, Pause
      downloadService.downloadCompleter = Completer<void>();
      downloadService.progress = 0.42;
      tCtrl.startModelDownload();
      await tester.pump();

      expect(find.textContaining('Downloading 42%'), findsWidgets);
      expect(find.text('Pause'), findsOneWidget);

      // Tap Pause
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      // 4. Verifying state -> "Verifying download..."
      downloadService.downloading = false;
      downloadService.verifying = true;
      downloadService.verifyCompleter = Completer<bool>();
      tCtrl.checkModelStatus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Verifying download...'), findsWidgets);

      // Complete verifying
      downloadService.verifying = false;
      downloadService.verifyCompleter!.complete(false);
      await tester.pump();

      // 5. Error state -> message + Retry
      downloadService.error = 'Network failure during download';
      await tCtrl.checkModelStatus();
      await tCtrl.startModelDownload();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Network failure during download'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // 6. Ready state -> banner hidden
      downloadService.error = null;
      downloadService.ready = true;
      downloadService.verifying = false;
      await tCtrl.checkModelStatus();
      await tester.pumpAndSettle();

      expect(find.textContaining('AI answers need a one-time'), findsNothing);
      expect(find.text('Offline · AI ready'), findsOneWidget); // Pill ready
    });

    testWidgets(
        'Details link opens ModelSetupScreen and closes when model ready',
        (tester) async {
      final downloadService = TestModelDownloadService();
      final tCtrl = TriageController(
        downloadService: downloadService,
        engineService: TestEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      downloadService.ready = false;
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      final detailsFinder = find.text('Details');
      expect(detailsFinder, findsOneWidget);

      await tester.tap(detailsFinder);
      await tester.pumpAndSettle();

      expect(find.byType(ModelSetupScreen), findsOneWidget);

      // Auto-closes when model becomes ready
      downloadService.ready = true;
      await tCtrl.checkModelStatus();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(ModelSetupScreen), findsNothing);
    });

    testWidgets(
        'Controller: no model + vague query -> unavailable card & no "No response generated."',
        (tester) async {
      final downloadService = TestModelDownloadService()..ready = false;
      final tCtrl = TriageController(
        downloadService: downloadService,
        engineService: TestEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'I do not feel great today');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      // If clarifier shows up, answer it
      if (find.widgetWithText(ElevatedButton, 'Yes').evaluate().isNotEmpty) {
        await tester.tap(find.widgetWithText(ElevatedButton, 'Yes'));
        await tester.pumpAndSettle();
        if (find.widgetWithText(ElevatedButton, 'Yes').evaluate().isNotEmpty) {
          await tester.tap(find.widgetWithText(ElevatedButton, 'Yes'));
          await tester.pumpAndSettle();
        }
      }

      expect(find.text('AI model not downloaded yet'), findsOneWidget);
      expect(find.text('Open Guides'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('No response generated.'), findsNothing);
    });

    testWidgets(
        'Controller: no model + confident retrieval -> protocol appears labeled "Verified protocol"',
        (tester) async {
      final downloadService = TestModelDownloadService()..ready = false;
      final tCtrl = TriageController(
        downloadService: downloadService,
        engineService: TestEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      // Confident query for severe bleeding or burns
      await tester.enterText(
          find.byType(TextField), 'boiling water burned arm');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Verified protocol'), findsOneWidget);
      expect(tCtrl.answerSource, AnswerSource.verifiedProtocol);
    });

    testWidgets('Controller: red flags still instant without model',
        (tester) async {
      final downloadService = TestModelDownloadService()..ready = false;
      final tCtrl = TriageController(
        downloadService: downloadService,
        engineService: TestEngineService(),
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'crushing chest pain radiating to left arm');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('CRITICAL RED FLAG'), findsOneWidget);
      expect(tCtrl.callEmergencyNow, isTrue);
    });

    testWidgets(
        'Controller: empty generation -> retry message with Retry button',
        (tester) async {
      final engineService = TestEngineService()..shouldReturnEmpty = true;
      final tCtrl = TriageController(
        downloadService: TestModelDownloadService()..ready = true,
        engineService: engineService,
        protocolRepository: repo,
        protocolRetriever: retriever,
        redFlagEngine: redFlagEngine,
        triageClarifier: clarifier,
        historyStore: HistoryStore(),
      );
      await tCtrl.checkModelStatus();

      await tester.pumpWidget(
        buildTestApp(
          child: const EmergencyHomeScreen(),
          topInset: 59.0,
          bottomInset: 34.0,
          screenSize: const Size(393, 852),
          textScale: 1.0,
          triageController: tCtrl,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextField), 'boiling water burned arm');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();

      expect(
          find.text('The AI did not return an answer. Try again or rephrase.'),
          findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}
