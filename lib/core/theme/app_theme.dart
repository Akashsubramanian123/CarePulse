import 'package:flutter/material.dart';

class AppColors {
  // Light Neumorphic / Glassmorphic Theme
  static const Color lightBackground = Color(0xFFF7F9FA); // Very soft cool white
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceCard = Color(0xFFFFFFFF);
  static const Color lightSurfaceBorder = Color(0xFFE2E8F0); // Subtle gray border

  // Medical Primaries
  static const Color tealPrimary = Color(0xFF00A69C);     // Bright Healthcare Teal
  static const Color tealAccent = Color(0xFF4DD0C8);      // Soft Mint Accent
  static const Color tealLight = Color(0xFFE6F6F5);       // Very light teal for chips/backgrounds

  // Warm Accents (Peach/Coral)
  static const Color peachAccent = Color(0xFFFF9E80);     // Warm peach gradient color
  static const Color coralEmergency = Color(0xFFFF6B6B);  // Bright Red/Coral for emergencies
  
  // Status Colors
  static const Color safeGreen = Color(0xFF00C48C);       // Bright vivid green
  static const Color warningAmber = Color(0xFFFFC107);

  // Typography
  static const Color textPrimary = Color(0xFF1E293B);     // Deep Slate
  static const Color textSecondary = Color(0xFF64748B);   // Muted Slate
  static const Color textMuted = Color(0xFF94A3B8);       // Light Slate

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE6F6F5), // Light mint
      Color(0xFFFFF0E6), // Light peach
    ],
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealPrimary,
        secondary: AppColors.tealAccent,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.coralEmergency,
      ),
      fontFamily: 'Inter', // Assuming we switch to a modern sans like Inter or Roboto
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurfaceCard.withValues(alpha: 0.9), // Slight glass effect
        elevation: 8,
        shadowColor: const Color(0x1A000000), // Soft shadow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.lightSurfaceBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.lightSurfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.lightSurfaceBorder),
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
          shadowColor: AppColors.tealPrimary.withValues(alpha: 0.3),
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

