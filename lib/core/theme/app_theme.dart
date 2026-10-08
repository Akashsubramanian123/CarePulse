import 'package:flutter/material.dart';

class AppColors {
  // Light Glassmorphic Backgrounds
  static const Color lightBackground = Color(0xFFE8F1F5); // Soft teal-tinted white
  static const Color lightSurface = Color(0x99FFFFFF);    // Semi-transparent white for glass
  static const Color lightSurfaceCard = Color(0xB3FFFFFF);// Slightly more opaque for cards
  static const Color lightSurfaceBorder = Color(0x33000000); // Soft border for glass

  // Calming Medical Primaries
  static const Color tealPrimary = Color(0xFF2CB1BA);     // Vibrant yet calming teal
  static const Color tealAccent = Color(0xFF4ACFD8);      
  static const Color tealLight = Color(0xFFB5E8EB);       
  static const Color peachGradientEnd = Color(0xFFFFCFA8); // Peach/Coral gradient end

  // Emergency & Alert Colors
  static const Color coralEmergency = Color(0xFFFF6B6B);  // Soft vibrant coral
  
  // Status Colors
  static const Color safeGreen = Color(0xFF38B27A);       
  static const Color warningAmber = Color(0xFFF9B234);    

  // Typography Colors
  static const Color textPrimary = Color(0xFF1E293B);     // Dark slate blue
  static const Color textSecondary = Color(0xFF475569);   
  static const Color textMuted = Color(0xFF94A3B8);       

  // Legacy variables to not break existing code entirely
  static const Color darkBackground = lightBackground;
  static const Color darkSurface = lightSurface;
  static const Color darkSurfaceCard = lightSurfaceCard;
  static const Color darkSurfaceBorder = lightSurfaceBorder;
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent, // We will use a gradient background in Scaffold
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealPrimary,
        secondary: AppColors.tealAccent,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.coralEmergency,
      ),
      fontFamily: 'Outfit', // Or any modern font, assuming Roboto is default
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
        color: AppColors.lightSurfaceCard,
        elevation: 0,
        shadowColor: const Color(0x1A000000),
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
          elevation: 8,
          shadowColor: AppColors.tealPrimary.withOpacity(0.4),
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

