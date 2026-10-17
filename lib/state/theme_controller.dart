import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages application theme mode with SharedPreferences persistence.
class ThemeController extends ChangeNotifier {
  static const String themeModeKey = 'app_theme_mode';

  ThemeMode _themeMode;

  ThemeController({ThemeMode defaultMode = ThemeMode.system})
      : _themeMode = defaultMode;

  ThemeMode get themeMode => _themeMode;

  /// Loads the persisted theme mode from SharedPreferences.
  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(themeModeKey);

    ThemeMode initialMode = ThemeMode.system;
    if (savedMode == 'light') {
      initialMode = ThemeMode.light;
    } else if (savedMode == 'dark') {
      initialMode = ThemeMode.dark;
    } else if (savedMode == 'system') {
      initialMode = ThemeMode.system;
    }

    return ThemeController(defaultMode: initialMode);
  }

  /// Sets the theme mode, notifies listeners, and persists choice.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModeKey, mode.name);
    } catch (_) {
      // Gracefully ignore storage exceptions in constrained environments
    }
  }

  /// Cycles theme mode: light -> dark -> system -> light...
  Future<void> cycleTheme() async {
    switch (_themeMode) {
      case ThemeMode.light:
        await setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        await setThemeMode(ThemeMode.system);
        break;
      case ThemeMode.system:
        await setThemeMode(ThemeMode.light);
        break;
    }
  }
}
