import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartspend/models/expense.dart';
import 'package:smartspend/providers/expense_provider.dart';
import 'package:smartspend/repositories/expense_repository.dart';
import 'package:smartspend/screens/add_expense/add_expense_screen.dart';

class FakeExpenseRepository extends ExpenseRepository {
  final List<Expense> savedExpenses = [];

  @override
  Future<String> createExpense(Expense expense) async {
    final created = Expense(
      id: 'generated_id_${savedExpenses.length + 1}',
      userId: 'test_user',
      amount: expense.amount,
      type: expense.type,
      category: expense.category,
      merchant: expense.merchant,
      description: expense.description,
      date: expense.date,
      paymentMethod: expense.paymentMethod,
      receiptUrl: expense.receiptUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    savedExpenses.add(created);
    return created.id;
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final index = savedExpenses.indexWhere((e) => e.id == expense.id);
    if (index >= 0) {
      savedExpenses[index] = expense;
    } else {
      savedExpenses.add(expense);
    }
  }

  @override
  Stream<List<Expense>> watchExpenses() async* {
    yield savedExpenses;
  }
}

class _TestHarness extends StatefulWidget {
  const _TestHarness({required this.initialExpense, super.key});

  final Expense? initialExpense;

  @override
  State<_TestHarness> createState() => _TestHarnessState();
}

class _TestHarnessState extends State<_TestHarness> {
  Expense? _expense;

  @override
  void initState() {
    super.initState();
    _expense = widget.initialExpense;
  }

  void setExpense(Expense? expense) {
    setState(() {
      _expense = expense;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AddExpenseScreen(expense: _expense);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AddExpenseScreen Form State Reset & Stale Data Prevention', () {
    testWidgets('saving an expense resets all temporary form fields and leaves saved expense intact', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeExpenseRepository();
      final initialExpense = Expense(
        id: 'seed_1',
        userId: 'test_user',
        amount: 10000,
        type: ExpenseType.debit,
        category: 'Groceries',
        merchant: 'Initial Merchant',
        description: null,
        date: DateTime.now(),
        paymentMethod: 'Cash',
        receiptUrl: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(fakeRepo),
            expensesProvider.overrideWith((ref) => Stream.value([initialExpense])),
          ],
          child: const MaterialApp(
            home: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter amount (0th TextFormField)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '250.50');

      // Select category via Dropdown
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groceries').last);
      await tester.pumpAndSettle();

      // Enter merchant (1st TextFormField)
      await tester.enterText(textFields.at(1), 'SuperMart Grocery');

      // Enter description (2nd TextFormField)
      await tester.enterText(textFields.at(2), 'Weekly grocery shopping');

      // Select payment method via second Dropdown
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('UPI').last);
      await tester.pumpAndSettle();

      // Submit and save
      final saveButton = find.text('Save expense');
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 1. Verify the saved expense remains intact in the repository
      expect(fakeRepo.savedExpenses.length, 1);
      final saved = fakeRepo.savedExpenses.first;
      expect(saved.amount, 25050);
      expect(saved.merchant, 'SuperMart Grocery');
      expect(saved.description, 'Weekly grocery shopping');
      expect(saved.category, 'Groceries');
      expect(saved.paymentMethod, 'UPI');

      // 2. Verify all form fields on the AddExpenseScreen are reset to fresh state
      expect(find.text('250.50'), findsNothing);
      expect(find.text('SuperMart Grocery'), findsNothing);
      expect(find.text('Weekly grocery shopping'), findsNothing);

      // Verify amount controller is empty
      final amountField = tester.widget<TextFormField>(textFields.at(0));
      expect(amountField.controller?.text, '');

      // Verify merchant controller is empty
      final merchantField = tester.widget<TextFormField>(textFields.at(1));
      expect(merchantField.controller?.text, '');

      // Verify description controller is empty
      final descriptionField = tester.widget<TextFormField>(textFields.at(2));
      expect(descriptionField.controller?.text, '');
    });

    testWidgets('navigating between edit and fresh new expense clears stale form data via didUpdateWidget', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final fakeRepo = FakeExpenseRepository();
      final existingExpense = Expense(
        id: 'exp_1',
        userId: 'u1',
        amount: 99900,
        type: ExpenseType.debit,
        category: 'Electronics',
        merchant: 'Gadget Store',
        description: 'New Headphones',
        date: DateTime(2026, 8, 15),
        paymentMethod: 'Credit card',
        receiptUrl: null,
        createdAt: DateTime(2026, 8, 15),
        updatedAt: DateTime(2026, 8, 15),
      );

      final harnessKey = GlobalKey<_TestHarnessState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            expenseRepositoryProvider.overrideWithValue(fakeRepo),
            expensesProvider.overrideWith((ref) => Stream.value(<Expense>[existingExpense])),
          ],
          child: MaterialApp(
            home: _TestHarness(
              key: harnessKey,
              initialExpense: existingExpense,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify populated data for edit
      expect(find.text('999.00'), findsOneWidget);
      expect(find.text('Gadget Store'), findsOneWidget);
      expect(find.text('New Headphones'), findsOneWidget);
      expect(find.text('Update transaction'), findsOneWidget);

      // Now update the parent state to a fresh new expense (expense: null)
      harnessKey.currentState!.setExpense(null);
      await tester.pumpAndSettle();

      // Verify all stale edit data was cleared
      expect(find.text('999.00'), findsNothing);
      expect(find.text('Gadget Store'), findsNothing);
      expect(find.text('New Headphones'), findsNothing);
      expect(find.text('Update transaction'), findsNothing);
      expect(find.text('Record a transaction'), findsOneWidget);
    });
  });
}
