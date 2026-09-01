import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/screens/home/home_screen.dart';

void main() {
  group('Dashboard insights', () {
    test('calculates debit category totals, monthly totals, and safe insights', () {
      final now = DateTime.now();
      final prevMonth = DateTime(now.year, now.month - 1, 12);
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 15000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(now.year, now.month, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(now.year, now.month, 10),
          updatedAt: DateTime(now.year, now.month, 10),
        ),
        Expense(
          id: '2',
          userId: 'u',
          amount: 25000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Grocer',
          description: 'Groceries',
          date: DateTime(now.year, now.month, 14),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(now.year, now.month, 14),
          updatedAt: DateTime(now.year, now.month, 14),
        ),
        Expense(
          id: '3',
          userId: 'u',
          amount: 30000,
          type: ExpenseType.debit,
          category: 'Travel',
          merchant: 'Metro',
          description: 'Transport',
          date: prevMonth,
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: prevMonth,
          updatedAt: prevMonth,
        ),
        Expense(
          id: '4',
          userId: 'u',
          amount: 50000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Salary',
          date: DateTime(now.year, now.month, 1),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(now.year, now.month, 1),
          updatedAt: DateTime(now.year, now.month, 1),
        ),
      ];

      final data = DashboardInsightsData.fromExpenses(expenses);

      expect(data.categoryBreakdown.length, 2);
      expect(data.categoryBreakdown.first.name, 'Food');
      expect(data.categoryBreakdown.first.amount, 40000);
      expect(data.monthlyBreakdown.length, 6);
      expect(data.currentMonthDebitTotal, 40000);
      expect(data.currentMonthCreditTotal, 50000);
      expect(data.debitTransactionCount, 3);
      expect(data.averageDebitAmount, 23333);
      expect(data.highestSpendingCategory, 'Food');
    });

    test('returns empty insights when there are no debit transactions', () {
      final now = DateTime.now();
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 50000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Salary',
          date: DateTime(now.year, now.month, 1),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(now.year, now.month, 1),
          updatedAt: DateTime(now.year, now.month, 1),
        ),
      ];

      final data = DashboardInsightsData.fromExpenses(expenses);

      expect(data.categoryBreakdown, isEmpty);
      expect(data.monthlyBreakdown.every((entry) => entry.amount == 0), isTrue);
      expect(data.highestSpendingCategory, isNull);
      expect(data.averageDebitAmount, 0);
      expect(data.debitTransactionCount, 0);
      expect(data.currentMonthDebitTotal, 0);
      expect(data.currentMonthCreditTotal, 50000);
    });

    test('normalizes category names before dashboard grouping', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 20000,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'A',
          description: 'A',
          date: DateTime(2026, 8, 3),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 3),
          updatedAt: DateTime(2026, 8, 3),
        ),
        Expense(
          id: '2',
          userId: 'u',
          amount: 15000,
          type: ExpenseType.debit,
          category: ' shopping ',
          merchant: 'B',
          description: 'B',
          date: DateTime(2026, 8, 8),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 8),
          updatedAt: DateTime(2026, 8, 8),
        ),
        Expense(
          id: '3',
          userId: 'u',
          amount: 5000,
          type: ExpenseType.debit,
          category: 'SHOPPING',
          merchant: 'C',
          description: 'C',
          date: DateTime(2026, 8, 12),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 12),
          updatedAt: DateTime(2026, 8, 12),
        ),
      ];

      final data = DashboardInsightsData.fromExpenses(expenses, referenceTime: DateTime(2026, 8, 20));

      expect(data.categoryBreakdown.length, 1);
      expect(data.categoryBreakdown.first.name, 'Shopping');
      expect(data.categoryBreakdown.first.amount, 40000);
      expect(data.highestSpendingCategory, 'Shopping');
    });

    test('builds exactly six recent months with one debit-only point per month', () {
      final reference = DateTime(2026, 8, 20);
      final expenses = [
        Expense(
          id: '1',
          userId: 'u',
          amount: 25000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'A',
          description: 'A',
          date: DateTime(2026, 3, 10),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 3, 10),
          updatedAt: DateTime(2026, 3, 10),
        ),
        Expense(
          id: '2',
          userId: 'u',
          amount: 30000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Salary',
          date: DateTime(2026, 5, 2),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 5, 2),
          updatedAt: DateTime(2026, 5, 2),
        ),
        Expense(
          id: '3',
          userId: 'u',
          amount: 40000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'B',
          description: 'B',
          date: DateTime(2026, 8, 11),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 11),
          updatedAt: DateTime(2026, 8, 11),
        ),
      ];

      final data = DashboardInsightsData.fromExpenses(expenses, referenceTime: reference);

      expect(data.monthlyBreakdown.length, 6);
      expect(data.monthlyBreakdown.map((entry) => entry.label).toSet().length, 6);
      expect(data.monthlyBreakdown.every((entry) => entry.amount >= 0), isTrue);
      expect(data.monthlyBreakdown.map((entry) => entry.amount).every((amount) => amount >= 0), isTrue);
      expect(data.monthlyBreakdown.map((entry) => entry.label), containsAll(['Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug']));
    });
  });
}
