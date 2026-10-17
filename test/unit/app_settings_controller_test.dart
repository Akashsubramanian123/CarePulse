import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carepulse/core/constants/emergency_config.dart';
import 'package:carepulse/state/app_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsController Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
        'Defaults are system theme, resolved emergency number, and saveHistory true',
        () {
      final controller = AppSettingsController(
        defaultThemeMode: ThemeMode.system,
        defaultEmergencyNumber: '112',
        defaultSelectedCountry: 'India',
        defaultSaveHistory: true,
      );

      expect(controller.themeMode, equals(ThemeMode.system));
      expect(controller.emergencyNumber, equals('112'));
      expect(controller.selectedCountry, equals('India'));
      expect(controller.saveHistory, isTrue);
    });

    test('Locale mapping resolves correct standard numbers', () {
      expect(resolveEmergencyNumberForCountryCode('IN'), equals('112'));
      expect(resolveEmergencyNumberForCountryCode('US'), equals('911'));
      expect(resolveEmergencyNumberForCountryCode('CA'), equals('911'));
      expect(resolveEmergencyNumberForCountryCode('GB'), equals('999'));
      expect(resolveEmergencyNumberForCountryCode('UK'), equals('999'));
      expect(resolveEmergencyNumberForCountryCode('AU'), equals('000'));
      expect(resolveEmergencyNumberForCountryCode('NZ'), equals('111'));
      expect(resolveEmergencyNumberForCountryCode('FR'), equals('112'));
      expect(resolveEmergencyNumberForCountryCode('DE'), equals('112'));
      expect(resolveEmergencyNumberForCountryCode('XX'), equals('112'));
      expect(resolveEmergencyNumberForCountryCode(null), equals('112'));
      expect(resolveEmergencyNumberForCountryCode(''), equals('112'));
    });

    test('Custom emergency number validation allows 2 to 6 digits only', () {
      expect(isValidCustomEmergencyNumber('911'), isTrue);
      expect(isValidCustomEmergencyNumber('112'), isTrue);
      expect(isValidCustomEmergencyNumber('000'), isTrue);
      expect(isValidCustomEmergencyNumber('12'), isTrue);
      expect(isValidCustomEmergencyNumber('123456'), isTrue);

      expect(isValidCustomEmergencyNumber('1'), isFalse); // too short
      expect(isValidCustomEmergencyNumber('1234567'), isFalse); // too long
      expect(isValidCustomEmergencyNumber('911a'), isFalse); // non-digit
      expect(isValidCustomEmergencyNumber('+911'), isFalse); // symbols
      expect(isValidCustomEmergencyNumber(''), isFalse); // empty
      expect(isValidCustomEmergencyNumber('   '), isFalse);
    });

    test('Settings persist and reload across instances', () async {
      SharedPreferences.setMockInitialValues({
        AppSettingsController.themeModeKey: 'dark',
        AppSettingsController.emergencyNumberKey: '911',
        AppSettingsController.selectedCountryKey: 'US / Canada',
        AppSettingsController.saveHistoryKey: false,
      });

      final controller = await AppSettingsController.load();

      expect(controller.themeMode, equals(ThemeMode.dark));
      expect(controller.emergencyNumber, equals('911'));
      expect(controller.selectedCountry, equals('US / Canada'));
      expect(controller.saveHistory, isFalse);

      // Mutate and verify SharedPreferences update
      await controller.setThemeMode(ThemeMode.light);
      await controller.setEmergencyNumber('999', country: 'United Kingdom');
      await controller.setSaveHistory(true);

      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.getString(AppSettingsController.themeModeKey), equals('light'));
      expect(prefs.getString(AppSettingsController.emergencyNumberKey),
          equals('999'));
      expect(prefs.getString(AppSettingsController.selectedCountryKey),
          equals('United Kingdom'));
      expect(prefs.getBool(AppSettingsController.saveHistoryKey), isTrue);
    });

    test('Rejects invalid custom emergency number', () async {
      final controller = AppSettingsController(
        defaultEmergencyNumber: '112',
      );

      final success = await controller.setEmergencyNumber('invalid');
      expect(success, isFalse);
      expect(controller.emergencyNumber, equals('112'));
    });

    test('Cycle theme switches light -> dark -> system -> light', () async {
      final controller = AppSettingsController(
        defaultThemeMode: ThemeMode.light,
      );

      await controller.cycleTheme();
      expect(controller.themeMode, equals(ThemeMode.dark));

      await controller.cycleTheme();
      expect(controller.themeMode, equals(ThemeMode.system));

      await controller.cycleTheme();
      expect(controller.themeMode, equals(ThemeMode.light));
    });
  });
}
