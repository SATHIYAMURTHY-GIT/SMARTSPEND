import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../models/expense.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../services/expense_export_service.dart';

enum ReportPeriod { today, thisWeek, thisMonth, lastMonth, custom }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportPeriod _selectedPeriod = ReportPeriod.thisMonth;
  DateTimeRange? _customRange;
  bool _isExporting = false;

  DateTimeRange _resolveSelectedRange() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return DateTimeRange(start: start, end: now);
      case ReportPeriod.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final startOfDay = DateTime(start.year, start.month, start.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: startOfDay, end: end);
      case ReportPeriod.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case ReportPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        final start = DateTime(lastMonth.year, lastMonth.month, 1);
        final end = DateTime(
          lastMonth.year,
          lastMonth.month + 1,
          0,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case ReportPeriod.custom:
        return _customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999),
            );
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _customRange ?? _resolveSelectedRange(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _customRange = picked;
      _selectedPeriod = ReportPeriod.custom;
    });
  }

  List<Expense> _filterExpenses(List<Expense> expenses) {
    final selectedRange = _resolveSelectedRange();
    return ExpenseExportService.filterExpensesByRange(expenses, selectedRange);
  }

  Future<void> _exportSelectedExpenses() async {
    if (_isExporting) return;

    final expenses = ref
        .read(expensesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <Expense>[]);
    final budget = ref
        .read(budgetProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);

    final range = _resolveSelectedRange();
    final filtered = ExpenseExportService.filterExpensesByRange(
      expenses,
      range,
    );

    if (!mounted) return;

    if (filtered.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export for this period.')),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      await ExpenseExportService.exportPdfToSharedFile(
        filtered,
        selectedRange: range,
        budget: budget,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF report prepared.')));
    } catch (error, stackTrace) {
      debugPrint('SmartSpend PDF export failed: $error');
      debugPrintStack(stackTrace: stackTrace, label: 'SmartSpend PDF export');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to export your PDF report right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _ReportsErrorState(
          onViewExpenses: () => context.go('/expenses'),
          onAddExpense: () => context.go('/add'),
        ),
        data: (expenses) {
          final range = _resolveSelectedRange();
          final filteredExpenses = _filterExpenses(expenses);
          final data = ReportsData.fromExpenses(
            filteredExpenses,
            selectedRange: range,
          );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial analysis',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _PeriodSelector(
                    selectedPeriod: _selectedPeriod,
                    customRangeLabel: _customRange == null
                        ? 'Custom range'
                        : '${DateFormat.MMMd().format(_customRange!.start)} - ${DateFormat.MMMd().format(_customRange!.end)}',
                    onSelected: (period) {
                      setState(() => _selectedPeriod = period);
                      if (period != ReportPeriod.custom) {
                        _customRange = null;
                      }
                    },
                    onCustom: _pickCustomRange,
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _exportSelectedExpenses,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_isExporting ? 'Exporting...' : 'Export PDF'),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (!data.hasData)
                    _EmptyReportsState(
                      onViewExpenses: () => context.go('/expenses'),
                      onAddExpense: () => context.go('/add'),
                    )
                  else ...[
                    _SummaryGrid(data: data),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Category analysis',
                      child: RepaintBoundary(
                        child: _CategoryBreakdownList(data: data),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionCard(
                      title: 'Time analysis',
                      child: RepaintBoundary(
                        child: _TrendChart(data: data),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selectedPeriod,
    required this.customRangeLabel,
    required this.onSelected,
    required this.onCustom,
  });

  final ReportPeriod selectedPeriod;
  final String customRangeLabel;
  final ValueChanged<ReportPeriod> onSelected;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    final periods = <_PeriodChipData>[
      _PeriodChipData(label: 'Today', value: ReportPeriod.today),
      _PeriodChipData(label: 'This week', value: ReportPeriod.thisWeek),
      _PeriodChipData(label: 'This month', value: ReportPeriod.thisMonth),
      _PeriodChipData(label: 'Last month', value: ReportPeriod.lastMonth),
      _PeriodChipData(label: customRangeLabel, value: ReportPeriod.custom),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: periods.map((period) {
        final selected = selectedPeriod == period.value;
        return ChoiceChip(
          label: Text(period.label),
          selected: selected,
          onSelected: (_) {
            if (period.value == ReportPeriod.custom) {
              onCustom();
              return;
            }
            onSelected(period.value);
          },
          selectedColor: palette.primaryContainer,
          labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? palette.onPrimaryContainer : palette.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          avatar: selected ? const Icon(Icons.check) : null,
        );
      }).toList(),
    );
  }
}

class _PeriodChipData {
  const _PeriodChipData({required this.label, required this.value});

  final String label;
  final ReportPeriod value;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    final cards = <_MetricTileData>[
      _MetricTileData(
        label: 'Total debit',
        value: formatMinorUnits(data.totalDebitSpending),
      ),
      _MetricTileData(
        label: 'Total credits',
        value: formatMinorUnits(data.totalCredits),
      ),
      _MetricTileData(
        label: 'Debit txn',
        value: data.debitTransactionCount.toString(),
      ),
      _MetricTileData(
        label: 'Credit txn',
        value: data.creditTransactionCount.toString(),
      ),
      _MetricTileData(
        label: 'Avg debit',
        value: formatMinorUnits(data.averageDebitAmount),
      ),
      _MetricTileData(
        label: 'Highest debit',
        value: formatMinorUnits(data.highestDebitAmount),
      ),
      _MetricTileData(
        label: 'Top category',
        value: data.highestSpendingCategory ?? 'N/A',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 360
            ? constraints.maxWidth
            : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((card) {
            return SizedBox(
              width: itemWidth,
              child: _MetricTile(label: card.label, value: card.value),
            );
          }).toList(),
        );
      },
    );
  }
}

class _MetricTileData {
  const _MetricTileData({required this.label, required this.value});

  final String label;
  final String value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CategoryBreakdownList extends StatelessWidget {
  const _CategoryBreakdownList({required this.data});

  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    if (data.categoryBreakdown.isEmpty) {
      return const Text('No debit spending data in this period.');
    }

    final total = data.totalDebitSpending;
    return Column(
      children: data.categoryBreakdown.map((entry) {
        final share = total <= 0 ? 0 : entry.percentOfTotal;
        final color = categoryColorForKey(entry.name);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.name,
                      style: Theme.of(context).textTheme.bodyLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${formatMinorUnits(entry.amount)} ($share%)',
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: total <= 0 ? 0 : (entry.amount / total).clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(999),
                color: color,
                backgroundColor: color.withValues(alpha: 0.18),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.data});

  final ReportsData data;

  @override
  Widget build(BuildContext context) {
    if (data.trendPoints.isEmpty) {
      return const Text('No data available for this time range.');
    }

    final maxAmount = data.trendPoints.fold<int>(0, (previousValue, point) {
      return point.amount > previousValue ? point.amount : previousValue;
    });

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxAmount <= 0 ? 1 : maxAmount.toDouble(),
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipRoundedRadius: 10,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final point = data.trendPoints[groupIndex];
                return BarTooltipItem(
                  '${point.label}\n${formatMinorUnits(point.amount)}',
                  const TextStyle(fontWeight: FontWeight.w600),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.trendPoints.length) {
                    return const SizedBox.shrink();
                  }

                  final label = data.trendPoints[index].shortLabel;
                  return Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
            ),
          ),
          barGroups: data.trendPoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            final color = index.isEven
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.secondary;

            return BarChartGroupData(
              x: index,
              barsSpace: 6,
              barRods: [
                BarChartRodData(
                  toY: point.amount.toDouble(),
                  width: 12,
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(7),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyReportsState extends StatelessWidget {
  const _EmptyReportsState({
    required this.onViewExpenses,
    required this.onAddExpense,
  });

  final VoidCallback onViewExpenses;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions in this period',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a new expense or review your existing entries to generate a report.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onViewExpenses,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('Expenses'),
                ),
                FilledButton.icon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.add),
                  label: const Text('Add expense'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsErrorState extends StatelessWidget {
  const _ReportsErrorState({
    required this.onViewExpenses,
    required this.onAddExpense,
  });

  final VoidCallback onViewExpenses;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your financial report is temporarily unavailable. Please try again shortly.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onViewExpenses,
                      icon: const Icon(Icons.list_alt_outlined),
                      label: const Text('Expenses'),
                    ),
                    FilledButton.icon(
                      onPressed: onAddExpense,
                      icon: const Icon(Icons.add),
                      label: const Text('Add expense'),
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

class ReportsData {
  const ReportsData({
    required this.totalDebitSpending,
    required this.totalCredits,
    required this.debitTransactionCount,
    required this.creditTransactionCount,
    required this.averageDebitAmount,
    required this.highestDebitAmount,
    required this.highestSpendingCategory,
    required this.categoryBreakdown,
    required this.trendPoints,
    required this.hasData,
  });

  final int totalDebitSpending;
  final int totalCredits;
  final int debitTransactionCount;
  final int creditTransactionCount;
  final int averageDebitAmount;
  final int highestDebitAmount;
  final String? highestSpendingCategory;
  final List<CategoryBreakdownEntry> categoryBreakdown;
  final List<TrendPoint> trendPoints;
  final bool hasData;

  static ReportsData fromExpenses(
    List<Expense> expenses, {
    required DateTimeRange selectedRange,
  }) {
    final filtered = expenses
        .where((expense) {
          final date = expense.date;
          if (date == null) return false;
          return !date.isBefore(_startOfDay(selectedRange.start)) &&
              !date.isAfter(_endOfDay(selectedRange.end));
        })
        .toList(growable: false);

    final debitTransactions = filtered
        .where((expense) => expense.type == ExpenseType.debit)
        .toList();
    final creditTransactions = filtered
        .where((expense) => expense.type == ExpenseType.credit)
        .toList();

    final totalDebitSpending = debitTransactions.fold<int>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final totalCredits = creditTransactions.fold<int>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final debitTransactionCount = debitTransactions.length;
    final creditTransactionCount = creditTransactions.length;
    final averageDebitAmount = debitTransactionCount == 0
        ? 0
        : totalDebitSpending ~/ debitTransactionCount;

    final highestDebitAmount = debitTransactions.isEmpty
        ? 0
        : debitTransactions
              .map((expense) => expense.amount)
              .reduce((a, b) => a > b ? a : b);

    final categoryMap = <String, int>{};
    for (final expense in debitTransactions) {
      final normalizedKey = normalizeCategoryKey(expense.category);
      if (normalizedKey.isEmpty) continue;
      categoryMap[normalizedKey] =
          (categoryMap[normalizedKey] ?? 0) + expense.amount;
    }

    final categoryBreakdown = categoryMap.entries.map((entry) {
      final displayName = normalizeCategoryName(entry.key);
      return CategoryBreakdownEntry(
        name: displayName.isNotEmpty ? displayName : 'Other',
        amount: entry.value,
        percentOfTotal: totalDebitSpending <= 0
            ? 0
            : ((entry.value * 100) ~/ totalDebitSpending),
      );
    }).toList()..sort((a, b) => b.amount.compareTo(a.amount));

    final highestCategoryEntry = categoryBreakdown.isEmpty
        ? null
        : categoryBreakdown.first;
    final highestSpendingCategory = highestCategoryEntry?.name;

    final trendPoints = _buildTrendPoints(filtered, selectedRange);
    final hasData =
        totalDebitSpending > 0 ||
        totalCredits > 0 ||
        debitTransactionCount > 0 ||
        creditTransactionCount > 0;

    return ReportsData(
      totalDebitSpending: totalDebitSpending,
      totalCredits: totalCredits,
      debitTransactionCount: debitTransactionCount,
      creditTransactionCount: creditTransactionCount,
      averageDebitAmount: averageDebitAmount,
      highestDebitAmount: highestDebitAmount,
      highestSpendingCategory: highestSpendingCategory,
      categoryBreakdown: categoryBreakdown,
      trendPoints: trendPoints,
      hasData: hasData,
    );
  }

  static List<TrendPoint> _buildTrendPoints(
    List<Expense> expenses,
    DateTimeRange range,
  ) {
    final debitExpenses = expenses
        .where((expense) => expense.type == ExpenseType.debit)
        .toList();
    final spanDays = range.end.difference(range.start).inDays + 1;

    if (spanDays <= 1) {
      final buckets = <String, int>{};
      for (var hour = 0; hour < 24; hour += 4) {
        buckets['${hour.toString().padLeft(2, '0')}:00'] = 0;
      }

      for (final expense in debitExpenses) {
        if (expense.date == null) continue;
        final hour = expense.date!.hour;
        final bucket = '${(hour ~/ 4 * 4).toString().padLeft(2, '0')}:00';
        buckets[bucket] = (buckets[bucket] ?? 0) + expense.amount;
      }

      return buckets.entries
          .map(
            (entry) => TrendPoint(
              label: entry.key,
              shortLabel: entry.key,
              amount: entry.value,
            ),
          )
          .toList(growable: false);
    }

    final buckets = <String, int>{};
    final step = spanDays <= 14 ? 1 : 7;
    if (step == 1) {
      for (var i = 0; i < spanDays; i++) {
        final day = range.start.add(Duration(days: i));
        final key = DateFormat.Md().format(day);
        buckets[key] = 0;
      }
      for (final expense in debitExpenses) {
        final date = expense.date;
        if (date == null) continue;
        final label = DateFormat.Md().format(date);
        buckets[label] = (buckets[label] ?? 0) + expense.amount;
      }
      return buckets.entries
          .map(
            (entry) => TrendPoint(
              label: entry.key,
              shortLabel: entry.key,
              amount: entry.value,
            ),
          )
          .toList(growable: false);
    }

    final totalWeeks = ((spanDays + 6) ~/ 7);
    for (var index = 0; index < totalWeeks; index++) {
      final label = 'W${index + 1}';
      buckets[label] = 0;
    }

    for (final expense in debitExpenses) {
      final date = expense.date;
      if (date == null) continue;
      final weekIndex = ((date.difference(range.start).inDays) / 7).floor();
      final label = 'W${weekIndex + 1}';
      buckets[label] = (buckets[label] ?? 0) + expense.amount;
    }

    return buckets.entries
        .map(
          (entry) => TrendPoint(
            label: entry.key,
            shortLabel: entry.key,
            amount: entry.value,
          ),
        )
        .toList(growable: false);
  }

  static DateTime _startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

class CategoryBreakdownEntry {
  const CategoryBreakdownEntry({
    required this.name,
    required this.amount,
    required this.percentOfTotal,
  });

  final String name;
  final int amount;
  final int percentOfTotal;
}

class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.shortLabel,
    required this.amount,
  });

  final String label;
  final String shortLabel;
  final int amount;
}
