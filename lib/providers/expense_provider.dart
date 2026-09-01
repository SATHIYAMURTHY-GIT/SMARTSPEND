import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'authentication_provider.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository();
});

final expensesProvider = StreamProvider.autoDispose<List<Expense>>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) => user == null
        ? Stream.value(const <Expense>[])
        : ref.watch(expenseRepositoryProvider).watchExpenses(),
    loading: () => Stream.value(const <Expense>[]),
    error: (error, stackTrace) => Stream.value(const <Expense>[]),
  );
});