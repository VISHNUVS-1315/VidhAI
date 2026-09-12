import 'package:flutter/material.dart';
import 'accent_color_controller.dart';

/// Centralized Fresh Leaf Design System (Dual Mode)
///
/// VidhAI - Empowering Farmers, Enriching Lives
///
/// LIGHT MODE: Background #EAF7EC, Primary #2E7D32, Secondary #C8E6C9, Accent #4CAF6C
/// DARK MODE: Background #0F1F14, Primary #4CAF6C, Secondary #1B5E3E, Accent #4CAF6C
///
/// Important: Do NOT make the entire UI green. Use green strategically for actions,
/// highlights and active states only.
class FreshLeafColors {
  FreshLeafColors._();

  // ============ LIGHT MODE COLORS ============

  // Background & Surface
  static const Color lightBackground = Color(0xFFEAF7EC); // Page background
  static const Color lightCard = Color(0xFFFFFFFF); // Cards
  static const Color lightSurface = Color(0xFFFEFEFE); // Elevated surfaces

  // Primary & Accent (Fresh Leaf Green - used strategically) - DEFAULT
  static const Color lightPrimary = Color(0xFF2E7D32); // Main CTA, selected nav
  static const Color lightAccent =
      Color(0xFF4CAF6C); // AI highlights, positive states
  static const Color lightSecondary =
      Color(0xFFC8E6C9); // Soft sections, alternate backgrounds

  // Text Colors
  static const Color lightPrimaryText = Color(0xFF1F2F23); // Primary text
  static const Color lightSecondaryText = Color(0xFF58705E); // Secondary text
  static const Color lightBorder = Color(0xFFD5E8D8); // Borders

  // Success/Status
  static const Color lightSuccess =
      Color(0xFF2E7D32); // Positive price movement

  static const Color danger =
      Color(0xFFEF4444); // Badge / destructive (backward compat)

  // ============ DARK MODE COLORS ============

  // Background & Surface
  static const Color darkBackground = Color(0xFF0F1F14); // Page background
  static const Color darkCard = Color(0xFF16291D); // Cards
  static const Color darkSurface = Color(0xFF1E2722); // Elevated surfaces

  // Primary & Accent (Fresh Leaf Green - used strategically) - DEFAULT
  static const Color darkPrimary = Color(0xFF4CAF6C); // Main CTA, selected nav
  static const Color darkAccent =
      Color(0xFF4CAF6C); // AI highlights, same as primary in dark
  static const Color darkSecondary = Color(0xFF1B5E3E); // Secondary sections

  // Text Colors
  static const Color darkPrimaryText = Color(0xFFF1F7F2); // Primary text
  static const Color darkSecondaryText = Color(0xFFA9BBAE); // Secondary text
  static const Color darkBorder = Color(0xFF294332); // Borders

  // Success/Status
  static const Color darkSuccess = Color(0xFF4CAF6C); // Positive price movement

  // ============ SEMANTIC COLORS ============

  // Common across both modes
  static const Color success = Color(0xFF4CAF6C); // Primary success color
  static const Color info = Color(0xFF1E88E5); // Info color
  static const Color warning = Color(0xFFFF8F00); // Warning color
  static const Color error = Color(0xFFCF6679); // Error color

  /// Returns the light primary color for the given accent option
  static Color lightPrimaryFor(AccentColorOption option) => option.lightPrimary;

  /// Returns the light accent color for the given accent option
  static Color lightAccentFor(AccentColorOption option) => option.lightAccent;

  /// Returns the dark primary color for the given accent option
  static Color darkPrimaryFor(AccentColorOption option) => option.darkPrimary;

  /// Returns the dark accent color for the given accent option
  static Color darkAccentFor(AccentColorOption option) => option.darkAccent;
}

/// [VidhAIColorsX] is deprecated, use [FreshLeafColorsX] instead.
/// This class is kept for backward compatibility with existing screen code.
@Deprecated('Use FreshLeafColorsX instead')
class VidhAIColorsX {
  VidhAIColorsX(this.context, [this.accentOption]);

  final BuildContext context;
  final AccentColorOption? accentOption;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ============ BRAND / PRIMARY ============

  Color get brand => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkPrimaryFor(accentOption!)
          : FreshLeafColors.darkPrimary)
      : (accentOption != null
          ? FreshLeafColors.lightPrimaryFor(accentOption!)
          : FreshLeafColors.lightPrimary);
  Color get brandStrong => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkAccentFor(accentOption!)
          : FreshLeafColors.darkAccent)
      : (accentOption != null
          ? FreshLeafColors.lightAccentFor(accentOption!)
          : FreshLeafColors.lightAccent);
  Color get brandDeep => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkPrimaryFor(accentOption!)
          : FreshLeafColors.darkPrimary)
      : (accentOption != null
          ? FreshLeafColors.lightPrimaryFor(accentOption!)
          : FreshLeafColors.lightPrimary);

  // ============ BACKGROUND / SURFACE ============

  Color get bg =>
      isDark ? FreshLeafColors.darkBackground : FreshLeafColors.lightBackground;
  Color get surface =>
      isDark ? FreshLeafColors.darkCard : FreshLeafColors.lightCard;
  Color get surfaceMuted =>
      isDark ? FreshLeafColors.darkSurface : FreshLeafColors.lightSurface;

  // ============ TEXT COLORS ============

  Color get onBackground => isDark
      ? FreshLeafColors.darkPrimaryText
      : FreshLeafColors.lightPrimaryText;
  Color get onSurfaceMuted => isDark
      ? FreshLeafColors.darkSecondaryText
      : FreshLeafColors.lightSecondaryText;
  Color get borderColor =>
      isDark ? FreshLeafColors.darkBorder : FreshLeafColors.lightBorder;

  // ============ SEMANTIC ============

  Color get success => FreshLeafColors.success;
  Color get info => FreshLeafColors.info;
  Color get warning => FreshLeafColors.warning;
  Color get error => FreshLeafColors.error;
  Color get danger => FreshLeafColors.error; // Backward compatibility
}

/// FreshLeaf colors accessor built from a BuildContext according to active mode.
class FreshLeafColorsX {
  FreshLeafColorsX(this.context, [this.accentOption]);

  final BuildContext context;
  final AccentColorOption? accentOption;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  // ============ BRAND / PRIMARY ============

  Color get brand => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkPrimaryFor(accentOption!)
          : FreshLeafColors.darkPrimary)
      : (accentOption != null
          ? FreshLeafColors.lightPrimaryFor(accentOption!)
          : FreshLeafColors.lightPrimary);
  Color get brandStrong => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkAccentFor(accentOption!)
          : FreshLeafColors.darkAccent)
      : (accentOption != null
          ? FreshLeafColors.lightAccentFor(accentOption!)
          : FreshLeafColors.lightAccent);
  Color get brandDeep => isDark
      ? (accentOption != null
          ? FreshLeafColors.darkPrimaryFor(accentOption!)
          : FreshLeafColors.darkPrimary)
      : (accentOption != null
          ? FreshLeafColors.lightPrimaryFor(accentOption!)
          : FreshLeafColors.lightPrimary);

  // ============ BACKGROUND / SURFACE ============

  Color get bg =>
      isDark ? FreshLeafColors.darkBackground : FreshLeafColors.lightBackground;
  Color get surface =>
      isDark ? FreshLeafColors.darkCard : FreshLeafColors.lightCard;
  Color get surfaceMuted =>
      isDark ? FreshLeafColors.darkSurface : FreshLeafColors.lightSurface;

  // ============ TEXT COLORS ============

  Color get onBackground => isDark
      ? FreshLeafColors.darkPrimaryText
      : FreshLeafColors.lightPrimaryText;
  Color get onSurfaceMuted => isDark
      ? FreshLeafColors.darkSecondaryText
      : FreshLeafColors.lightSecondaryText;
  Color get borderColor =>
      isDark ? FreshLeafColors.darkBorder : FreshLeafColors.lightBorder;

  // ============ SEMANTIC ============

  Color get success => FreshLeafColors.success;
  Color get info => FreshLeafColors.info;
  Color get warning => FreshLeafColors.warning;
  Color get error => FreshLeafColors.error;
}

/// Builds the FreshLeaf ColorScheme from the mode.
class FreshLeafTheme {
  FreshLeafTheme._();

  // ============ DESIGN TOKENS (backward compat with VidhAITheme) ============

  static const double radiusMd = 16;

  static const List<BoxShadow> softShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  /// Light color scheme following Fresh Leaf specification
  static ColorScheme _lightScheme(AccentColorOption option) {
    return ColorScheme(
      brightness: Brightness.light,
      primary: FreshLeafColors.lightPrimaryFor(option), // Main CTA
      onPrimary: FreshLeafColors.lightPrimaryText, // #1F2F23 - White on primary
      secondary: FreshLeafColors.lightSecondary, // #C8E6C9 - Soft sections
      onSecondary: FreshLeafColors.lightSecondaryText, // #58705E
      tertiary:
          FreshLeafColors.lightAccentFor(option), // #4CAF6C - AI highlights
      onTertiary: Colors.white,
      surface: FreshLeafColors.lightCard, // #FFFFFF - Cards
      onSurface: FreshLeafColors.lightPrimaryText, // #1F2F23 - Primary text
      error: FreshLeafColors.error, // Standard error
      onError: Colors.white,
      surfaceTint: FreshLeafColors.lightPrimaryFor(
          option), // Floating action button tint
    );
  }

  /// Dark color scheme following Fresh Leaf specification
  static ColorScheme _darkScheme(AccentColorOption option) {
    return ColorScheme(
      brightness: Brightness.dark,
      primary: FreshLeafColors.darkPrimaryFor(option), // #4CAF6C - Main CTA
      onPrimary: FreshLeafColors.darkPrimaryText, // #F1F7F2 - White on primary
      secondary: FreshLeafColors.darkSecondary, // #1B5E3E - Secondary sections
      onSecondary: FreshLeafColors.darkSecondaryText, // #A9BBAE
      tertiary:
          FreshLeafColors.darkAccentFor(option), // #4CAF6C - AI highlights
      onTertiary: Colors.white,
      surface: FreshLeafColors.darkCard, // #16291D - Cards
      onSurface: FreshLeafColors.darkPrimaryText, // #F1F7F2 - Primary text
      error: FreshLeafColors.error, // Standard error
      onError: Colors.white,
      surfaceTint:
          FreshLeafColors.darkPrimaryFor(option), // Floating action button tint
    );
  }

  /// Creates the Light ThemeData with Fresh Leaf colors
  static ThemeData lightTheme([AccentColorOption? option]) {
    final opt = option ?? AccentColorController.options[0];
    final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
    return base.copyWith(
      colorScheme: _lightScheme(opt),
      scaffoldBackgroundColor: FreshLeafColors.lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: FreshLeafColors.lightBackground,
        foregroundColor: FreshLeafColors.lightPrimaryText,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FreshLeafColors.lightPrimaryFor(opt), // CTA
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FreshLeafColors.lightPrimaryFor(opt),
          side: const BorderSide(color: FreshLeafColors.lightBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FreshLeafColors.lightSurface,
        hintStyle: const TextStyle(color: FreshLeafColors.lightSecondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FreshLeafColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FreshLeafColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: FreshLeafColors.lightPrimaryFor(opt), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      dividerColor: FreshLeafColors.lightBorder,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: FreshLeafColors.lightCard,
        selectedItemColor: FreshLeafColors.lightPrimaryFor(opt),
        unselectedItemColor: FreshLeafColors.lightSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  /// Creates the Dark ThemeData with Fresh Leaf colors
  static ThemeData darkTheme([AccentColorOption? option]) {
    final opt = option ?? AccentColorController.options[0];
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      colorScheme: _darkScheme(opt),
      scaffoldBackgroundColor: FreshLeafColors.darkBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: FreshLeafColors.darkBackground,
        foregroundColor: FreshLeafColors.darkPrimaryText,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: FreshLeafColors.darkPrimaryFor(opt),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: FreshLeafColors.darkPrimaryFor(opt),
          side: const BorderSide(color: FreshLeafColors.darkBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FreshLeafColors.darkSurface,
        hintStyle: const TextStyle(color: FreshLeafColors.darkSecondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FreshLeafColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FreshLeafColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: FreshLeafColors.darkPrimaryFor(opt), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      dividerColor: FreshLeafColors.darkBorder,
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: FreshLeafColors.darkCard,
        selectedItemColor: FreshLeafColors.darkPrimaryFor(opt),
        unselectedItemColor: FreshLeafColors.darkSecondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
