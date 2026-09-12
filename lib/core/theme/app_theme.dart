import 'package:flutter/material.dart';

extension AppExtension on BuildContext {
  Color get primaryColor => Theme.of(this).colorScheme.primary;
  Color get secondaryColor => Theme.of(this).colorScheme.secondary;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get errorColor => Theme.of(this).colorScheme.error;
  TextTheme get textTheme => Theme.of(this).textTheme;
  ThemeData get theme => Theme.of(this);
}

class AppTheme {
  AppTheme._();

  // Grey colors for input decoration
  static const Color lightGrey300 = Color(0xFFE0E0E0);
  static const Color lightGrey400 = Color(0xFFB0B0B0);
  static const Color darkGrey300 = Color(0xFF4A4A4A);
  static const Color darkGrey400 = Color(0xFF757575);

  static ColorScheme lightColorScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF2E7D32),
    onPrimary: Colors.white,
    secondary: Color(0xFF1565C0),
    onSecondary: Colors.white,
    tertiary: Color(0xFF6A1B9A),
    onTertiary: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF212121),
    error: Color(0xFFCF6679),
    onError: Colors.white,
    secondaryContainer: Color(0xFFE3F2FD),
    onSecondaryContainer: Color(0xFF1565C0),
    tertiaryContainer: Color(0xFFE8C8E6),
    onTertiaryContainer: Color(0xFF6A1B9A),
    surfaceTint: Color(0xFF2E7D32),
  );

  static ColorScheme darkColorScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF2E7D32),
    onPrimary: Colors.white,
    secondary: Color(0xFF1565C0),
    onSecondary: Colors.white,
    tertiary: Color(0xFF6A1B9A),
    onTertiary: Colors.white,
    surface: Color(0xFF121212),
    onSurface: Color(0xFFE0E0E0),
    error: Color(0xFFCF6679),
    onError: Colors.white,
    secondaryContainer: Color(0xFF0D47A1),
    onSecondaryContainer: Color(0xFFBBDEFB),
    tertiaryContainer: Color(0xFF370036),
    onTertiaryContainer: Color(0xFFF48FB1),
    surfaceTint: Color(0xFF2E7D32),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lora',
    colorScheme: lightColorScheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF212121),
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: lightGrey400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightGrey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: lightGrey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
    ),
    textTheme: _lightTextTheme,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'Lora',
    colorScheme: darkColorScheme,
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: const TextStyle(color: darkGrey400),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkGrey300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkGrey300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
      ),
    ),
    textTheme: _darkTextTheme,
  );

  static const TextTheme _lightTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: 'Oswald',
      color: Color(0xFF212121),
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: 'Oswald',
      color: Color(0xFF666666),
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Color(0xFF212121),
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Color(0xFF212121),
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: Color(0xFF666666),
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
  );

  static const TextTheme _darkTextTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      fontFamily: 'Oswald',
      color: Colors.white,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      fontFamily: 'Oswald',
      color: darkGrey300,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      fontFamily: 'Oswald',
      color: darkGrey300,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: Colors.white,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: Colors.white70,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      color: darkGrey300,
    ),
    labelLarge: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: Colors.white,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: Colors.white70,
    ),
  );
}
