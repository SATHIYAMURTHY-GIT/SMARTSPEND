import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class ThemePreferenceService {
  ThemePreferenceService({this.customFilePath});

  final String? customFilePath;
  static const String _fileName = 'smartspend_theme_preference.txt';

  Future<File?> _getFile() async {
    if (customFilePath != null) {
      return File(customFilePath!);
    }
    try {
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/$_fileName');
    } catch (_) {
      return null;
    }
  }

  Future<ThemeMode> loadThemeMode() async {
    try {
      final file = await _getFile();
      if (file == null || !await file.exists()) {
        return ThemeMode.system;
      }
      final content = (await file.readAsString()).trim().toLowerCase();
      switch (content) {
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        case 'system':
        default:
          return ThemeMode.system;
      }
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    try {
      final file = await _getFile();
      if (file == null) return;
      await file.writeAsString(mode.name);
    } catch (_) {
      // Gracefully ignore file write errors in test or restricted environments.
    }
  }
}
