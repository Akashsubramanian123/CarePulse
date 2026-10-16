import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/state/theme_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeController Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Default mode is ThemeMode.system', () {
      final controller = ThemeController();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('Change theme mode updates property, notifies listeners and persists',
        () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      await controller.setThemeMode(ThemeMode.dark);

      expect(controller.themeMode, ThemeMode.dark);
      expect(notified, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(ThemeController.themeModeKey), 'dark');
    });

    test('ThemeController.load restores saved mode from SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({
        ThemeController.themeModeKey: 'light',
      });

      final controller = await ThemeController.load();
      expect(controller.themeMode, ThemeMode.light);

      SharedPreferences.setMockInitialValues({
        ThemeController.themeModeKey: 'dark',
      });
      final darkController = await ThemeController.load();
      expect(darkController.themeMode, ThemeMode.dark);

      SharedPreferences.setMockInitialValues({
        ThemeController.themeModeKey: 'system',
      });
      final sysController = await ThemeController.load();
      expect(sysController.themeMode, ThemeMode.system);
    });

    test('cycleTheme cycles light -> dark -> system -> light', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController(defaultMode: ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);

      await controller.cycleTheme();
      expect(controller.themeMode, ThemeMode.dark);

      await controller.cycleTheme();
      expect(controller.themeMode, ThemeMode.system);

      await controller.cycleTheme();
      expect(controller.themeMode, ThemeMode.light);
    });
  });
}
