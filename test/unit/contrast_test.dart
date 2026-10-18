import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carepulse/core/theme/app_theme.dart';

double linearize(double c) {
  return (c <= 0.03928)
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double relativeLuminance(Color color) {
  final r = linearize(color.r);
  final g = linearize(color.g);
  final b = linearize(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double contrastRatio(Color c1, Color c2) {
  final l1 = relativeLuminance(c1);
  final l2 = relativeLuminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG Contrast Ratios', () {
    test('Emergency gradient colors contrast >= 4.5:1 with white text', () {
      const white = Colors.white;
      const gradientStart = Color(0xFFC7382E);
      const gradientEnd = Color(0xFFB52B4D);

      final ratioStart = contrastRatio(white, gradientStart);
      final ratioEnd = contrastRatio(white, gradientEnd);

      expect(ratioStart, greaterThanOrEqualTo(4.5));
      expect(ratioEnd, greaterThanOrEqualTo(4.5));
    });

    test(
        'CPR counter circle fill contrasts >= 4.5:1 with white counter text in both themes',
        () {
      const white = Colors.white;
      // Light mode circle fills
      const cprLightStart = Color(0xFF14545E);
      const cprLightEnd = Color(0xFF1B6875);
      expect(contrastRatio(white, cprLightStart), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(white, cprLightEnd), greaterThanOrEqualTo(4.5));

      // Dark mode circle fills
      const cprDarkStart = Color(0xFF164E59);
      const cprDarkEnd = Color(0xFF1E6774);
      expect(contrastRatio(white, cprDarkStart), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(white, cprDarkEnd), greaterThanOrEqualTo(4.5));
    });

    test(
        'Guides and SOS call/blood chips contrast >= 4.5:1 in light and dark mode',
        () {
      // Light mode chip
      const chipTextLight = Color(0xFFB3362C);
      const chipBgLight = Color(0xFFFFEBE9);
      final ratioLight = contrastRatio(chipTextLight, chipBgLight);
      expect(ratioLight, greaterThanOrEqualTo(4.5));

      // Dark mode chip
      const chipTextDark = Color(0xFFFFB4AB);
      const chipBgDark = Color(0xFF410E0B);
      final ratioDark = contrastRatio(chipTextDark, chipBgDark);
      expect(ratioDark, greaterThanOrEqualTo(4.5));
    });

    test('Light theme tokens meet WCAG requirements against light surface', () {
      final lightTheme = AppTheme.lightTheme;
      final glass = lightTheme.extension<CarePulseGlass>()!;
      final surface = lightTheme.colorScheme.surface;

      // Normal text >= 4.5:1
      expect(
          contrastRatio(glass.textPrimary, surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(glass.textSecondary, surface),
          greaterThanOrEqualTo(4.5));

      // Icons and large elements >= 3:1
      expect(
          contrastRatio(glass.accentMint, surface), greaterThanOrEqualTo(3.0));
    });

    test('Dark theme tokens meet WCAG requirements against dark surface', () {
      final darkTheme = AppTheme.darkTheme;
      final glass = darkTheme.extension<CarePulseGlass>()!;
      final surface = darkTheme.colorScheme.surface;

      // Normal text >= 4.5:1
      expect(
          contrastRatio(glass.textPrimary, surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(glass.textSecondary, surface),
          greaterThanOrEqualTo(4.5));

      // Icons and large elements >= 3:1
      expect(
          contrastRatio(glass.accentMint, surface), greaterThanOrEqualTo(3.0));
    });

    test('Settings sheet surface is solid and tokens have >= 4.5:1 contrast',
        () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final surface = theme.colorScheme.surface;
        // Surface must be 100% opaque (alpha 255)
        expect((surface.a * 255.0).round(), equals(255));

        final onSurface = theme.colorScheme.onSurface;
        final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

        expect(contrastRatio(onSurface, surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5));
      }
    });
  });
}
