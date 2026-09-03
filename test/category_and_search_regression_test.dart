import 'package:flutter/material.dart';
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

  group('centralized category color mapping', () {
    test('maps all standard categories to their permanent consistent colors', () {
      expect(categoryColorForKey('Food'), const Color(0xFF8E24AA));
      expect(categoryColorForKey('Transport'), const Color(0xFF1E88E5));
      expect(categoryColorForKey('Shopping'), const Color(0xFFFB8C00));
      expect(categoryColorForKey('Bills'), const Color(0xFF43A047));
      expect(categoryColorForKey('Education'), const Color(0xFFE53935));
      expect(categoryColorForKey('Entertainment'), const Color(0xFFFDD835));
      expect(categoryColorForKey('Healthcare'), const Color(0xFFE91E63));
      expect(categoryColorForKey('Travel'), const Color(0xFF00897B));
      expect(categoryColorForKey('Subscriptions'), const Color(0xFF3949AB));
      expect(categoryColorForKey('Other'), const Color(0xFF757575));
    });

    test('colors remain permanent regardless of casing, whitespace or order', () {
      expect(categoryColorForKey('  food  '), const Color(0xFF8E24AA));
      expect(categoryColorForKey('TRANSPORT'), const Color(0xFF1E88E5));
      expect(categoryColorForKey('shopping'), const Color(0xFFFB8C00));
      expect(categoryColorForKey('Groceries'), const Color(0xFF8E24AA));
      expect(categoryColorForKey('Utilities'), const Color(0xFF43A047));
      expect(categoryColorForKey('Medical'), const Color(0xFFE91E63));
      expect(categoryColorForKey('General'), const Color(0xFF757575));
    });

    test('custom categories receive deterministic, stable colors', () {
      final color1 = categoryColorForKey('Gym Membership');
      final color2 = categoryColorForKey('Gym Membership');
      expect(color1, equals(color2));
    });
  });
}
