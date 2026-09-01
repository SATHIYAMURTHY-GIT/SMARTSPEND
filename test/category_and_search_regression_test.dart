import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/core/utils/formatters.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/expenses/expenses_screen.dart';
import 'package:smartspend/services/expense_export_service.dart';

void main() {
  group('category management', () {
    test('deduplicates existing categories using normalized names', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 1500,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'Store',
          description: 'Groceries',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 2200,
          type: ExpenseType.debit,
          category: ' shopping ',
          merchant: 'Another',
          description: 'Office',
          date: DateTime(2026, 8, 11),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 11),
          updatedAt: DateTime(2026, 8, 11),
        ),
        Expense(
          id: '3',
          userId: 'user-1',
          amount: 900,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 12),
          paymentMethod: 'Cash',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 12),
          updatedAt: DateTime(2026, 8, 12),
        ),
      ];

      expect(
        deriveAvailableCategories(expenses.map((expense) => expense.category)),
        ['Food', 'Shopping'],
      );
    });

    test('uses the existing canonical category when a normalized duplicate is entered', () {
      final categories = ['Shopping', 'Food'];

      expect(resolveCategorySelection(' shopping ', categories), 'Shopping');
      expect(resolveCategorySelection('SHOPPING', categories), 'Shopping');
      expect(resolveCategorySelection('Entertainment', categories), 'Entertainment');
    });
  });

  group('search and filtering', () {
    test('searches merchant, category, description and payment method', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 1500,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'ABC Store',
          description: 'Groceries',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 500,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'shopping for groceries',
          date: DateTime(2026, 8, 11),
          paymentMethod: 'Cash',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 11),
          updatedAt: DateTime(2026, 8, 11),
        ),
      ];

      final matches = filterExpensesForUi(
        expenses: expenses,
        searchQuery: ' shopping ',
        typeFilter: null,
        categoryFilter: null,
        dateRange: null,
      );

      expect(matches, hasLength(2));
    });

    test('search combines with type and category filters', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 1500,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'ABC Store',
          description: 'Groceries',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 1500,
          type: ExpenseType.credit,
          category: 'Shopping',
          merchant: 'Refund',
          description: 'Reversal',
          date: DateTime(2026, 8, 10),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 10),
          updatedAt: DateTime(2026, 8, 10),
        ),
      ];

      final matches = filterExpensesForUi(
        expenses: expenses,
        searchQuery: 'store',
        typeFilter: ExpenseType.debit,
        categoryFilter: 'Shopping',
        dateRange: null,
      );

      expect(matches, hasLength(1));
      expect(matches.first.merchant, 'ABC Store');
    });
  });

  group('csv escaping', () {
    test('escapes CSV fields safely with commas, quotes and newlines', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 12345,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: '"Main" Market',
          description: 'Lunch, "special"\norder',
          date: DateTime(2026, 8, 18),
          paymentMethod: 'Credit, Card',
          receiptUrl: 'https://example.com/a,b.csv',
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
      ];

      final csv = ExpenseExportService.generateCsv(expenses);

      expect(csv, contains('""Main"" Market"'));
      expect(csv, contains('"Lunch, ""special""\norder"'));
      expect(csv, contains('"Credit, Card"'));
      expect(csv, contains('"https://example.com/a,b.csv"'));
    });
  });
}
