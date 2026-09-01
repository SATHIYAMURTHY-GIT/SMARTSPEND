import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/expenses/expenses_screen.dart';
import 'package:smartspend/screens/home/home_screen.dart';

Expense _createExpense({
  required String id,
  required int amount,
  required DateTime date,
  DateTime? createdAt,
  String merchant = 'Store',
}) {
  return Expense(
    id: id,
    userId: 'user-1',
    amount: amount,
    type: ExpenseType.debit,
    category: 'General',
    merchant: merchant,
    description: 'Test expense $id',
    date: date,
    paymentMethod: 'UPI',
    receiptUrl: null,
    createdAt: createdAt ?? date,
    updatedAt: date,
  );
}

void main() {
  group('Recent Transactions (3-transaction presentation limit)', () {
    test('0 expenses returns 0 recent transactions', () {
      final expenses = <Expense>[];
      final recent = getRecentTransactions(expenses, limit: 3);

      expect(recent, isEmpty);
    });

    test('1 expense returns exactly 1 recent transaction', () {
      final expenses = [
        _createExpense(id: '1', amount: 1000, date: DateTime(2026, 8, 1)),
      ];
      final recent = getRecentTransactions(expenses, limit: 3);

      expect(recent.length, 1);
      expect(recent.first.id, '1');
    });

    test('3 expenses returns all 3 recent transactions ordered newest first', () {
      final expenses = [
        _createExpense(id: '1', amount: 1000, date: DateTime(2026, 8, 1)),
        _createExpense(id: '3', amount: 3000, date: DateTime(2026, 8, 3)),
        _createExpense(id: '2', amount: 2000, date: DateTime(2026, 8, 2)),
      ];
      final recent = getRecentTransactions(expenses, limit: 3);

      expect(recent.length, 3);
      expect(recent.map((e) => e.id).toList(), ['3', '2', '1']);
    });

    test('5 expenses returns only the newest 3 transactions', () {
      final expenses = [
        _createExpense(id: '1', amount: 1000, date: DateTime(2026, 8, 1)),
        _createExpense(id: '2', amount: 2000, date: DateTime(2026, 8, 2)),
        _createExpense(id: '3', amount: 3000, date: DateTime(2026, 8, 3)),
        _createExpense(id: '4', amount: 4000, date: DateTime(2026, 8, 4)),
        _createExpense(id: '5', amount: 5000, date: DateTime(2026, 8, 5)),
      ];
      final recent = getRecentTransactions(expenses, limit: 3);

      expect(recent.length, 3);
      expect(recent.map((e) => e.id).toList(), ['5', '4', '3']);
    });

    test('adding a newer expense updates the list so oldest displayed drops off', () {
      final initialExpenses = [
        _createExpense(id: '1', amount: 1000, date: DateTime(2026, 8, 1)),
        _createExpense(id: '2', amount: 2000, date: DateTime(2026, 8, 2)),
        _createExpense(id: '3', amount: 3000, date: DateTime(2026, 8, 3)),
      ];
      final initialRecent = getRecentTransactions(initialExpenses, limit: 3);
      expect(initialRecent.map((e) => e.id).toList(), ['3', '2', '1']);

      // Add a 4th newer expense
      final updatedExpenses = [
        ...initialExpenses,
        _createExpense(id: '4', amount: 4000, date: DateTime(2026, 8, 10)),
      ];
      final updatedRecent = getRecentTransactions(updatedExpenses, limit: 3);

      expect(updatedRecent.length, 3);
      expect(updatedRecent.map((e) => e.id).toList(), ['4', '3', '2']);
      expect(updatedRecent.any((e) => e.id == '1'), isFalse);
    });

    test('Expenses screen filterExpensesForUi continues showing all expenses', () {
      final expenses = [
        _createExpense(id: '1', amount: 1000, date: DateTime(2026, 8, 1)),
        _createExpense(id: '2', amount: 2000, date: DateTime(2026, 8, 2)),
        _createExpense(id: '3', amount: 3000, date: DateTime(2026, 8, 3)),
        _createExpense(id: '4', amount: 4000, date: DateTime(2026, 8, 4)),
        _createExpense(id: '5', amount: 5000, date: DateTime(2026, 8, 5)),
      ];

      final filteredForUi = filterExpensesForUi(
        expenses: expenses,
        searchQuery: '',
        typeFilter: null,
        categoryFilter: null,
        dateRange: null,
      );

      // Expenses screen must preserve all 5 expenses
      expect(filteredForUi.length, 5);
      expect(filteredForUi.map((e) => e.id).toList(), ['1', '2', '3', '4', '5']);
    });
  });
}
