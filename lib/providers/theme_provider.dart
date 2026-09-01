import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/theme_preference_service.dart';

final themePreferenceServiceProvider = Provider<ThemePreferenceService>((ref) {
  return ThemePreferenceService();
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  bool _userExplicitlySet = false;

  @override
  ThemeMode build() {
    _loadInitialTheme();
    return ThemeMode.system;
  }

  Future<void> _loadInitialTheme() async {
    final service = ref.read(themePreferenceServiceProvider);
    final savedMode = await service.loadThemeMode();
    if (!_userExplicitlySet) {
      state = savedMode;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _userExplicitlySet = true;
    if (state == mode) return;
    state = mode;
    final service = ref.read(themePreferenceServiceProvider);
    await service.saveThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

