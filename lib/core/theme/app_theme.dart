import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  AppTheme._();

  // Monochrome palette (Light)
  static const Color black = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFE8E8E8);
  static const Color grey400 = Color(0xFFAAAAAA);
  static const Color grey600 = Color(0xFF666666);
  static const Color grey800 = Color(0xFF333333);

  // Monochrome palette (Dark)
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkSurface = Color(0xFF141414);
  static const Color darkCard = Color(0xFF161616);
  static const Color darkBorder = Color(0xFF262626);
  static const Color darkBorderStrong = Color(0xFF383838);
  static const Color darkGrey100 = Color(0xFF1C1C1E);
  static const Color darkGrey200 = Color(0xFF2C2C2E);
  static const Color darkTextMuted = Color(0xFF71717A);
  static const Color darkTextSecondary = Color(0xFFA1A1AA);

  // Semantic
  static const Color incomeColor = Color(0xFF0A0A0A);
  static const Color expenseColor = Color(0xFF666666);

  static const SystemUiOverlayStyle systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  static const SystemUiOverlayStyle darkSystemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: darkBg,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  );

  // Context-aware color getters
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) =>
      isDark(context) ? darkBg : white;

  static Color cardBg(BuildContext context) =>
      isDark(context) ? darkCard : white;

  static Color surface(BuildContext context) =>
      isDark(context) ? darkSurface : white;

  static Color border(BuildContext context) =>
      isDark(context) ? darkBorder : grey200;

  static Color borderStrong(BuildContext context) =>
      isDark(context) ? darkBorderStrong : black;

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? white : black;

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : grey600;

  static Color textMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : grey400;

  static Color subtleBg(BuildContext context) =>
      isDark(context) ? darkGrey100 : grey100;

  static Color chipBg(BuildContext context) =>
      isDark(context) ? darkGrey100 : grey100;

  static Color inputBg(BuildContext context) =>
      isDark(context) ? darkGrey100 : grey100;

  static Color primaryButtonBg(BuildContext context) =>
      isDark(context) ? white : black;

  static Color primaryButtonText(BuildContext context) =>
      isDark(context) ? black : white;

  static Color secondaryButtonBg(BuildContext context) =>
      isDark(context) ? darkGrey100 : grey100;

  static Color secondaryButtonText(BuildContext context) =>
      isDark(context) ? white : black;

  static Color error(BuildContext context) =>
      const Color(0xFFE53935);

  static SystemUiOverlayStyle currentSystemUiStyle(BuildContext context) =>
      isDark(context) ? darkSystemUiStyle : systemUiStyle;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: black,
        onPrimary: white,
        secondary: grey800,
        onSecondary: white,
        error: black,
        onError: white,
        surface: white,
        onSurface: black,
      ),
      scaffoldBackgroundColor: white,
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: grey200),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: systemUiStyle,
        iconTheme: IconThemeData(color: black),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: black,
          letterSpacing: -0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: grey200,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: black, width: 1.5),
        ),
        hintStyle: const TextStyle(color: grey400),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: black,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: black,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: white,
        onPrimary: black,
        secondary: darkTextSecondary,
        onSecondary: black,
        error: white,
        onError: black,
        surface: darkSurface,
        onSurface: white,
      ),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: darkSystemUiStyle,
        iconTheme: IconThemeData(color: white),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: white,
          letterSpacing: -0.5,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: darkBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkGrey100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: white, width: 1.5),
        ),
        hintStyle: const TextStyle(color: darkTextMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: white,
          foregroundColor: black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: white,
        ),
      ),
    );
  }
}
