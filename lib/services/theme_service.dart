import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const String _themePrefKey = 'app_theme';

  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  String _currentThemeName = 'Light Mode';
  String get currentThemeName => _currentThemeName;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentThemeName = prefs.getString(_themePrefKey) ?? 'Light Mode';
    themeModeNotifier.value = _themeModeFromName(_currentThemeName);
  }

  Future<void> setTheme(String themeName) async {
    _currentThemeName = themeName;
    themeModeNotifier.value = _themeModeFromName(themeName);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefKey, themeName);
  }

  ThemeMode _themeModeFromName(String name) {
    switch (name) {
      case 'Dark Mode':
        return ThemeMode.dark;
      case 'System Default':
        return ThemeMode.system;
      case 'Light Mode':
      default:
        return ThemeMode.light;
    }
  }

  static bool isDarkMode(BuildContext context) {
    final mode = themeModeNotifier.value;
    if (mode == ThemeMode.dark) return true;
    if (mode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }
}
