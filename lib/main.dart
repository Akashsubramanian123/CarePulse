import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'state/triage_controller.dart';
import 'ui/screens/emergency_home_screen.dart';
import 'ui/screens/model_setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CarePulseApp());
}

class CarePulseApp extends StatelessWidget {
  const CarePulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TriageController(),
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const RootScreenRouter(),
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
