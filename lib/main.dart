import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'state/app_settings_controller.dart';
import 'state/theme_controller.dart';
import 'state/triage_controller.dart';
import 'ui/screens/emergency_home_screen.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/model_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsController = await AppSettingsController.load();
  runApp(CarePulseApp(settingsController: settingsController));
}

class CarePulseApp extends StatelessWidget {
  final AppSettingsController? settingsController;
  final ThemeController? themeController;

  const CarePulseApp({
    super.key,
    this.settingsController,
    this.themeController,
  });

  @override
  Widget build(BuildContext context) {
    final settings =
        settingsController ?? themeController ?? AppSettingsController();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettingsController>.value(value: settings),
        ChangeNotifierProxyProvider<AppSettingsController, TriageController>(
          create: (_) => TriageController(settingsController: settings),
          update: (_, appSettings, triage) =>
              (triage ?? TriageController(settingsController: appSettings))
                ..updateSettings(appSettings),
        ),
        ChangeNotifierProvider<ThemeController>.value(
          value: settings is ThemeController
              ? settings
              : ThemeController(defaultMode: settings.themeMode),
        ),
      ],
      child: Consumer<AppSettingsController>(
        builder: (context, appSettings, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: appSettings.themeMode,
            home: const MainShell(),
          );
        },
      ),
    );
  }
}

class RootScreenRouter extends StatelessWidget {
  const RootScreenRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TriageController>();

    if (controller.isReady) {
      return const EmergencyHomeScreen();
    } else {
      return const ModelSetupScreen();
    }
  }
}
