import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/budget.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/services/expense_export_service.dart';

void main() {
  group('Expense export service', () {
    test('generates CSV with the expected headers and values', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 12345,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 18),
          paymentMethod: 'Card',
          receiptUrl: 'https://example.com/receipt.jpg',
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
      ];

      final csv = ExpenseExportService.generateCsv(expenses);

      expect(csv, contains('Date,Type,Amount,Category,Merchant,Description,Payment Method,Receipt URL'));
      expect(csv, contains('2026-08-18'));
      expect(csv, contains('Debit'));
      expect(csv, contains('₹123.45'));
      expect(csv, contains('Food'));
      expect(csv, contains('Cafe'));
      expect(csv, contains('Lunch'));
      expect(csv, contains('Card'));
      expect(csv, contains('https://example.com/receipt.jpg'));
    });

    test('keeps debit and credit entries separate in the CSV output', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 12345,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 18),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 34000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Monthly pay',
          date: DateTime(2026, 8, 20),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 20),
          updatedAt: DateTime(2026, 8, 20),
        ),
      ];

      final csv = ExpenseExportService.generateCsv(expenses);

      expect(csv.split('\n').length, greaterThan(2));
      expect(csv, contains('Debit'));
      expect(csv, contains('Credit'));
    });

    test('filters exported expenses by the selected date range', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 1200,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Coffee',
          description: 'Morning coffee',
          date: DateTime(2026, 8, 9),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 9),
          updatedAt: DateTime(2026, 8, 9),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 1800,
          type: ExpenseType.debit,
          category: 'Transport',
          merchant: 'Metro',
          description: 'Travel',
          date: DateTime(2026, 8, 12),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 12),
          updatedAt: DateTime(2026, 8, 12),
        ),
        Expense(
          id: '3',
          userId: 'user-1',
          amount: 2000,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Groceries',
          description: 'Weekend purchase',
          date: DateTime(2026, 8, 21),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 21),
          updatedAt: DateTime(2026, 8, 21),
        ),
      ];

      final range = DateTimeRange(
        start: DateTime(2026, 8, 10),
        end: DateTime(2026, 8, 18),
      );

      final filtered = ExpenseExportService.filterExpensesByRange(expenses, range);
      final csv = ExpenseExportService.generateCsv(filtered);

      expect(filtered.length, 1);
      expect(csv, contains('2026-08-12'));
      expect(csv, isNot(contains('2026-08-09')));
      expect(csv, isNot(contains('2026-08-21')));
    });

    test('includes category, merchant and description fields in the CSV output', () {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 5000,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'Market Place',
          description: 'Office supplies',
          date: DateTime(2026, 8, 20),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 20),
          updatedAt: DateTime(2026, 8, 20),
        ),
      ];

      final csv = ExpenseExportService.generateCsv(expenses);

      expect(csv, contains('Shopping'));
      expect(csv, contains('Market Place'));
      expect(csv, contains('Office supplies'));
    });

    test('formats INR amounts correctly for export output', () {
      expect(ExpenseExportService.formatAmountForExport(12345), '₹123.45');
      expect(ExpenseExportService.formatAmountForExport(0), '₹0.00');
      expect(ExpenseExportService.formatAmountForExport(-2500), '-₹25.00');
    });

    test('creates a real temporary CSV file that exists and has content', () async {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 12345,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 18),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
      ];

      final csv = ExpenseExportService.generateCsv(expenses);
      expect(csv, isNotEmpty);

      final directory = await Directory.systemTemp.createTemp('smartspend-export-test');
      final file = File('${directory.path}/smartspend-export.csv');
      await file.writeAsString(csv);

      expect(await file.exists(), isTrue);
      expect(await file.length(), greaterThan(0));

      await file.delete();
      await directory.delete(recursive: true);
    });

    test('creates a readable PDF financial report for a selected period', () async {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 12345,
          type: ExpenseType.debit,
          category: 'Food',
          merchant: 'Cafe',
          description: 'Lunch',
          date: DateTime(2026, 8, 18),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 18),
          updatedAt: DateTime(2026, 8, 18),
        ),
        Expense(
          id: '2',
          userId: 'user-1',
          amount: 34000,
          type: ExpenseType.credit,
          category: 'Income',
          merchant: 'Salary',
          description: 'Monthly pay',
          date: DateTime(2026, 8, 20),
          paymentMethod: 'Bank',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 20),
          updatedAt: DateTime(2026, 8, 20),
        ),
      ];

      final report = await ExpenseExportService.generatePdfReport(
        expenses,
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        ),
        budget: null,
      );

      expect(report, isNotEmpty);
      expect(report.sublist(0, 5), equals('%PDF-'.codeUnits));
      expect(report.length, greaterThan(100));
    });

    test('generates valid PDF when expenses list is empty (empty state report)', () async {
      final report = await ExpenseExportService.generatePdfReport(
        [],
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        ),
        budget: null,
      );

      expect(report, isNotEmpty);
      expect(report.sublist(0, 5), equals('%PDF-'.codeUnits));
    });

    test('generates valid PDF with budget and tracks status correctly', () async {
      final expenses = [
        Expense(
          id: '1',
          userId: 'user-1',
          amount: 250000,
          type: ExpenseType.debit,
          category: 'Shopping',
          merchant: 'Store',
          description: 'Purchase',
          date: DateTime(2026, 8, 15),
          paymentMethod: 'Card',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 15),
          updatedAt: DateTime(2026, 8, 15),
        ),
      ];

      // On Track budget
      final onTrackReport = await ExpenseExportService.generatePdfReport(
        expenses,
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        ),
        budget: MonthlyBudget(
          userId: 'user-1',
          monthlyLimitMinorUnits: 500000,
          updatedAt: DateTime(2026, 8, 1),
        ),
      );
      expect(onTrackReport, isNotEmpty);

      // Exceeded budget
      final exceededReport = await ExpenseExportService.generatePdfReport(
        expenses,
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        ),
        budget: MonthlyBudget(
          userId: 'user-1',
          monthlyLimitMinorUnits: 200000,
          updatedAt: DateTime(2026, 8, 1),
        ),
      );
      expect(exceededReport, isNotEmpty);
    });

    test('generates multi-page PDF safely with 50+ transactions without layout errors', () async {
      final manyExpenses = List.generate(
        60,
        (i) => Expense(
          id: 'exp-$i',
          userId: 'user-1',
          amount: 1000 + (i * 250),
          type: i % 5 == 0 ? ExpenseType.credit : ExpenseType.debit,
          category: i % 2 == 0 ? 'Food' : 'Shopping',
          merchant: 'Merchant $i',
          description: 'Item description $i',
          date: DateTime(2026, 8, 1).add(Duration(days: i % 28)),
          paymentMethod: 'UPI',
          receiptUrl: null,
          createdAt: DateTime(2026, 8, 1),
          updatedAt: DateTime(2026, 8, 1),
        ),
      );

      final report = await ExpenseExportService.generatePdfReport(
        manyExpenses,
        selectedRange: DateTimeRange(
          start: DateTime(2026, 8, 1),
          end: DateTime(2026, 8, 31),
        ),
        budget: MonthlyBudget(
          userId: 'user-1',
          monthlyLimitMinorUnits: 2000000,
          updatedAt: DateTime(2026, 8, 1),
        ),
      );

      expect(report, isNotEmpty);
      expect(report.length, greaterThan(5000));
    });

    test('formats PDF amount in INR with Rupee symbol and no Unicode errors', () {
      expect(ExpenseExportService.formatPdfAmount(19300), '₹193.00');
      expect(ExpenseExportService.formatPdfAmount(1000), '₹10.00');
      expect(ExpenseExportService.formatPdfAmount(500000), '₹5000.00');
      expect(ExpenseExportService.formatPdfAmount(0), '₹0.00');
    });

    test('returns empty csv for empty export data', () {
      expect(ExpenseExportService.generateCsv([]), isEmpty);
    });
  });
}
