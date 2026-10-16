import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'state/theme_controller.dart';
import 'state/triage_controller.dart';
import 'ui/screens/emergency_home_screen.dart';
import 'ui/screens/main_shell.dart';
import 'ui/screens/model_setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeController = await ThemeController.load();
  runApp(CarePulseApp(themeController: themeController));
}

class CarePulseApp extends StatelessWidget {
  final ThemeController? themeController;

  const CarePulseApp({super.key, this.themeController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TriageController()),
        if (themeController != null)
          ChangeNotifierProvider<ThemeController>.value(
            value: themeController!,
          )
        else
          ChangeNotifierProvider<ThemeController>(
            create: (_) => ThemeController(),
          ),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: theme.themeMode,
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
