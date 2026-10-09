import 'package:flutter/material.dart';

class AppColors {
  // Light Gradient Backgrounds
  static const Color lightBackgroundStart = Color(0xFFE0F7FA); // Light Cyan
  static const Color lightBackgroundEnd = Color(0xFFF3E5F5);   // Light Purple

  // Glassmorphism Surface
  static const Color glassSurface = Color(0x99FFFFFF); // 60% White
  static const Color glassBorder = Color(0x33FFFFFF);  // 20% White for borders
  
  // Calming Medical Primaries
  static const Color tealPrimary = Color(0xFF00838F);     // Darker healthcare teal for light mode
  static const Color tealAccent = Color(0xFF00BCD4);      
  
  // Emergency & Alert Colors
  static const Color coralEmergency = Color(0xFFD32F2F);  
  
  // Status Colors
  static const Color safeGreen = Color(0xFF388E3C);       
  static const Color warningAmber = Color(0xFFF57C00);    

  // High-Legibility Typography Colors
  static const Color textPrimary = Color(0xFF263238);     // Dark blue-grey for text
  static const Color textSecondary = Color(0xFF546E7A);   
  static const Color textMuted = Color(0xFF78909C);       
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent, // Let gradient show through
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealPrimary,
        secondary: AppColors.tealAccent,
        surface: AppColors.glassSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        error: AppColors.coralEmergency,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.tealPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.glassSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorder, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0x40FFFFFF),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.glassBorder),
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

