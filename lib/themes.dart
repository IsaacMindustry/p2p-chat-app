import 'package:flutter/material.dart';

class AppThemes {
  static final darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF121212),
    primaryColor: Colors.blueAccent,
    colorScheme: const ColorScheme.dark(
      primary: Colors.blueAccent,
    ),
  );

  static final midnightTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF0A0E21),
    primaryColor: Colors.purpleAccent,
    colorScheme: const ColorScheme.dark(
      primary: Colors.purpleAccent,
    ),
  );

  static final lightTheme = ThemeData.light().copyWith(
    primaryColor: Colors.blue,
    colorScheme: const ColorScheme.light(
      primary: Colors.blue,
    ),
  );
}