import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/budget.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/home/home_screen.dart';

void main() {
  group('Budget summary', () {
    test('reads a saved budget from Firestore payload and keeps minor-unit values intact', () {
      final budget = MonthlyBudget.fromFirestore(
        {
          'userId': 'user-123',
          'monthlyLimitMinorUnits': 125500,
          'updatedAt': DateTime(2026, 8, 20),
        },
        userId: 'user-123',
      );

      expect(budget.userId, 'user-123');
      expect(budget.monthlyLimitMinorUnits, 125500);
      expect(budget.updatedAt, isNotNull);
    });

    test('calculates remaining and status without floating point math', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 35000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 9),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 9),
          updatedAt: DateTime(2026, 8, 9),
        ),
        Expense(
          id: '2',
          userId: 'u',
          amount: 55000,
          type: ExpenseType.debit,
          category: 'Travel',
          merchant: 'Metro',
          description: 'Travel',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        Expense(
          id: '3',
          userId: 'u',
          amount: 25000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Salary',
          date: DateTime(2026, 8, 1),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];

      final summary = BudgetSummary.fromExpensesAndBudget(
        expenses,
        monthlyBudget: 100000,
        referenceTime: DateTime(2026, 8, 20),
      );

      expect(summary.monthlyBudget, 100000);
      expect(summary.currentMonthDebitTotal, 90000);
      expect(summary.remainingMinorUnits, 10000);
      expect(summary.isExceeded, isFalse);
      expect(summary.spentRatio, 0.9);
      expect(summary.statusLabel, 'Approaching limit');
    });

    test('flags a budget as exceeded when spending goes over the limit', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 150000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Restaurant',
          description: 'Dinner',
          date: DateTime(2026, 8, 3),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 3),
          updatedAt: DateTime(2026, 8, 3),
        ),
      ];

      final summary = BudgetSummary.fromExpensesAndBudget(
        expenses,
        monthlyBudget: 100000,
        referenceTime: DateTime(2026, 8, 20),
      );

      expect(summary.currentMonthDebitTotal, 150000);
      expect(summary.remainingMinorUnits, -50000);
      expect(summary.isExceeded, isTrue);
      expect(summary.statusLabel, 'Budget exceeded');
      expect(summary.spentRatio, 1.5);
    });
  });
}
