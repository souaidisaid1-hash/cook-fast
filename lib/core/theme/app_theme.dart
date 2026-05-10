import 'package:flutter/material.dart';

class AppColors {
  // Primary — chaud, appétissant
  static const primary = Color(0xFFFF6B35);
  static const primaryLight = Color(0xFFFF8F66);
  static const primaryDark = Color(0xFFE5501A);

  // Accents
  static const green = Color(0xFF4CAF7D);
  static const blue = Color(0xFF4A90D9);
  static const purple = Color(0xFF9B59B6);
  static const yellow = Color(0xFFF5A623);

  // Dark mode
  static const darkBg = Color(0xFF0F0F0F);
  static const darkSurface = Color(0xFF1A1A1A);
  static const darkCard = Color(0xFF242424);
  static const darkBorder = Color(0xFF2E2E2E);

  // Light mode
  static const lightBg = Color(0xFFF8F6F3);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFEEEEEE);

  // Text
  static const textDark = Color(0xFFF5F5F5);
  static const textDarkSecondary = Color(0xFF9E9E9E);
  static const textLight = Color(0xFF1A1A1A);
  static const textLightSecondary = Color(0xFF757575);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.darkSurface,
          onSurface: AppColors.textDark,
        ),
        cardColor: AppColors.darkCard,
        dividerColor: AppColors.darkBorder,
        fontFamily: 'SF Pro Display',
        textTheme: _textTheme(AppColors.textDark, AppColors.textDarkSecondary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.darkBg,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.darkSurface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textDarkSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          hintStyle: const TextStyle(color: AppColors.textDarkSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        useMaterial3: true,
      );

  static ThemeData get light => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.lightSurface,
          onSurface: AppColors.textLight,
        ),
        cardColor: AppColors.lightCard,
        dividerColor: AppColors.lightBorder,
        fontFamily: 'SF Pro Display',
        textTheme: _textTheme(AppColors.textLight, AppColors.textLightSecondary),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.lightBg,
          foregroundColor: AppColors.textLight,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.lightSurface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textLightSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.lightCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lightBorder),
          ),
          hintStyle: const TextStyle(color: AppColors.textLightSecondary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        useMaterial3: true,
      );

  static TextTheme _textTheme(Color primary, Color secondary) => TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: primary),
        displayMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: primary),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: primary),
        headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: primary),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primary),
        bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: primary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondary),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      );
}
