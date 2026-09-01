import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/user_avatar_widget.dart';
import '../../models/budget.dart';
import '../../models/expense.dart';
import '../../providers/budget_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/user_profile_provider.dart';
import 'calendar_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    final budgetAsync = ref.watch(budgetProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartSpend'),
        actions: [
          IconButton(
            onPressed: () => context.go('/profile'),
            icon: UserAvatarWidget(
              avatarId: profile?.avatar,
              radius: 14,
              showBorder: true,
              borderColor: Theme.of(context).colorScheme.primary,
            ),
            tooltip: 'Profile',
          ),
          IconButton(
            onPressed: () => context.go('/expenses'),
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'All expenses',
          ),
        ],
      ),
      body: SafeArea(
        child: expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _DashboardErrorState(
            onAddExpense: () => context.go('/add'),
            onViewExpenses: () => context.go('/expenses'),
          ),
          data: (expenses) {
            final headerCard = _HeaderCard(
              displayName: profile?.safeDisplayName ?? 'SmartSpend',
              avatarId: profile?.avatar,
              onViewExpenses: () => context.go('/expenses'),
            );

            if (expenses.isEmpty) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Column(
                  children: [
                    headerCard,
                    const SizedBox(height: 20),
                    _EmptyDashboardState(
                      onAddExpense: () => context.go('/add'),
                      onViewExpenses: () => context.go('/expenses'),
                    ),
                  ],
                ),
              );
            }

            final metrics = _DashboardMetrics.fromExpenses(expenses);
            final insights = DashboardInsightsData.fromExpenses(expenses);
            final budget = budgetAsync.maybeWhen(
              data: (value) => value,
              orElse: () => null,
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerCard,
                  const SizedBox(height: 20),
                  _SummaryCard(
                    title: 'Current month expenses',
                    value: formatMinorUnits(metrics.currentMonthExpenses),
                    subtitle: 'This month',
                    accent: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth;
                      final itemWidth = (availableWidth - 12) / 2;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Expenses',
                              value: formatMinorUnits(metrics.totalExpenses),
                              icon: Icons.arrow_upward_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Credits',
                              value: formatMinorUnits(metrics.totalCredits),
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'This month',
                              value: formatMinorUnits(
                                metrics.currentMonthCredits,
                              ),
                              icon: Icons.savings_outlined,
                              subLabel: 'Credits',
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _MetricCard(
                              label: 'Transactions',
                              value: '${metrics.transactionCount}',
                              icon: Icons.receipt_long_outlined,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Spending by category',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _CategorySummary(categories: metrics.categoryBreakdown),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Debit distribution',
                    child: insights.hasDebitData
                        ? RepaintBoundary(
                            child: _CategorySpendingChart(
                              categories: insights.categoryBreakdown,
                            ),
                          )
                        : const _EmptyChartState(
                            message: 'No debit spending data yet.',
                          ),
                  ),
                  const SizedBox(height: 20),
                  _ChartCard(
                    title: 'Monthly spending',
                    child: insights.hasDebitData
                        ? RepaintBoundary(
                            child: SizedBox(
                              height: 220,
                              child: _MonthlySpendingChart(
                                points: insights.monthlyBreakdown,
                              ),
                            ),
                          )
                        : const _EmptyChartState(
                            message:
                                'No spending records for the recent months.',
                          ),
                  ),
                  const SizedBox(height: 20),
                  RepaintBoundary(
                    child: CalendarCard(
                      expenses: expenses,
                      onDateSelected: (date) {
                        // Could be used to filter expenses by date
                        // For now, just tracking the selection
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _BudgetCard(
                    budget: budget,
                    currentMonthSpending: metrics.currentMonthExpenses,
                    onSetBudget: () =>
                        _showSetBudgetDialog(context, ref, budget),
                  ),
                  const SizedBox(height: 12),
                  if (budget != null)
                    _BudgetStatusAlert(
                      budget: budget,
                      currentMonthSpending: metrics.currentMonthExpenses,
                    ),
                  const SizedBox(height: 20),
                  _InsightsCard(data: insights),
                  const SizedBox(height: 20),
                  _DebitCreditComparisonCard(
                    debitTotal: insights.currentMonthDebitTotal,
                    creditTotal: insights.currentMonthCreditTotal,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent transactions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/expenses'),
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _RecentTransactionsList(
                    transactions: metrics.recentTransactions,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.onViewExpenses,
    this.displayName = 'SmartSpend',
    this.avatarId,
  });

  final VoidCallback onViewExpenses;
  final String displayName;
  final String? avatarId;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayName.isNotEmpty ? displayName : 'SmartSpend',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.onPrimary.withValues(alpha: 0.8),
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: UserAvatarWidget(
                  avatarId: avatarId,
                  radius: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onViewExpenses,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colors.onPrimary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: colors.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View expenses',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: colors.onPrimary.withValues(alpha: 0.8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.subLabel,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? subLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: colors.primary),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                subLabel!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategorySummary extends StatelessWidget {
  const _CategorySummary({required this.categories});

  final List<CategoryTotal> categories;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAmount = categories.first.amount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: categories.map((entry) {
          final progress = maxAmount <= 0
              ? 0.0
              : (entry.amount / maxAmount).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatMinorUnits(entry.amount),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

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
        mainAxisSize: MainAxisSize.min,
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

class _EmptyChartState extends StatelessWidget {
  const _EmptyChartState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _CategorySpendingChart extends StatelessWidget {
  const _CategorySpendingChart({required this.categories});

  final List<CategoryTotal> categories;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final palette = <Color>[
      colors.primary,
      colors.secondary,
      colors.tertiary,
      colors.primaryContainer,
      colors.secondaryContainer,
    ];

    final sections = categories.asMap().entries.map((entry) {
      final category = entry.value;
      return PieChartSectionData(
        value: category.amount.toDouble(),
        color: categoryColorForKey(category.name, palette: palette),
        radius: 36,
        title: '',
      );
    }).toList();

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: categories.asMap().entries.map((entry) {
        final category = entry.value;
        final chipColor = categoryColorForKey(category.name, palette: palette);

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  category.name,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatMinorUnits(category.amount),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      }).toList(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useRowLayout = constraints.maxWidth >= 380;
        final chartSize = (constraints.maxWidth * 0.42)
            .clamp(120.0, 160.0)
            .toDouble();

        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 20,
              startDegreeOffset: -90,
              sections: sections,
            ),
          ),
        );

        if (useRowLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              const SizedBox(width: 16),
              Expanded(child: legend),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(height: 12),
            legend,
          ],
        );
      },
    );
  }
}

class _MonthlySpendingChart extends StatelessWidget {
  const _MonthlySpendingChart({required this.points});

  final List<MonthlySpendingEntry> points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final maxAmount = points.fold<int>(0, (previousValue, entry) {
      return entry.amount > previousValue ? entry.amount : previousValue;
    });

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = points.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.amount.toDouble());
    }).toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxAmount <= 0 ? 1 : (maxAmount * 1.15).toDouble(),
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipRoundedRadius: 10,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  final entry = points[index];
                  return LineTooltipItem(
                    '${entry.label}\n${formatMinorUnits(entry.amount)}',
                    const TextStyle(fontWeight: FontWeight.w600),
                  );
                }).toList();
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
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    points[index].label,
                    style: Theme.of(context).textTheme.labelSmall,
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              color: colors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: colors.primary,
                    strokeWidth: 0,
                  );
                },
              ),
              belowBarData: BarAreaData(show: false),
              spots: spots,
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.data});

  final DashboardInsightsData data;

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
            'Spending insights',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (!data.hasDebitData)
            const _EmptyChartState(
              message: 'No debit activity to summarize yet.',
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _InsightTile(
                        label: 'Highest category',
                        value: data.highestSpendingCategory ?? 'N/A',
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _InsightTile(
                        label: 'Current month',
                        value: formatMinorUnits(data.currentMonthDebitTotal),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _InsightTile(
                        label: 'Avg. debit',
                        value: formatMinorUnits(data.averageDebitAmount),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _InsightTile(
                        label: 'Debit count',
                        value: '${data.debitTransactionCount}',
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _DebitCreditComparisonCard extends StatelessWidget {
  const _DebitCreditComparisonCard({
    required this.debitTotal,
    required this.creditTotal,
  });

  final int debitTotal;
  final int creditTotal;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = debitTotal + creditTotal;
    final debitRatio = total <= 0 ? 0.0 : (debitTotal / total).clamp(0.0, 1.0);

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
            'Debit vs credit',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ComparisonMetric(
                  label: 'Debit',
                  value: formatMinorUnits(debitTotal),
                  color: colors.primary,
                  ratio: debitRatio,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonMetric(
                  label: 'Credit',
                  value: formatMinorUnits(creditTotal),
                  color: colors.secondary,
                  ratio: total <= 0
                      ? 0.0
                      : (creditTotal / total).clamp(0.0, 1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComparisonMetric extends StatelessWidget {
  const _ComparisonMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.ratio,
  });

  final String label;
  final String value;
  final Color color;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentTransactionsList extends StatelessWidget {
  const _RecentTransactionsList({required this.transactions});

  final List<Expense> transactions;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: transactions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final expense = transactions[index];
        final isDebit = expense.type == ExpenseType.debit;

        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            onTap: () => context.go('/add', extra: expense),
            leading: CircleAvatar(
              backgroundColor: isDebit
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                isDebit
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isDebit
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
            title: Text(
              expense.merchant ?? expense.category ?? 'Expense',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              [
                expense.category,
                expense.date != null
                    ? DateFormat.yMMMd().format(expense.date!)
                    : null,
              ].whereType<String>().join(' • '),
            ),
            trailing: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isDebit ? '-' : '+'}${formatMinorUnits(expense.amount)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDebit
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  isDebit ? 'Debit' : 'Credit',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.currentMonthSpending,
    required this.onSetBudget,
  });

  final MonthlyBudget? budget;
  final int currentMonthSpending;
  final VoidCallback onSetBudget;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentMonthlyBudget = budget?.monthlyLimitMinorUnits ?? 0;
    final remaining = currentMonthlyBudget - currentMonthSpending;
    final exceeded =
        budget != null && currentMonthSpending > currentMonthlyBudget;
    final statusLabel = budget == null
        ? 'No budget set'
        : exceeded
        ? 'Budget exceeded'
        : currentMonthSpending >= currentMonthlyBudget
        ? 'Reached limit'
        : 'On track';

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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Monthly budget',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              TextButton.icon(
                onPressed: onSetBudget,
                icon: const Icon(Icons.edit_outlined),
                label: Text(budget == null ? 'Set budget' : 'Update'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (budget == null)
            Text(
              'No monthly budget configured yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Budget limit',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatMinorUnits(currentMonthlyBudget),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Spent so far',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  formatMinorUnits(currentMonthSpending),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: currentMonthlyBudget <= 0
                    ? 0.0
                    : (currentMonthSpending / currentMonthlyBudget).clamp(
                        0.0,
                        1.0,
                      ),
                minHeight: 10,
                backgroundColor: colors.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  exceeded ? colors.error : colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exceeded
                        ? 'Budget exceeded by ${formatMinorUnits((currentMonthSpending - currentMonthlyBudget).abs())}'
                        : 'Remaining ${formatMinorUnits(remaining)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: exceeded ? colors.error : colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: exceeded ? colors.error : colors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _showSetBudgetDialog(
  BuildContext context,
  WidgetRef ref,
  MonthlyBudget? existingBudget,
) async {
  final controller = TextEditingController(
    text: existingBudget == null
        ? ''
        : (existingBudget.monthlyLimitMinorUnits / 100).toStringAsFixed(2),
  );
  final repository = ref.read(budgetRepositoryProvider);
  var isSubmitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              existingBudget == null
                  ? 'Set monthly budget'
                  : 'Update monthly budget',
            ),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter your monthly spending cap in INR.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. 25000.00',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final rawValue = controller.text.trim();
                        if (rawValue.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Enter a budget amount greater than zero.',
                              ),
                            ),
                          );
                          return;
                        }

                        final parsed = double.tryParse(rawValue);
                        if (parsed == null || parsed <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Budget must be above ₹0.00.'),
                            ),
                          );
                          return;
                        }

                        final minorUnits = (parsed * 100).round();
                        if (minorUnits <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Budget must be above ₹0.00.'),
                            ),
                          );
                          return;
                        }

                        setState(() => isSubmitting = true);

                        try {
                          await repository.upsertBudget(
                            monthlyLimitMinorUnits: minorUnits,
                          );
                          ref.invalidate(budgetProvider);
                          if (context.mounted) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Monthly budget saved.'),
                              ),
                            );
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unable to save budget: $error'),
                              ),
                            );
                          }
                        } finally {
                          if (context.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        existingBudget == null
                            ? 'Save budget'
                            : 'Update budget',
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}

enum BudgetStatus { onTrack, approachingLimit, limitReached, exceeded }

class BudgetSummary {
  const BudgetSummary({
    required this.monthlyBudget,
    required this.currentMonthDebitTotal,
    required this.remainingMinorUnits,
    required this.spentRatio,
    required this.isExceeded,
    required this.status,
    required this.statusLabel,
    required this.alertMessage,
  });

  final int monthlyBudget;
  final int currentMonthDebitTotal;
  final int remainingMinorUnits;
  final double spentRatio;
  final bool isExceeded;
  final BudgetStatus status;
  final String statusLabel;
  final String alertMessage;

  static BudgetSummary fromExpensesAndBudget(
    List<Expense> expenses, {
    required int monthlyBudget,
    DateTime? referenceTime,
  }) {
    final reference = referenceTime ?? DateTime.now();
    final currentMonthDebitTotal = expenses
        .where(
          (expense) =>
              expense.type == ExpenseType.debit &&
              isCurrentMonth(expense.date, reference),
        )
        .fold<int>(0, (sum, expense) => sum + expense.amount);

    return fromCurrentMonthSpending(
      currentMonthSpending: currentMonthDebitTotal,
      monthlyBudget: monthlyBudget,
    );
  }

  static BudgetSummary fromCurrentMonthSpending({
    required int currentMonthSpending,
    required int monthlyBudget,
  }) {
    final remaining = monthlyBudget - currentMonthSpending;
    final ratio = monthlyBudget <= 0
        ? 0.0
        : currentMonthSpending / monthlyBudget;
    final isExceeded =
        monthlyBudget > 0 && currentMonthSpending > monthlyBudget;

    final status = monthlyBudget <= 0
        ? BudgetStatus.onTrack
        : isExceeded
        ? BudgetStatus.exceeded
        : currentMonthSpending * 100 >= monthlyBudget * 80 &&
              currentMonthSpending * 100 < monthlyBudget * 100
        ? BudgetStatus.approachingLimit
        : currentMonthSpending == monthlyBudget
        ? BudgetStatus.limitReached
        : BudgetStatus.onTrack;

    final label = monthlyBudget <= 0
        ? 'No budget set'
        : status == BudgetStatus.exceeded
        ? 'Budget exceeded'
        : status == BudgetStatus.limitReached
        ? 'Reached limit'
        : status == BudgetStatus.approachingLimit
        ? 'Approaching limit'
        : 'On track';

    final alertMessage = monthlyBudget <= 0
        ? ''
        : status == BudgetStatus.approachingLimit
        ? 'You\'ve used ${_percentageLabel(currentMonthSpending, monthlyBudget)}% of your monthly budget.'
        : status == BudgetStatus.limitReached
        ? 'You\'ve reached your monthly budget.'
        : status == BudgetStatus.exceeded
        ? 'You\'ve exceeded your monthly budget by ${formatMinorUnits((currentMonthSpending - monthlyBudget).abs())}.'
        : '';

    return BudgetSummary(
      monthlyBudget: monthlyBudget,
      currentMonthDebitTotal: currentMonthSpending,
      remainingMinorUnits: remaining,
      spentRatio: ratio,
      isExceeded: isExceeded,
      status: status,
      statusLabel: label,
      alertMessage: alertMessage,
    );
  }

  static String _percentageLabel(int spending, int budget) {
    if (budget <= 0) return '0';
    return ((spending * 100) / budget).round().toString();
  }
}

class _BudgetStatusAlert extends StatelessWidget {
  const _BudgetStatusAlert({
    required this.budget,
    required this.currentMonthSpending,
  });

  final MonthlyBudget budget;
  final int currentMonthSpending;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final currentSummary = BudgetSummary.fromCurrentMonthSpending(
      currentMonthSpending: currentMonthSpending,
      monthlyBudget: budget.monthlyLimitMinorUnits,
    );

    final alert = currentSummary.alertMessage;
    if (alert.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExceeded = currentSummary.status == BudgetStatus.exceeded;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExceeded ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded ? colors.error : colors.primary,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isExceeded
                ? Icons.warning_amber_rounded
                : Icons.info_outline_rounded,
            color: isExceeded
                ? colors.onErrorContainer
                : colors.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isExceeded
                    ? colors.onErrorContainer
                    : colors.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardErrorState extends StatelessWidget {
  const _DashboardErrorState({
    required this.onAddExpense,
    required this.onViewExpenses,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onViewExpenses;

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
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(
                  'We could not load your dashboard right now.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please try again in a moment or continue with a manual entry.',
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

class _EmptyDashboardState extends StatelessWidget {
  const _EmptyDashboardState({
    required this.onAddExpense,
    required this.onViewExpenses,
  });

  final VoidCallback onAddExpense;
  final VoidCallback onViewExpenses;

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
                  Icons.bar_chart_outlined,
                  size: 50,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  'No transactions yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first expense to start tracking spending and cash flow.',
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
                      label: const Text('View expenses'),
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

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.totalExpenses,
    required this.totalCredits,
    required this.currentMonthExpenses,
    required this.currentMonthCredits,
    required this.transactionCount,
    required this.recentTransactions,
    required this.categoryBreakdown,
  });

  final int totalExpenses;
  final int totalCredits;
  final int currentMonthExpenses;
  final int currentMonthCredits;
  final int transactionCount;
  final List<Expense> recentTransactions;
  final List<CategoryTotal> categoryBreakdown;

  static _DashboardMetrics fromExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    final monthExpenses = expenses.where(
      (expense) =>
          expense.type == ExpenseType.debit &&
          isCurrentMonth(expense.date, now),
    );
    final monthCredits = expenses.where(
      (expense) =>
          expense.type == ExpenseType.credit &&
          isCurrentMonth(expense.date, now),
    );

    final categoryMap = <String, int>{};
    for (final expense in expenses) {
      final categoryKey = normalizeCategoryKey(expense.category);
      if (expense.type == ExpenseType.debit && categoryKey.isNotEmpty) {
        final normalizedName = normalizeCategoryName(expense.category);
        categoryMap[normalizedName] =
            (categoryMap[normalizedName] ?? 0) + expense.amount;
      }
    }

    final categoryBreakdown =
        categoryMap.entries
            .map((entry) => CategoryTotal(name: entry.key, amount: entry.value))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    return _DashboardMetrics(
      totalExpenses: _sumByType(expenses, ExpenseType.debit),
      totalCredits: _sumByType(expenses, ExpenseType.credit),
      currentMonthExpenses: _sumByType(monthExpenses, ExpenseType.debit),
      currentMonthCredits: _sumByType(monthCredits, ExpenseType.credit),
      transactionCount: expenses.length,
      recentTransactions: getRecentTransactions(expenses, limit: 3),
      categoryBreakdown: categoryBreakdown,
    );
  }

  static int _sumByType(Iterable<Expense> expenses, ExpenseType type) {
    var total = 0;
    for (final expense in expenses) {
      if (expense.type == type) {
        total += expense.amount;
      }
    }
    return total;
  }
}

List<Expense> getRecentTransactions(List<Expense> expenses, {int limit = 3}) {
  final sortedExpenses = [...expenses]
    ..sort((a, b) {
      final aDate = a.date ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.date ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = bDate.compareTo(aDate);
      if (dateCompare != 0) return dateCompare;
      final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bCreated.compareTo(aCreated);
    });
  return sortedExpenses.take(limit).toList(growable: false);
}

bool isCurrentMonth(DateTime? date, DateTime reference) {
  if (date == null) return false;
  return date.year == reference.year && date.month == reference.month;
}

class DashboardInsightsData {
  const DashboardInsightsData({
    required this.categoryBreakdown,
    required this.monthlyBreakdown,
    required this.currentMonthDebitTotal,
    required this.currentMonthCreditTotal,
    required this.averageDebitAmount,
    required this.debitTransactionCount,
    required this.highestSpendingCategory,
  });

  final List<CategoryTotal> categoryBreakdown;
  final List<MonthlySpendingEntry> monthlyBreakdown;
  final int currentMonthDebitTotal;
  final int currentMonthCreditTotal;
  final int averageDebitAmount;
  final int debitTransactionCount;
  final String? highestSpendingCategory;

  bool get hasDebitData => debitTransactionCount > 0;

  static DashboardInsightsData fromExpenses(
    List<Expense> expenses, {
    DateTime? referenceTime,
  }) {
    final reference = referenceTime ?? DateTime.now();
    final debitTransactions = expenses
        .where((expense) => expense.type == ExpenseType.debit)
        .toList();
    final currentMonthDebit = expenses.where(
      (expense) =>
          expense.type == ExpenseType.debit &&
          isCurrentMonth(expense.date, reference),
    );
    final currentMonthCredit = expenses.where(
      (expense) =>
          expense.type == ExpenseType.credit &&
          isCurrentMonth(expense.date, reference),
    );

    final categoryMap = <String, int>{};
    for (final expense in debitTransactions) {
      final categoryKey = normalizeCategoryKey(expense.category);
      if (categoryKey.isEmpty) {
        continue;
      }
      final normalizedName = normalizeCategoryName(expense.category);
      categoryMap[normalizedName] =
          (categoryMap[normalizedName] ?? 0) + expense.amount;
    }

    final categoryBreakdown =
        categoryMap.entries
            .map((entry) => CategoryTotal(name: entry.key, amount: entry.value))
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));

    final monthlyBreakdown = <MonthlySpendingEntry>[];
    for (var monthOffset = 5; monthOffset >= 0; monthOffset--) {
      final monthDate = DateTime(
        reference.year,
        reference.month - monthOffset,
        1,
      );
      final monthTotal = debitTransactions
          .where((expense) {
            final expenseDate = expense.date;
            return expenseDate != null &&
                expenseDate.year == monthDate.year &&
                expenseDate.month == monthDate.month;
          })
          .fold<int>(0, (sum, expense) => sum + expense.amount);

      monthlyBreakdown.add(
        MonthlySpendingEntry(
          label: DateFormat.MMM().format(monthDate),
          amount: monthTotal,
        ),
      );
    }

    final totalDebitAmount = debitTransactions.fold<int>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final debitCount = debitTransactions.length;

    return DashboardInsightsData(
      categoryBreakdown: categoryBreakdown,
      monthlyBreakdown: monthlyBreakdown,
      currentMonthDebitTotal: currentMonthDebit.fold<int>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      currentMonthCreditTotal: currentMonthCredit.fold<int>(
        0,
        (sum, expense) => sum + expense.amount,
      ),
      averageDebitAmount: debitCount == 0 ? 0 : totalDebitAmount ~/ debitCount,
      debitTransactionCount: debitCount,
      highestSpendingCategory: categoryBreakdown.isEmpty
          ? null
          : categoryBreakdown.first.name,
    );
  }
}

class MonthlySpendingEntry {
  const MonthlySpendingEntry({required this.label, required this.amount});

  final String label;
  final int amount;
}

class CategoryTotal {
  const CategoryTotal({required this.name, required this.amount});

  final String name;
  final int amount;
}
