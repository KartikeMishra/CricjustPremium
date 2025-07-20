import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // Force light mode by default instead of following the system:
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
