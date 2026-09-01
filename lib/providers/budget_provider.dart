import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/budget.dart';
import '../providers/authentication_provider.dart';
import '../repositories/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository();
});

final budgetProvider = StreamProvider.autoDispose<MonthlyBudget?>((ref) {
  final authState = ref.watch(authStateProvider);

  return authState.when(
    data: (user) => user == null
        ? Stream.value(null)
        : ref.watch(budgetRepositoryProvider).watchBudget(),
    loading: () => Stream.value(null),
    error: (error, stackTrace) => Stream.value(null),
  );
});
