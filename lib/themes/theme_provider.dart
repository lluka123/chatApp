import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeData get themeData {
    return _isDarkMode ? _darkTheme : _lightTheme;
  }

  // Modern light theme with blue accents
  final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1E88E5),       // Bright blue
      onPrimary: Colors.white,
      secondary: Color(0xFFE3F2FD),     // Light blue background
      tertiary: Color(0xFFBBDEFB),      // Lighter blue for borders
      surface: Colors.white,
      error: Colors.redAccent,
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF1E88E5),
      iconTheme: IconThemeData(color: Color(0xFF1E88E5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: const Color(0xFFE3F2FD),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E88E5)),
      bodyLarge: TextStyle(color: Color(0xFF424242)),
    ),
  );

  // Modern dark theme with blue accents
  final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF64B5F6),       // Lighter blue for dark mode
      onPrimary: Colors.black,
      secondary: Color(0xFF1A2639),     // Dark blue background
      tertiary: Color(0xFF0D47A1),      // Darker blue for borders
      surface: Color(0xFF121212),
      background: Color(0xFF121212),
      error: Colors.redAccent,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: true,
      backgroundColor: Color(0xFF121212),
      foregroundColor: Color(0xFF64B5F6),
      iconTheme: IconThemeData(color: Color(0xFF64B5F6)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: const Color(0xFF1A2639),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64B5F6)),
      bodyLarge: TextStyle(color: Color(0xFFE0E0E0)),
    ),
  );

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}
