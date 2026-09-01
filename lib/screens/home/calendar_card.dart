import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';

class CalendarCard extends StatefulWidget {
  const CalendarCard({required this.expenses, this.onDateSelected, super.key});

  final List<Expense> expenses;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _selectedDay;
  late DateTime _viewMonth;
  late Map<DateTime, List<Expense>> _expensesByDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = _dayOnly(now);
    _viewMonth = DateTime(now.year, now.month, 1);
    _buildExpensesByDate();
  }

  @override
  void didUpdateWidget(covariant CalendarCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expenses != widget.expenses) {
      _buildExpensesByDate();
    }
  }

  void _buildExpensesByDate() {
    final grouped = <DateTime, List<Expense>>{};
    for (final expense in widget.expenses) {
      final expenseDate = expense.date;
      if (expenseDate == null) continue;

      final dateKey = _dayOnly(expenseDate);
      grouped.putIfAbsent(dateKey, () => <Expense>[]).add(expense);
    }

    _expensesByDate = grouped;
  }

  List<Expense> _expensesForDay(DateTime day) {
    return _expensesByDate[_dayOnly(day)] ?? const <Expense>[];
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedExpenses = _expensesForDay(_selectedDay);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calendar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _viewMonth = DateTime(
                          _viewMonth.year,
                          _viewMonth.month - 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous month',
                  ),
                  Text(
                    DateFormat.yMMMM().format(_viewMonth),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    iconSize: 20,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _viewMonth = DateTime(
                          _viewMonth.year,
                          _viewMonth.month + 1,
                          1,
                        );
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next month',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeekdayHeader(context),
          const SizedBox(height: 6),
          _buildDaysGrid(context),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _SelectedDayExpenses(date: _selectedDay, expenses: selectedExpenses),
        ],
      ),
    );
  }

  Widget _buildWeekdayHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Row(
      children: weekdays.map((day) {
        return Expanded(
          child: Center(
            child: Text(
              day,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDaysGrid(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = _dayOnly(now);

    final firstDayOfMonth = DateTime(_viewMonth.year, _viewMonth.month, 1);
    final daysInCurrentMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final leadingOffset = firstDayOfMonth.weekday % 7;

    final totalCells = ((leadingOffset + daysInCurrentMonth + 6) ~/ 7) * 7;
    final startDate = firstDayOfMonth.subtract(Duration(days: leadingOffset));

    final rows = <Widget>[];
    for (var i = 0; i < totalCells; i += 7) {
      final weekCells = <Widget>[];
      for (var col = 0; col < 7; col++) {
        final cellDate = startDate.add(Duration(days: i + col));
        final isCurrentMonth = cellDate.month == _viewMonth.month;
        final isSelected = _isSameDay(cellDate, _selectedDay);
        final isToday = _isSameDay(cellDate, today);
        final dayExpenses = _expensesForDay(cellDate);
        final hasExpenses = dayExpenses.isNotEmpty;

        weekCells.add(
          Expanded(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      final selected = _dayOnly(cellDate);
                      setState(() {
                        _selectedDay = selected;
                        if (cellDate.month != _viewMonth.month) {
                          _viewMonth = DateTime(cellDate.year, cellDate.month, 1);
                        }
                      });
                      widget.onDateSelected?.call(selected);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary
                            : (isToday
                                ? colors.primaryContainer.withValues(alpha: 0.35)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(10),
                        border: (isToday && !isSelected)
                            ? Border.all(color: colors.primary, width: 1.2)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${cellDate.day}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected || isToday
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? colors.onPrimary
                                  : (isCurrentMonth
                                      ? colors.onSurface
                                      : colors.onSurfaceVariant.withValues(alpha: 0.38)),
                            ),
                          ),
                          if (hasExpenses) ...[
                            const SizedBox(height: 2),
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.onPrimary
                                    : (dayExpenses.any((e) => e.type == ExpenseType.debit)
                                        ? colors.primary
                                        : colors.secondary),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ] else
                            const SizedBox(height: 7),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: weekCells),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

class _SelectedDayExpenses extends StatelessWidget {
  const _SelectedDayExpenses({required this.date, required this.expenses});

  final DateTime date;
  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (expenses.isEmpty) {
      return Text(
        'No expenses on ${DateFormat.yMMMd().format(date)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      );
    }

    final totalDebit = expenses
        .where((e) => e.type == ExpenseType.debit)
        .fold<int>(0, (sum, expense) => sum + expense.amount);
    final totalCredit = expenses
        .where((e) => e.type == ExpenseType.credit)
        .fold<int>(0, (sum, expense) => sum + expense.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${expenses.length} ${expenses.length == 1 ? 'transaction' : 'transactions'} on ${DateFormat.yMMMd().format(date)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (totalDebit > 0)
              Text(
                formatMinorUnits(totalDebit),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        if (totalCredit > 0) ...[
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '+${formatMinorUnits(totalCredit)} credit',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: expenses.map((expense) {
            final isDebit = expense.type == ExpenseType.debit;
            final categoryName = normalizeCategoryName(expense.category);
            final displayName = categoryName.isNotEmpty
                ? categoryName
                : (expense.merchant ?? expense.description ?? 'Expense');
            final chipColor = categoryColorForKey(displayName);

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayName,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (expense.paymentMethod != null && expense.paymentMethod!.isNotEmpty) ...[
                    Text(
                      expense.paymentMethod!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    '${isDebit ? '-' : '+'}${formatMinorUnits(expense.amount)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDebit ? colors.error : colors.primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
