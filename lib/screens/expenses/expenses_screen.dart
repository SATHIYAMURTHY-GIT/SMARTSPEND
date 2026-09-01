import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import '../../providers/expense_provider.dart';

DateTime _startOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime _endOfDay(DateTime date) =>
    DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

List<Expense> filterExpensesForUi({
  required List<Expense> expenses,
  required String searchQuery,
  required ExpenseType? typeFilter,
  required String? categoryFilter,
  required DateTimeRange? dateRange,
}) {
  final query = searchQuery.trim().toLowerCase();
  return expenses
      .where((expense) {
        final searchableText = [
          expense.merchant,
          expense.category,
          expense.description,
          expense.paymentMethod,
        ].whereType<String>().join(' ').toLowerCase();
        final matchesSearch = query.isEmpty || searchableText.contains(query);
        final matchesType = typeFilter == null || expense.type == typeFilter;
        final normalizedCategory = normalizeCategoryKey(expense.category);
        final normalizedSelectedCategory = normalizeCategoryKey(categoryFilter);
        final matchesCategory =
            categoryFilter == null ||
            normalizedCategory == normalizedSelectedCategory;
        final expenseDate = expense.date;
        final matchesDate =
            dateRange == null ||
            (expenseDate != null &&
                !expenseDate.isBefore(_startOfDay(dateRange.start)) &&
                !expenseDate.isAfter(_endOfDay(dateRange.end)));
        return matchesSearch && matchesType && matchesCategory && matchesDate;
      })
      .toList(growable: false);
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String? _deletingExpenseId;
  String _searchQuery = '';
  ExpenseType? _typeFilter;
  String? _categoryFilter;
  DateTimeRange? _dateRange;

  Future<void> _editExpense(Expense expense) async {
    context.go('/add', extra: expense);
  }

  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          'Delete ${expense.merchant ?? expense.category ?? 'this expense'} '
          'for ${formatMinorUnits(expense.amount)}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deletingExpenseId = expense.id);
    try {
      await ref.read(expenseRepositoryProvider).deleteExpense(expense.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense deleted successfully.')),
      );
    } on StateError {
      _showDeleteError('Please sign in before deleting an expense.');
    } on FirebaseException {
      _showDeleteError('We could not delete this expense. Please try again.');
    } catch (_) {
      _showDeleteError('We could not delete this expense. Please try again.');
    } finally {
      if (mounted) setState(() => _deletingExpenseId = null);
    }
  }

  void _showDeleteError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) setState(() => _dateRange = range);
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _typeFilter = null;
      _categoryFilter = null;
      _dateRange = null;
    });
  }

  List<Expense> _filteredExpenses(List<Expense> expenses) {
    return filterExpensesForUi(
      expenses: expenses,
      searchQuery: _searchQuery,
      typeFilter: _typeFilter,
      categoryFilter: _categoryFilter,
      dateRange: _dateRange,
    );
  }

  Future<void> _showFilterSheet([List<String>? categoryOptions]) async {
    final selectedType = _typeFilter;
    final selectedCategory = _categoryFilter;
    final selectedRange = _dateRange;
    final categories = categoryOptions ?? const <String>[];

    final result = await showModalBottomSheet<_FilterSheetResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return _FilterSheetContent(
          selectedType: selectedType,
          selectedCategory: selectedCategory,
          selectedRange: selectedRange,
          categories: categories,
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _typeFilter = result.typeFilter;
      _categoryFilter = result.categoryFilter;
      _dateRange = result.dateRange;
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final categoryOptions = expenses.maybeWhen(
      data: (items) =>
          items
              .map((expense) => normalizeCategoryName(expense.category))
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort(),
      orElse: () => const <String>[],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            onPressed: () => context.go('/add'),
            icon: const Icon(Icons.add),
            tooltip: 'Add expense',
          ),
        ],
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _EmptyExpenses(onAdd: () => context.go('/add')),
        data: (items) => items.isEmpty
            ? _EmptyExpenses(onAdd: () => context.go('/add'))
            : _ExpenseContent(
                expenses: _filteredExpenses(items),
                allExpenses: items,
                searchQuery: _searchQuery,
                typeFilter: _typeFilter,
                categoryFilter: _categoryFilter,
                dateRange: _dateRange,
                deletingExpenseId: _deletingExpenseId,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                onTypeChanged: (value) => setState(() => _typeFilter = value),
                onCategoryChanged: (value) =>
                    setState(() => _categoryFilter = value),
                onDateRange: _selectDateRange,
                onClearFilters: _clearFilters,
                onFilterPressed: () => _showFilterSheet(categoryOptions),
                onEdit: _editExpense,
                onDelete: _confirmDelete,
              ),
      ),
    );
  }
}

class _ExpenseContent extends StatelessWidget {
  const _ExpenseContent({
    required this.expenses,
    required this.allExpenses,
    required this.searchQuery,
    required this.typeFilter,
    required this.categoryFilter,
    required this.dateRange,
    required this.deletingExpenseId,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onDateRange,
    required this.onClearFilters,
    required this.onFilterPressed,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final List<Expense> allExpenses;
  final String searchQuery;
  final ExpenseType? typeFilter;
  final String? categoryFilter;
  final DateTimeRange? dateRange;
  final String? deletingExpenseId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ExpenseType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onDateRange;
  final VoidCallback onClearFilters;
  final VoidCallback onFilterPressed;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final categories =
        allExpenses
            .map((expense) => normalizeCategoryName(expense.category))
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              _ExpenseSummary(expenses: expenses),
              const SizedBox(height: 16),
              TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search merchant, category, description, method...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: onFilterPressed,
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filters',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _FilterBar(
                typeFilter: typeFilter,
                categoryFilter: categoryFilter,
                categories: categories,
                dateRange: dateRange,
                onTypeChanged: onTypeChanged,
                onCategoryChanged: onCategoryChanged,
                onDateRange: onDateRange,
                onClearFilters: onClearFilters,
              ),
              const SizedBox(height: 16),
              if (expenses.isEmpty)
                const _NoMatchingExpenses()
              else
                _ExpenseList(
                  expenses: expenses,
                  deletingExpenseId: deletingExpenseId,
                  onEdit: onEdit,
                  onDelete: onDelete,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseSummary extends StatelessWidget {
  const _ExpenseSummary({required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    var debitTotal = 0;
    var creditTotal = 0;
    for (final expense in expenses) {
      if (expense.type == ExpenseType.credit) {
        creditTotal += expense.amount;
      } else {
        debitTotal += expense.amount;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 420
            ? (constraints.maxWidth - 10) / 2
            : (constraints.maxWidth - 20) / 3;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                label: 'Expenses',
                value: formatMinorUnits(debitTotal),
                icon: Icons.arrow_upward,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                label: 'Credits',
                value: formatMinorUnits(creditTotal),
                icon: Icons.arrow_downward,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _SummaryTile(
                label: 'Transactions',
                value: '${expenses.length}',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.categoryFilter,
    required this.categories,
    required this.dateRange,
    required this.onTypeChanged,
    required this.onCategoryChanged,
    required this.onDateRange,
    required this.onClearFilters,
  });

  final ExpenseType? typeFilter;
  final String? categoryFilter;
  final List<String> categories;
  final DateTimeRange? dateRange;
  final ValueChanged<ExpenseType?> onTypeChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onDateRange;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        typeFilter != null || categoryFilter != null || dateRange != null;
    if (!hasFilters) {
      return const SizedBox.shrink();
    }

    final chips = <Widget>[];

    if (typeFilter != null) {
      chips.add(
        InputChip(
          label: Text(typeFilter == ExpenseType.debit ? 'Debit' : 'Credit'),
          avatar: const Icon(Icons.filter_list, size: 18),
          onDeleted: () => onTypeChanged(null),
        ),
      );
    }

    if (categoryFilter != null) {
      chips.add(
        InputChip(
          label: Text(categoryFilter ?? 'Category'),
          avatar: const Icon(Icons.category_outlined, size: 18),
          onDeleted: () => onCategoryChanged(null),
        ),
      );
    }

    if (dateRange != null) {
      chips.add(
        InputChip(
          label: Text(
            '${DateFormat.MMMd().format(dateRange!.start)} - ${DateFormat.MMMd().format(dateRange!.end)}',
          ),
          avatar: const Icon(Icons.date_range_outlined, size: 18),
          onDeleted: () => onDateRange(),
        ),
      );
    }

    chips.add(
      TextButton(onPressed: onClearFilters, child: const Text('Clear all')),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _NoMatchingExpenses extends StatelessWidget {
  const _NoMatchingExpenses();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 46,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          const Text('No expenses match these filters.'),
        ],
      ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 52,
                  color: colors.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  'No expenses yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your first transaction to start building your personal spending history.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                  label: const Text('Add expense'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpenseList extends StatelessWidget {
  const _ExpenseList({
    required this.expenses,
    required this.deletingExpenseId,
    required this.onEdit,
    required this.onDelete,
  });

  final List<Expense> expenses;
  final String? deletingExpenseId;
  final ValueChanged<Expense> onEdit;
  final ValueChanged<Expense> onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: expenses.length,
      itemBuilder: (context, index) {
        final expense = expenses[index];
        final isCredit = expense.type == ExpenseType.credit;
        final isDeleting = deletingExpenseId == expense.id;
        final subtitle = [
          if (expense.category != null) expense.category!,
          if (expense.date != null) DateFormat.yMMMd().format(expense.date!),
        ].join('  •  ');
        return Padding(
          key: ValueKey(expense.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: Card(
            child: ListTile(
              onTap: isDeleting ? null : () => onEdit(expense),
              leading: CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                child: Icon(
                  isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: colors.onSecondaryContainer,
                ),
              ),
              title: Text(expense.merchant ?? expense.category ?? 'Expense'),
              subtitle: Text(subtitle),
              trailing: isDeleting
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (expense.receiptUrl != null &&
                            expense.receiptUrl!.isNotEmpty)
                          IconButton(
                            tooltip: 'Open receipt',
                            onPressed: () => _showReceiptDialog(
                              context,
                              expense.receiptUrl!,
                            ),
                            icon: const Icon(Icons.receipt_long_outlined),
                            visualDensity: VisualDensity.compact,
                          ),
                        Text(
                          '${isCredit ? '+' : '-'}${formatMinorUnits(expense.amount)}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: isCredit
                                    ? colors.primary
                                    : colors.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        PopupMenuButton<_ExpenseAction>(
                          tooltip: 'Expense actions',
                          onSelected: (action) => action == _ExpenseAction.edit
                              ? onEdit(expense)
                              : onDelete(expense),
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _ExpenseAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _ExpenseAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _showReceiptDialog(BuildContext context, String receiptUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 360,
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 0.9,
                      child: Image.network(
                        receiptUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('Receipt could not be loaded.'),
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterSheetResult {
  const _FilterSheetResult({
    required this.typeFilter,
    required this.categoryFilter,
    required this.dateRange,
  });

  final ExpenseType? typeFilter;
  final String? categoryFilter;
  final DateTimeRange? dateRange;
}

class _FilterSheetContent extends StatefulWidget {
  const _FilterSheetContent({
    required this.selectedType,
    required this.selectedCategory,
    required this.selectedRange,
    required this.categories,
  });

  final ExpenseType? selectedType;
  final String? selectedCategory;
  final DateTimeRange? selectedRange;
  final List<String> categories;

  @override
  State<_FilterSheetContent> createState() => _FilterSheetContentState();
}

class _FilterSheetContentState extends State<_FilterSheetContent> {
  late ExpenseType? _typeFilter = widget.selectedType;
  late String? _categoryFilter = widget.selectedCategory;
  late DateTimeRange? _dateRange = widget.selectedRange;

  Future<void> _selectDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
    );
    if (range != null) {
      setState(() => _dateRange = range);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories;
    final hasFilters =
        _typeFilter != null || _categoryFilter != null || _dateRange != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Filter expenses',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (hasFilters)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _typeFilter = null;
                            _categoryFilter = null;
                            _dateRange = null;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _typeFilter == null,
                      onSelected: (_) => setState(() => _typeFilter = null),
                    ),
                    ChoiceChip(
                      label: const Text('Debit'),
                      selected: _typeFilter == ExpenseType.debit,
                      onSelected: (_) =>
                          setState(() => _typeFilter = ExpenseType.debit),
                    ),
                    ChoiceChip(
                      label: const Text('Credit'),
                      selected: _typeFilter == ExpenseType.credit,
                      onSelected: (_) =>
                          setState(() => _typeFilter = ExpenseType.credit),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (categories.isNotEmpty)
                  DropdownButtonFormField<String?>(
                    initialValue: _categoryFilter,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All categories'),
                      ),
                      ...categories.map(
                        (category) => DropdownMenuItem<String?>(
                          value: category,
                          child: Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _categoryFilter = value),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_outlined),
                  title: Text(
                    _dateRange == null
                        ? 'Date range'
                        : '${DateFormat.MMMd().format(_dateRange!.start)} - ${DateFormat.MMMd().format(_dateRange!.end)}',
                  ),
                  onTap: _selectDateRange,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(
                          _FilterSheetResult(
                            typeFilter: _typeFilter,
                            categoryFilter: _categoryFilter,
                            dateRange: _dateRange,
                          ),
                        ),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExpenseAction { edit, delete }
