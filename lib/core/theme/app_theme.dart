import 'package:flutter/material.dart';

class AppColors {
  // Calm Backgrounds (Eliminate pure black #000000 and harsh blue-black #0B0F19)
  static const Color darkBackground = Color(0xFF121A22); // Deep calm blue-gray
  static const Color darkSurface = Color(0xFF1B242D);    // Soft elevated surface
  static const Color darkSurfaceCard = Color(0xFF242F3A);// Card surface
  static const Color darkSurfaceBorder = Color(0xFF334250);// Low-contrast borders

  static const Color lightBackground = Color(0xFFF7F5F2);// Warm off-white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceBorder = Color(0xFFE2DDD5);

  // Calming Medical Primaries
  static const Color tealPrimary = Color(0xFF2F8F9D);     // Soft healthcare teal
  static const Color tealAccent = Color(0xFF3EA3B3);      // Calming interaction accent
  static const Color tealLight = Color(0xFF72C2CE);       // Gentle highlight
  static const Color tealGlow = Color(0x262F8F9D);        // Soft teal ambient aura

  // Emergency & Alert Colors (Reserved STRICTLY for SOS and immediate harm actions)
  static const Color coralEmergency = Color(0xFFE05A4F);  // Muted coral-red (less alarming than neon crimson)
  static const Color coralGlow = Color(0x26E05A4F);
  
  // Status Colors
  static const Color safeGreen = Color(0xFF6BAA8E);       // Sage green for Offline / Safe
  static const Color warningAmber = Color(0xFFE8B04B);    // Soft warm amber

  // High-Legibility Typography Colors
  static const Color textPrimary = Color(0xFFE6EDF3);     // Soft white on dark
  static const Color textSecondary = Color(0xFF9AA7B4);   // Subdued secondary text
  static const Color textMuted = Color(0xFF637381);       // Hints and labels
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.tealPrimary,
        secondary: AppColors.tealAccent,
        surface: AppColors.darkSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.coralEmergency,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurfaceCard,
        elevation: 0,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.darkSurfaceBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.darkSurfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.tealAccent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.tealPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: const Color(0x1A000000),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent, // Transparent for gradient
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealPrimary,
        secondary: AppColors.tealAccent,
        surface: Colors.white70,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1B242D),
        error: AppColors.coralEmergency,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1B242D),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: Color(0xFF1B242D)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.4),
        elevation: 0,
        shadowColor: const Color(0x1A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Colors.white, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.5),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.tealAccent, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.tealPrimary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.tealPrimary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

