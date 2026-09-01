import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/reports/reports_screen.dart';

void main() {
  group('Reports metrics', () {
    test('calculates debit and credit metrics without mixing totals', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
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
          userId: 'user-1',
          amount: 55000,
          type: ExpenseType.debit,
          category: 'Travel',
          merchant: 'Metro',
          description: 'Train',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        Expense(
          id: '3',
          userId: 'user-1',
          amount: 25000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Payday',
          date: DateTime(2026, 8, 1),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      ];

      final data = ReportsData.fromExpenses(
        expenses,
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31, 23, 59, 59, 999),
        ),
      );

      expect(data.totalDebitSpending, 90000);
      expect(data.totalCredits, 25000);
      expect(data.debitTransactionCount, 2);
      expect(data.creditTransactionCount, 1);
      expect(data.averageDebitAmount, 45000);
      expect(data.highestDebitAmount, 55000);
      expect(data.highestSpendingCategory, 'Travel');
      expect(data.categoryBreakdown.first.name, 'Travel');
      expect(data.categoryBreakdown.first.percentOfTotal, 61);
    });

    test('handles empty periods without fake stats', () {
      final data = ReportsData.fromExpenses(
        const <Expense>[],
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31, 23, 59, 59, 999),
        ),
      );

      expect(data.totalDebitSpending, 0);
      expect(data.totalCredits, 0);
      expect(data.debitTransactionCount, 0);
      expect(data.creditTransactionCount, 0);
      expect(data.averageDebitAmount, 0);
      expect(data.highestDebitAmount, 0);
      expect(data.highestSpendingCategory, isNull);
      expect(data.categoryBreakdown, isEmpty);
      expect(data.hasData, isFalse);
    });
  });
}
