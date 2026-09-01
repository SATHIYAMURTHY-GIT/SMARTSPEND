import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/screens/splash/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SplashScreen Startup Animation', () {
    testWidgets('displays Company logo first, then SmartSpend logo, then completes', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(
            onComplete: () {
              completed = true;
            },
          ),
        ),
      );

      // Initial frame: Company logo is present and onComplete is not yet called
      expect(completed, isFalse);
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Advance through first half (Company logo animation)
      await tester.pump(const Duration(milliseconds: 600));
      expect(completed, isFalse);

      // Advance past transition point (1400ms -> SmartSpend logo animation)
      await tester.pump(const Duration(milliseconds: 900));
      expect(completed, isFalse);
      expect(find.byType(Image), findsOneWidget);

      // Advance to full completion (2700ms total)
      await tester.pump(const Duration(milliseconds: 1400));
      expect(completed, isTrue);
    });
  });
}
