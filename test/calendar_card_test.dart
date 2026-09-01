import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/home/calendar_card.dart';

void main() {
  group('CalendarCard', () {
    testWidgets('renders month title, weekdays, and days grid', (tester) async {
      final now = DateTime.now();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarCard(expenses: const []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text(DateFormat.yMMMM().format(now)), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.textContaining('No expenses on'), findsOneWidget);
    });

    testWidgets('navigates to next and previous month', (tester) async {
      final now = DateTime.now();
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final prevMonth = DateTime(now.year, now.month - 1, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarCard(expenses: const []),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap next month
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(find.text(DateFormat.yMMMM().format(nextMonth)), findsOneWidget);

      // Tap previous month twice to go to previous month
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(DateFormat.yMMMM().format(now)), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text(DateFormat.yMMMM().format(prevMonth)), findsOneWidget);
    });

    testWidgets('shows transactions for selected date and invokes callback', (tester) async {
      DateTime? selected;
      final today = DateTime.now();
      final sampleExpenses = [
        Expense(
          id: '1',
          userId: 'u1',
          amount: 50000,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'Amazon',
          description: 'Office stuff',
          date: today,
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: today,
          updatedAt: today,
        ),
        Expense(
          id: '2',
          userId: 'u1',
          amount: 150000,
          type: ExpenseType.credit,
          category: 'Salary',
          merchant: 'Employer',
          description: 'Monthly pay',
          date: today,
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: today,
          updatedAt: today,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CalendarCard(
                expenses: sampleExpenses,
                onDateSelected: (date) {
                  selected = date;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2 transactions on'), findsOneWidget);
      expect(find.text('Shopping'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('-₹500.00'), findsOneWidget);
      expect(find.text('+₹1500.00'), findsOneWidget);

      // Tap on day 1
      await tester.tap(find.text('1').first);
      await tester.pumpAndSettle();

      expect(selected, isNotNull);
      expect(selected!.day, 1);
    });
  });
}
