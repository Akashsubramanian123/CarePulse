import 'package:flutter/material.dart';

class CarePulseGlass extends ThemeExtension<CarePulseGlass> {
  final LinearGradient backgroundGradient;
  final Color glowTopLeftColor;
  final Color glowBottomRightColor;
  final LinearGradient glassFillGradient;
  final Color glassBorderColor;
  final Color innerHighlightColor;
  final Color shadowColor;
  final Color textPrimary;
  final Color textSecondary;
  final Color accentMint;
  final LinearGradient iconTintGradient;
  final Color successDot;
  final LinearGradient emergencyGradient;
  final LinearGradient primaryActionGradient;

  const CarePulseGlass({
    required this.backgroundGradient,
    required this.glowTopLeftColor,
    required this.glowBottomRightColor,
    required this.glassFillGradient,
    required this.glassBorderColor,
    required this.innerHighlightColor,
    required this.shadowColor,
    required this.textPrimary,
    required this.textSecondary,
    required this.accentMint,
    required this.iconTintGradient,
    required this.successDot,
    required this.emergencyGradient,
    required this.primaryActionGradient,
  });

  @override
  ThemeExtension<CarePulseGlass> copyWith({
    LinearGradient? backgroundGradient,
    Color? glowTopLeftColor,
    Color? glowBottomRightColor,
    LinearGradient? glassFillGradient,
    Color? glassBorderColor,
    Color? innerHighlightColor,
    Color? shadowColor,
    Color? textPrimary,
    Color? textSecondary,
    Color? accentMint,
    LinearGradient? iconTintGradient,
    Color? successDot,
    LinearGradient? emergencyGradient,
    LinearGradient? primaryActionGradient,
  }) {
    return CarePulseGlass(
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      glowTopLeftColor: glowTopLeftColor ?? this.glowTopLeftColor,
      glowBottomRightColor: glowBottomRightColor ?? this.glowBottomRightColor,
      glassFillGradient: glassFillGradient ?? this.glassFillGradient,
      glassBorderColor: glassBorderColor ?? this.glassBorderColor,
      innerHighlightColor: innerHighlightColor ?? this.innerHighlightColor,
      shadowColor: shadowColor ?? this.shadowColor,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      accentMint: accentMint ?? this.accentMint,
      iconTintGradient: iconTintGradient ?? this.iconTintGradient,
      successDot: successDot ?? this.successDot,
      emergencyGradient: emergencyGradient ?? this.emergencyGradient,
      primaryActionGradient: primaryActionGradient ?? this.primaryActionGradient,
    );
  }

  @override
  ThemeExtension<CarePulseGlass> lerp(covariant ThemeExtension<CarePulseGlass>? other, double t) {
    if (other is! CarePulseGlass) {
      return this;
    }
    return CarePulseGlass(
      backgroundGradient: LinearGradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
      glowTopLeftColor: Color.lerp(glowTopLeftColor, other.glowTopLeftColor, t)!,
      glowBottomRightColor: Color.lerp(glowBottomRightColor, other.glowBottomRightColor, t)!,
      glassFillGradient: LinearGradient.lerp(glassFillGradient, other.glassFillGradient, t)!,
      glassBorderColor: Color.lerp(glassBorderColor, other.glassBorderColor, t)!,
      innerHighlightColor: Color.lerp(innerHighlightColor, other.innerHighlightColor, t)!,
      shadowColor: Color.lerp(shadowColor, other.shadowColor, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      accentMint: Color.lerp(accentMint, other.accentMint, t)!,
      iconTintGradient: LinearGradient.lerp(iconTintGradient, other.iconTintGradient, t)!,
      successDot: Color.lerp(successDot, other.successDot, t)!,
      emergencyGradient: LinearGradient.lerp(emergencyGradient, other.emergencyGradient, t)!,
      primaryActionGradient: LinearGradient.lerp(primaryActionGradient, other.primaryActionGradient, t)!,
    );
  }
}

class AppTheme {
  static final _emergencyGradient = const LinearGradient(
    colors: [Color(0xFFE05A4F), Color(0xFFD4476A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final CarePulseGlass _darkGlass = CarePulseGlass(
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFF0B1E2B), Color(0xFF0F3D4A), Color(0xFF2A2158)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(160 * 3.14159 / 180),
    ),
    glowTopLeftColor: const Color.fromRGBO(79, 179, 191, 0.55),
    glowBottomRightColor: const Color.fromRGBO(239, 123, 112, 0.40),
    glassFillGradient: LinearGradient(
      colors: [Colors.white.withOpacity(0.20), Colors.white.withOpacity(0.06)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassBorderColor: Colors.white.withOpacity(0.22),
    innerHighlightColor: Colors.white.withOpacity(0.30),
    shadowColor: Colors.black.withOpacity(0.25),
    textPrimary: const Color(0xFFF1F7FA),
    textSecondary: Colors.white.withOpacity(0.72),
    accentMint: const Color(0xFF9FF0E3),
    iconTintGradient: const LinearGradient(
      colors: [Color.fromRGBO(94, 234, 212, 0.45), Color.fromRGBO(79, 179, 191, 0.18)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    successDot: const Color(0xFF7FE3B0),
    emergencyGradient: _emergencyGradient,
    primaryActionGradient: const LinearGradient(
      colors: [Color(0xFF2FB5C4), Color(0xFF5B6CE0)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static final CarePulseGlass _lightGlass = CarePulseGlass(
    backgroundGradient: const LinearGradient(
      colors: [Color(0xFFE4F5F3), Color(0xFFE9E7FA), Color(0xFFFBE9E3)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      transform: GradientRotation(160 * 3.14159 / 180),
    ),
    glowTopLeftColor: const Color.fromRGBO(94, 200, 205, 0.55),
    glowBottomRightColor: const Color.fromRGBO(251, 170, 150, 0.50),
    glassFillGradient: LinearGradient(
      colors: [Colors.white.withOpacity(0.78), Colors.white.withOpacity(0.42)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    glassBorderColor: Colors.white.withOpacity(0.90),
    innerHighlightColor: Colors.white.withOpacity(0.95),
    shadowColor: const Color.fromRGBO(31, 41, 51, 0.10),
    textPrimary: const Color(0xFF1F2933),
    textSecondary: const Color(0xFF52606D),
    accentMint: const Color(0xFF1F7480),
    iconTintGradient: const LinearGradient(
      colors: [Color.fromRGBO(47, 143, 157, 0.30), Color.fromRGBO(79, 179, 191, 0.12)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    successDot: const Color(0xFF4FAE86),
    emergencyGradient: _emergencyGradient,
    primaryActionGradient: const LinearGradient(
      colors: [Color(0xFF1F7480), Color(0xFF4F5FC9)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: Colors.transparent, // Background handled by GradientBackground
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF2FB5C4),
        onPrimary: Colors.white,
        surface: Colors.transparent,
        onSurface: _darkGlass.textPrimary,
        error: const Color(0xFFE05A4F),
      ),
      extensions: [_darkGlass],
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        primary: const Color(0xFF1F7480),
        onPrimary: Colors.white,
        surface: Colors.transparent,
        onSurface: _lightGlass.textPrimary,
        error: const Color(0xFFE05A4F),
      ),
      extensions: [_lightGlass],
    );
  }
}

class AppColors {
  static const Color darkBackground = Color(0xFF121A22);
  static const Color darkSurface = Color(0xFF1B242D);
  static const Color darkSurfaceCard = Color(0xFF242F3A);
  static const Color darkSurfaceBorder = Color(0xFF334250);
  static const Color tealPrimary = Color(0xFF2F8F9D);
  static const Color tealAccent = Color(0xFF3EA3B3);
  static const Color tealGlow = Color(0x262F8F9D);
  static const Color coralEmergency = Color(0xFFE05A4F);
  static const Color safeGreen = Color(0xFF6BAA8E);
  static const Color warningAmber = Color(0xFFE8B04B);
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF9AA7B4);
  static const Color textMuted = Color(0xFF637381);
}
