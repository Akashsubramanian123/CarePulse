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
import 'package:carepulse/state/theme_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/main_shell.dart';

class ReadyModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';
}

class FakeTriageEngineService extends TriageEngineService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  double getEstimatedRamUsageMB() => 850.0;

  @override
  Stream<String> generateTriage(
    String query, {
    void Function(TriageTelemetry telemetry)? onTelemetryUpdate,
    UserProfile? profile,
    String? context,
  }) async* {
    yield '1. IMMEDIATE ACTION: Simulated advice.';
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Tapping theme in Settings sheet changes MaterialApp.themeMode',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final themeController = ThemeController(defaultMode: ThemeMode.system);
    final downloadService = ReadyModelDownloadService();
    final triageController = TriageController(
      downloadService: downloadService,
      engineService: FakeTriageEngineService(),
      protocolRepository: repo,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(
            value: themeController,
          ),
          ChangeNotifierProvider<TriageController>.value(
            value: triageController,
          ),
        ],
        child: Consumer<ThemeController>(
          builder: (context, theme, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.themeMode,
              home: const MainShell(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    MaterialApp getMaterialApp() {
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    // Default themeMode is system
    expect(getMaterialApp().themeMode, ThemeMode.system);

    // Open Settings sheet from Assistant AppBar
    final settingsButton = find.byTooltip('Settings');
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Verify SegmentedButton options exist
    expect(find.text('Settings & About'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);

    // Tap Light
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.light);
    expect(themeController.themeMode, ThemeMode.light);

    // Tap Dark
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.dark);
    expect(themeController.themeMode, ThemeMode.dark);

    // Tap System
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.system);
    expect(themeController.themeMode, ThemeMode.system);
  });

  testWidgets(
      'Quick sun/moon button in MainShell cycles MaterialApp.themeMode (light -> dark -> system)',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final themeController = ThemeController(defaultMode: ThemeMode.system);
    final triageController = TriageController(
      downloadService: ReadyModelDownloadService(),
      engineService: FakeTriageEngineService(),
      protocolRepository: repo,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeController>.value(
            value: themeController,
          ),
          ChangeNotifierProvider<TriageController>.value(
            value: triageController,
          ),
        ],
        child: Consumer<ThemeController>(
          builder: (context, theme, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: theme.themeMode,
              home: const MainShell(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    MaterialApp getMaterialApp() {
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    final quickButton = find.byKey(const ValueKey('quick_theme_toggle_button'));
    expect(quickButton, findsOneWidget);

    // Initial mode is system
    expect(getMaterialApp().themeMode, ThemeMode.system);

    // Tap 1: system -> light
    await tester.tap(quickButton);
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.light);
    expect(themeController.themeMode, ThemeMode.light);

    // Tap 2: light -> dark
    await tester.tap(quickButton);
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.dark);
    expect(themeController.themeMode, ThemeMode.dark);

    // Tap 3: dark -> system
    await tester.tap(quickButton);
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, ThemeMode.system);
    expect(themeController.themeMode, ThemeMode.system);
  });
}
