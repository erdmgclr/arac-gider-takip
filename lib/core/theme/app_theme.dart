import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color lightBackground = Color(0xFFF3F6FA);
  static const Color darkBackground = Color(0xFF000000);

  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color darkCard = Color(0xFF0D0D0D);

  static const Color lightBorder = Color(0xFFE3E7ED);
  static const Color darkBorder = Color(0xFF242424);

  static const Color lightPrimary = Color(0xFF1565C0);
  static const Color darkPrimary = Color(0xFF4A90FF);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: lightPrimary,
      brightness: Brightness.light,
      surface: lightCard,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightBackground,
      cardColor: lightCard,
      dividerColor: lightBorder,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightCard,
        indicatorColor: colorScheme.primaryContainer,
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: lightCard,
        elevation: 12,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightPrimary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: darkPrimary,
      brightness: Brightness.dark,
      surface: darkCard,
    ).copyWith(surface: darkCard, onSurface: Colors.white, outline: darkBorder);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkBorder,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkBackground,
        indicatorColor: darkPrimary.withValues(alpha: 0.18),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: darkBackground,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF101010),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkPrimary, width: 1.5),
        ),
      ),
    );
  }
}
