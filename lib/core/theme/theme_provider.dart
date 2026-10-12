import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.light);

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final initialMode = ref.watch(initialThemeModeProvider);
  return ThemeModeNotifier(initialMode);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier([super.initial = ThemeMode.light]) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'dark' && state != ThemeMode.dark) {
        state = ThemeMode.dark;
      } else if (saved == 'light' && state != ThemeMode.light) {
        state = ThemeMode.light;
      }
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(next);
  }
}
