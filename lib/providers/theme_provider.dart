import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/settings_repository.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _settingsRepo = SettingsRepository();

  ThemeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final mode = await _settingsRepo.getThemeMode();
    if (mode == 'dark') {
      state = ThemeMode.dark;
    } else if (mode == 'light') {
      state = ThemeMode.light;
    } else {
      state = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String modeStr = 'light';
    if (mode == ThemeMode.dark) {
      modeStr = 'dark';
    } else if (mode == ThemeMode.system) {
      modeStr = 'system';
    }
    await _settingsRepo.saveThemeMode(modeStr);
  }

  void toggleTheme() {
    if (state == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else {
      setThemeMode(ThemeMode.dark);
    }
  }
}
