import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/theme/app_theme.dart';
import 'package:carepulse/services/model_download_service.dart';
import 'package:carepulse/services/protocol_repository.dart';
import 'package:carepulse/services/triage_engine_service.dart';
import 'package:carepulse/state/app_settings_controller.dart';
import 'package:carepulse/state/theme_controller.dart';
import 'package:carepulse/state/triage_controller.dart';
import 'package:carepulse/ui/screens/main_shell.dart';

class FakeTriageEngineService extends TriageEngineService {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initializeEngine(String modelPath) async {}

  @override
  double getEstimatedRamUsageMB() => 850.0;
}

class FakeModelDownloadService extends ModelDownloadService {
  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<String> getModelPath() async => '/fake/model.gguf';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'onboarding_v2_seen': true,
      'profile_prompt_dismissed': true,
    });
  });

  testWidgets(
      'AppSettingsController themeMode setting changes MaterialApp.themeMode',
      (WidgetTester tester) async {
    final settingsController = AppSettingsController(
      defaultThemeMode: ThemeMode.system,
      defaultEmergencyNumber: '112',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsController>.value(
            value: settingsController,
          ),
        ],
        child: Consumer<AppSettingsController>(
          builder: (context, settings, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode,
              home: const Scaffold(body: Text('Test Body')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    MaterialApp getMaterialApp() =>
        tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(getMaterialApp().themeMode, equals(ThemeMode.system));

    await settingsController.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, equals(ThemeMode.dark));

    await settingsController.setThemeMode(ThemeMode.light);
    await tester.pumpAndSettle();
    expect(getMaterialApp().themeMode, equals(ThemeMode.light));
  });

  testWidgets(
      'Call label in MainShell and EmergencyHomeScreen uses the configured emergency number',
      (WidgetTester tester) async {
    final file = File('assets/protocols/protocols.json');
    final jsonStr = file.readAsStringSync();
    final repo = ProtocolRepository();
    repo.loadFromJsonString(jsonStr);

    final settingsController = AppSettingsController(
      defaultThemeMode: ThemeMode.system,
      defaultEmergencyNumber: '911',
      defaultSelectedCountry: 'US / Canada',
    );
    final themeController = ThemeController(defaultMode: ThemeMode.system);
    final triageController = TriageController(
      downloadService: FakeModelDownloadService(),
      engineService: FakeTriageEngineService(),
      protocolRepository: repo,
    );
    await triageController.checkModelStatus();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AppSettingsController>.value(
            value: settingsController,
          ),
          ChangeNotifierProvider<ThemeController>.value(
            value: themeController,
          ),
          ChangeNotifierProvider<TriageController>.value(
            value: triageController,
          ),
        ],
        child: Consumer<AppSettingsController>(
          builder: (context, settings, _) {
            return MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: settings.themeMode,
              home: const MainShell(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify MainShell top bar and emergency buttons have Call 911
    expect(find.text('Call 911'), findsWidgets);
    expect(find.byKey(const ValueKey('main_shell_call_112_button')),
        findsOneWidget);

    // Verify EmergencyHomeScreen primary emergency button has Call emergency · 911
    expect(find.text('Call emergency · 911'), findsOneWidget);

    // Update emergency number dynamically to 999
    await settingsController.setEmergencyNumber('999',
        country: 'United Kingdom');
    await tester.pumpAndSettle();

    // Now labels should be updated to Call 999
    expect(find.text('Call 999'), findsWidgets);
    expect(find.text('Call emergency · 999'), findsOneWidget);
  });
}
