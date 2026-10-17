import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/emergency_config.dart';

/// Manages application-wide settings: ThemeMode, Region-aware Emergency Number, and History persistence.
class AppSettingsController extends ChangeNotifier {
  static const String themeModeKey = 'app_theme_mode';
  static const String emergencyNumberKey = 'app_emergency_number';
  static const String selectedCountryKey = 'app_selected_country';
  static const String saveHistoryKey = 'app_save_history';

  ThemeMode _themeMode;
  String _emergencyNumber;
  String _selectedCountry;
  bool _saveHistory;

  AppSettingsController({
    ThemeMode defaultThemeMode = ThemeMode.system,
    String? defaultEmergencyNumber,
    String? defaultSelectedCountry,
    bool defaultSaveHistory = true,
  })  : _themeMode = defaultThemeMode,
        _emergencyNumber = defaultEmergencyNumber ??
            resolveEmergencyNumberForCountryCode(
                PlatformDispatcher.instance.locale.countryCode),
        _selectedCountry = defaultSelectedCountry ??
            resolveCountryNameForCountryCode(
                PlatformDispatcher.instance.locale.countryCode),
        _saveHistory = defaultSaveHistory;

  ThemeMode get themeMode => _themeMode;
  String get emergencyNumber => _emergencyNumber;
  String get selectedCountry => _selectedCountry;
  bool get saveHistory => _saveHistory;

  /// Loads persisted settings from SharedPreferences, falling back to device locale defaults.
  static Future<AppSettingsController> load({String? testCountryCode}) async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString(themeModeKey);
    ThemeMode initialTheme = ThemeMode.system;
    if (savedTheme == 'light') {
      initialTheme = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      initialTheme = ThemeMode.dark;
    } else if (savedTheme == 'system') {
      initialTheme = ThemeMode.system;
    }

    final localeCode =
        testCountryCode ?? PlatformDispatcher.instance.locale.countryCode;
    final defaultNumber = resolveEmergencyNumberForCountryCode(localeCode);
    final defaultCountry = resolveCountryNameForCountryCode(localeCode);

    final savedNumber = prefs.getString(emergencyNumberKey) ?? defaultNumber;
    final savedCountry = prefs.getString(selectedCountryKey) ?? defaultCountry;
    final savedSaveHistory = prefs.getBool(saveHistoryKey) ?? true;

    return AppSettingsController(
      defaultThemeMode: initialTheme,
      defaultEmergencyNumber: savedNumber,
      defaultSelectedCountry: savedCountry,
      defaultSaveHistory: savedSaveHistory,
    );
  }

  /// Sets theme mode and persists it.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(themeModeKey, mode.name);
    } catch (_) {}
  }

  /// Cycles theme mode: light -> dark -> system -> light.
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

  /// Sets emergency number with country and persists it. Returns false if validation fails.
  Future<bool> setEmergencyNumber(String number, {String? country}) async {
    final trimmed = number.trim();
    if (!isValidCustomEmergencyNumber(trimmed)) {
      return false;
    }

    _emergencyNumber = trimmed;
    if (country != null) {
      _selectedCountry = country;
    } else {
      // Find matching country or set custom
      final match = emergencyCountries.cast<EmergencyCountry?>().firstWhere(
            (c) => c?.number == trimmed,
            orElse: () => null,
          );
      _selectedCountry = match?.name ?? customCountryName;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(emergencyNumberKey, _emergencyNumber);
      await prefs.setString(selectedCountryKey, _selectedCountry);
    } catch (_) {}
    return true;
  }

  /// Sets selected country from predefined list or custom.
  Future<void> setCountry(String countryName, {String? customNumber}) async {
    _selectedCountry = countryName;
    if (countryName == customCountryName) {
      if (customNumber != null && isValidCustomEmergencyNumber(customNumber)) {
        _emergencyNumber = customNumber.trim();
      }
    } else {
      final country = emergencyCountries.firstWhere(
        (c) => c.name == countryName,
        orElse: () => const EmergencyCountry(name: 'Other', number: '112'),
      );
      _emergencyNumber = country.number;
    }
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(emergencyNumberKey, _emergencyNumber);
      await prefs.setString(selectedCountryKey, _selectedCountry);
    } catch (_) {}
  }

  /// Toggles whether queries and responses are saved to local history.
  Future<void> setSaveHistory(bool value) async {
    if (_saveHistory == value) return;
    _saveHistory = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(saveHistoryKey, value);
    } catch (_) {}
  }
}
