import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void useSystemTheme() {
    _themeMode = ThemeMode.system;
    notifyListeners();
  }

  void useLightTheme() {
    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  void useDarkTheme() {
    _themeMode = ThemeMode.dark;
    notifyListeners();
  }

  void toggleTheme(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    if (brightness == Brightness.dark) {
      useLightTheme();
    } else {
      useDarkTheme();
    }
  }
}

final ThemeController themeController = ThemeController();
