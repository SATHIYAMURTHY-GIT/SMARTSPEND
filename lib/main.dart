import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/authentication_provider.dart';
import 'providers/theme_provider.dart';
import 'routing/app_router.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/firebase_initializer.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeFirebase();
  runApp(const ProviderScope(child: SmartSpendApp()));
}

class SmartSpendApp extends ConsumerStatefulWidget {
  const SmartSpendApp({
    this.skipSplash = false,
    super.key,
  });

  final bool skipSplash;

  @override
  ConsumerState<SmartSpendApp> createState() => _SmartSpendAppState();
}

class _SmartSpendAppState extends ConsumerState<SmartSpendApp> {
  late bool _splashCompleted;

  @override
  void initState() {
    super.initState();
    _splashCompleted = widget.skipSplash;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'SmartSpend',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: appRouter,
      builder: (context, child) {
        if (!_splashCompleted) {
          return SplashScreen(
            onComplete: () {
              if (mounted) {
                setState(() => _splashCompleted = true);
              }
            },
          );
        }
        return AuthGate(child: child);
      },
    );
  }
}

class AuthGate extends ConsumerWidget {
  const AuthGate({required this.child, super.key});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const _AuthLoadingScreen(),
      error: (error, stackTrace) => const LoginScreen(),
      data: (user) => user == null ? const LoginScreen() : child!,
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
