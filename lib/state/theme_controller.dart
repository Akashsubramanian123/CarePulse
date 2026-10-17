import 'package:flutter/material.dart';
import 'app_settings_controller.dart';

/// Manages application theme mode with SharedPreferences persistence.
/// Extends AppSettingsController for backward compatibility.
class ThemeController extends AppSettingsController {
  static const String themeModeKey = AppSettingsController.themeModeKey;

  ThemeController({ThemeMode defaultMode = ThemeMode.system})
      : super(defaultThemeMode: defaultMode);

  /// Loads the persisted theme mode from SharedPreferences.
  static Future<ThemeController> load() async {
    final settings = await AppSettingsController.load();
    return ThemeController(defaultMode: settings.themeMode);
  }
}
