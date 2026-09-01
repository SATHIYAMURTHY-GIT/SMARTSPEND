import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartspend/main.dart';
import 'package:smartspend/screens/add_expense/add_expense_screen.dart';

void main() {
  testWidgets('shows the authentication screen when signed out', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: SmartSpendApp(skipSplash: true)),
    );
    await tester.pumpAndSettle();

    expect(find.text('SmartSpend'), findsOneWidget);
    expect(find.text('Manage your money smarter.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('add expense form uses a scroll-safe layout and a tappable date card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddExpenseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.text('Date'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('add expense form exposes UPI in the supported payment options', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddExpenseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(AddExpenseScreen.supportedPaymentMethods, contains('UPI'));
    expect(find.byType(DropdownButtonFormField<String>), findsWidgets);
  });

  testWidgets('add expense amount field displays Indian Rupee symbol', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AddExpenseScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.currency_rupee), findsOneWidget);
    expect(find.byIcon(Icons.attach_money), findsNothing);
  });
}
