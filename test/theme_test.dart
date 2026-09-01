import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/providers/theme_provider.dart';
import 'package:smartspend/screens/profile/profile_screen.dart';
import 'package:smartspend/services/theme_preference_service.dart';
import 'package:smartspend/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme configurations', () {
    test('Light theme creates valid ThemeData with light brightness', () {
      final theme = AppTheme.light;
      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, const Color(0xFF5E2BBF));
    });

    test('Dark theme creates valid ThemeData with dark brightness and purple brand scheme', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.colorScheme.primary, const Color(0xFFCFB5FF));
      expect(theme.colorScheme.surface, const Color(0xFF15102E));
    });
  });

  group('Theme preferences persistence', () {
    late Directory tempDir;
    late String tempFilePath;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('smartspend_theme_test');
      tempFilePath = '${tempDir.path}/theme_test.txt';
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('defaults to ThemeMode.system when no saved file exists', () async {
      final service = ThemePreferenceService(customFilePath: tempFilePath);
      final mode = await service.loadThemeMode();
      expect(mode, ThemeMode.system);
    });

    test('saves and loads ThemeMode.light correctly', () async {
      final service = ThemePreferenceService(customFilePath: tempFilePath);
      await service.saveThemeMode(ThemeMode.light);
      final loaded = await service.loadThemeMode();
      expect(loaded, ThemeMode.light);
    });

    test('saves and loads ThemeMode.dark correctly', () async {
      final service = ThemePreferenceService(customFilePath: tempFilePath);
      await service.saveThemeMode(ThemeMode.dark);
      final loaded = await service.loadThemeMode();
      expect(loaded, ThemeMode.dark);
    });

    test('saves and loads ThemeMode.system correctly', () async {
      final service = ThemePreferenceService(customFilePath: tempFilePath);
      await service.saveThemeMode(ThemeMode.system);
      final loaded = await service.loadThemeMode();
      expect(loaded, ThemeMode.system);
    });
  });

  group('ThemeModeNotifier dynamic switching without restart', () {
    test('switching ThemeMode updates state immediately across all modes', () async {
      final container = ProviderContainer(
        overrides: [
          themePreferenceServiceProvider.overrideWithValue(
            ThemePreferenceService(customFilePath: '${Directory.systemTemp.path}/dummy_theme.txt'),
          ),
        ],
      );

      // Initial mode is system
      expect(container.read(themeModeProvider), ThemeMode.system);

      // Switch to light mode
      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.light);
      expect(container.read(themeModeProvider), ThemeMode.light);

      // Switch to dark mode
      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      // Switch back to system mode
      await container.read(themeModeProvider.notifier).setThemeMode(ThemeMode.system);
      expect(container.read(themeModeProvider), ThemeMode.system);

      container.dispose();
    });
  });

  group('ProfileScreen Appearance UI', () {
    testWidgets('renders theme options (System, Light, Dark) and toggles mode without restart', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Tap 'Dark' segment
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode active'), findsOneWidget);

      // Tap 'Light' segment
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(find.text('Light mode active'), findsOneWidget);

      // Tap 'System' segment
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(find.text('Follows your device theme'), findsOneWidget);
    });
  });
}
