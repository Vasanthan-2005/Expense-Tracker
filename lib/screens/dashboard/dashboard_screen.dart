import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/account_provider.dart';
import '../../models/account.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/empty_state.dart';
import '../expense/add_edit_expense_modal.dart';

import '../../core/database/database_helper.dart';
import '../../widgets/celebration/month_end_celebration_modal.dart';
import 'calendar_view_modal.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onViewAllHistory;

  const DashboardScreen({super.key, required this.onViewAllHistory});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _checkedAutoCelebration = false;
  Map<String, dynamic>? _monthBudgetPerformance;
  Map<int, int> _historicalAccountBalances = {};
  int? _lastEvaluatedYear;
  int? _lastEvaluatedMonth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAutoMonthEndCelebration();
    });
  }

  Future<void> _checkAutoMonthEndCelebration() async {
    final settings = context.read<SettingsProvider>();
    if (!settings.isCelebrationEnabled) return;
    if (_checkedAutoCelebration || !mounted) return;
    _checkedAutoCelebration = true;

    final now = DateTime.now();

    // Only show celebration on the 1st and 2nd day of the current month
    if (now.day != 1 && now.day != 2) return;

    // Check previous completed month
    final prevMonthDate = DateTime(now.year, now.month - 1, 1);
    final prevMonthKey = "${prevMonthDate.year}-${prevMonthDate.month.toString().padLeft(2, '0')}";

    if (settings.lastCelebratedMonth != prevMonthKey) {
      try {
        final summary = await DatabaseHelper.instance.getMonthBudgetPerformance(
          year: prevMonthDate.year,
          month: prevMonthDate.month,
          overallBudgetPaise: settings.overallMonthlyBudgetPaise,
        );

        final hasData = summary['hasData'] == true;
        // Do not celebrate if no proper data was recorded in the previous month
        if (!hasData) return;

        final isQualified = summary['isCelebrationQualified'] == true;
        final hasBudgets = (summary['budgetedCategoriesCount'] as int? ?? 0) > 0 || settings.isOverallBudgetSet;
        final shouldShow = isQualified || (!settings.isPositiveOnlyCelebration && hasBudgets);

        if (shouldShow && mounted) {
          await settings.setLastCelebratedMonth(prevMonthKey);
          if (mounted) {
            MonthEndCelebrationModal.show(
              context,
              year: prevMonthDate.year,
              month: prevMonthDate.month,
              totalSpentPaise: summary['totalSpentPaise'] as int,
              overallBudgetPaise: summary['overallBudgetPaise'] as int?,
              overallSavedPaise: summary['overallSavedPaise'] as int,
              categoryBreakdown: summary['categoryBreakdown'] as List<Map<String, dynamic>>,
              currencySymbol: settings.currencySymbol,
              isQualified: isQualified,
            );
          }
        }
      } catch (e) {
        debugPrint('Error evaluating auto celebration: $e');
      }
    }
  }

  Future<void> _refreshData(BuildContext context) async {
    await Future.wait([
      context.read<ExpenseProvider>().refreshAll(),
      context.read<AccountProvider>().refreshAccounts(),
    ]);
    _evaluateSelectedMonthPerformance();
  }

  Future<void> _evaluateSelectedMonthPerformance() async {
    final selMonth = context.read<ExpenseProvider>().selectedMonth;
    final settings = context.read<SettingsProvider>();
    final now = DateTime.now();
    final isCurrent = selMonth.year == now.year && selMonth.month == now.month;

    try {
      final summaryFuture = DatabaseHelper.instance.getMonthBudgetPerformance(
        year: selMonth.year,
        month: selMonth.month,
        overallBudgetPaise: settings.overallMonthlyBudgetPaise,
      );

      final histBalancesFuture = isCurrent
          ? Future.value(<int, int>{})
          : DatabaseHelper.instance.getAccountClosingBalancesForMonth(selMonth.year, selMonth.month);

      final results = await Future.wait([summaryFuture, histBalancesFuture]);

      if (mounted) {
        setState(() {
          _monthBudgetPerformance = results[0] as Map<String, dynamic>;
          _historicalAccountBalances = results[1] as Map<int, int>;
          _lastEvaluatedYear = selMonth.year;
          _lastEvaluatedMonth = selMonth.month;
        });
      }
    } catch (e) {
      debugPrint('Error evaluating month budget performance: $e');
    }
  }

  Future<void> _showCelebrationForSelectedMonth(BuildContext context, int year, int month) async {
    final settings = context.read<SettingsProvider>();
    final summary = await DatabaseHelper.instance.getMonthBudgetPerformance(
      year: year,
      month: month,
      overallBudgetPaise: settings.overallMonthlyBudgetPaise,
    );

    if (context.mounted) {
      MonthEndCelebrationModal.show(
        context,
        year: year,
        month: month,
        totalSpentPaise: summary['totalSpentPaise'] as int,
        overallBudgetPaise: summary['overallBudgetPaise'] as int?,
        overallSavedPaise: summary['overallSavedPaise'] as int,
        categoryBreakdown: summary['categoryBreakdown'] as List<Map<String, dynamic>>,
        currencySymbol: settings.currencySymbol,
        isQualified: summary['isCelebrationQualified'] == true,
      );
    }
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final accountProvider = context.watch<AccountProvider>();

    final currency = settings.currencySymbol;
    final recentExpenses = expenseProvider.expenses.take(10).toList();
    final accounts = accountProvider.accounts;
    final selMonth = expenseProvider.selectedMonth;
    final monthName = _monthNames[selMonth.month - 1];
    final now = DateTime.now();
    final isCurrentMonth = selMonth.year == now.year && selMonth.month == now.month;

    if (_lastEvaluatedYear != selMonth.year || _lastEvaluatedMonth != selMonth.month) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _evaluateSelectedMonthPerformance();
      });
    }

    final hasOverallBudget = settings.isOverallBudgetSet;
    final overallBudgetPaise = settings.overallMonthlyBudgetPaise ?? 0;
    final monthSpentPaise = expenseProvider.monthTotalPaise;
    final int remainingBudgetPaise = overallBudgetPaise - monthSpentPaise;
    final double overallBudgetProgress = overallBudgetPaise > 0
        ? (monthSpentPaise / overallBudgetPaise.toDouble()).clamp(0.0, 1.0)
        : 0.0;

    final isCelebrationQualified = _monthBudgetPerformance != null &&
        _monthBudgetPerformance!['isCelebrationQualified'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance_wallet, color: theme.colorScheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            const Text('Expense Tracker'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Financial Calendar',
            onPressed: () => CalendarViewModal.show(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshData(context),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Standardized Slightly Compact Month Switcher Bar
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        final prev = DateTime(selMonth.year, selMonth.month - 1, 1);
                        expenseProvider.setSelectedMonth(prev);
                        context.read<ReportsProvider>().setSelectedMonth(prev);
                      },
                      tooltip: 'Previous Month',
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selMonth,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            expenseProvider.setSelectedMonth(picked);
                            if (context.mounted) {
                              context.read<ReportsProvider>().setSelectedMonth(picked);
                            }
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$monthName ${selMonth.year}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: isCurrentMonth ? theme.disabledColor : null,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: isCurrentMonth ? null : () {
                        final next = DateTime(selMonth.year, selMonth.month + 1, 1);
                        expenseProvider.setSelectedMonth(next);
                        context.read<ReportsProvider>().setSelectedMonth(next);
                      },
                      tooltip: 'Next Month',
                    ),
                  ],
                ),
              ),

              Builder(
                builder: (context) {
                  final dashboardAccounts = accounts.where((acc) {
                    final n = acc.name.toLowerCase();
                    return acc.isDefault || n.contains('cash') || n.contains('expense');
                  }).toList();

                  if (!settings.isAccountsSectionEnabled || dashboardAccounts.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  int getAccountBalance(Account acc) {
                    if (isCurrentMonth) {
                      return accountProvider.getAccountBalancePaise(acc.id!);
                    } else {
                      return _historicalAccountBalances[acc.id!] ?? accountProvider.getAccountBalancePaise(acc.id!);
                    }
                  }

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      if (dashboardAccounts.length == 1)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 240,
                              height: 88,
                              child: _buildAccountCard(
                                context,
                                dashboardAccounts[0],
                                getAccountBalance(dashboardAccounts[0]),
                                currency,
                                isCurrentMonth: isCurrentMonth,
                                monthLabel: monthName,
                              ),
                            ),
                          ),
                        )
                      else if (dashboardAccounts.length == 2)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SizedBox(
                            height: 88,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildAccountCard(
                                    context,
                                    dashboardAccounts[0],
                                    getAccountBalance(dashboardAccounts[0]),
                                    currency,
                                    isCurrentMonth: isCurrentMonth,
                                    monthLabel: monthName,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAccountCard(
                                    context,
                                    dashboardAccounts[1],
                                    getAccountBalance(dashboardAccounts[1]),
                                    currency,
                                    isCurrentMonth: isCurrentMonth,
                                    monthLabel: monthName,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: SizedBox(
                            height: 84,
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildAccountCard(
                                    context,
                                    dashboardAccounts[0],
                                    getAccountBalance(dashboardAccounts[0]),
                                    currency,
                                    isCompact: true,
                                    isCurrentMonth: isCurrentMonth,
                                    monthLabel: monthName,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildAccountCard(
                                    context,
                                    dashboardAccounts[1],
                                    getAccountBalance(dashboardAccounts[1]),
                                    currency,
                                    isCompact: true,
                                    isCurrentMonth: isCurrentMonth,
                                    monthLabel: monthName,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Celebratory Banner (shown when past month expenses had proper data and were within all budget limits)
              if (isCelebrationQualified && !isCurrentMonth)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Budget Champion for $monthName!',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'All expenses stayed within budget limit 🎉',
                                style: TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          onPressed: () => _showCelebrationForSelectedMonth(context, selMonth.year, selMonth.month),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFFB45309),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Celebrate! 🏆', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Spending Metric Hero Card (Monthly Basis)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${monthName.toUpperCase()} SPENDING',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text('$monthName ${selMonth.year}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            CurrencyFormatter.formatPaise(monthSpentPaise, symbol: currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),

                          // Overall Budget Progress (if configured)
                          if (hasOverallBudget) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: overallBudgetProgress,
                                minHeight: 6,
                                backgroundColor: Colors.white24,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  overallBudgetProgress < 0.8
                                      ? Colors.white
                                      : (overallBudgetProgress <= 1.0 ? Colors.amberAccent : Colors.redAccent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Budget: ${CurrencyFormatter.formatPaise(overallBudgetPaise, symbol: currency)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  remainingBudgetPaise >= 0
                                      ? '${CurrencyFormatter.formatPaise(remainingBudgetPaise, symbol: currency)} left'
                                      : '${CurrencyFormatter.formatPaise(-remainingBudgetPaise, symbol: currency)} over',
                                  style: TextStyle(
                                    color: remainingBudgetPaise >= 0 ? Colors.white : Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Today & Week Cards Row (Only shown when viewing Current Month)
                    if (selMonth.year == DateTime.now().year && selMonth.month == DateTime.now().month) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricSubCard(
                              title: 'Today',
                              amount: CurrencyFormatter.formatPaise(expenseProvider.todayTotalPaise, symbol: currency),
                              icon: Icons.today,
                              color: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricSubCard(
                              title: 'This Week',
                              amount: CurrencyFormatter.formatPaise(expenseProvider.weekTotalPaise, symbol: currency),
                              icon: Icons.calendar_view_week,
                              color: const Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Recent Expenses Section Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$monthName Expenses',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onViewAllHistory,
                      child: const Row(
                        children: [
                          Text('View All'),
                          Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Recent Expenses List
              if (expenseProvider.isLoading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (recentExpenses.isEmpty)
                EmptyStateWidget(
                  title: 'No Expenses for $monthName',
                  description: 'Tap below to log an expense for $monthName ${selMonth.year}.',
                  actionLabel: 'Add Expense',
                  onAction: () => AddEditExpenseModal.show(context),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentExpenses.length,
                  itemBuilder: (ctx, idx) {
                    final expense = recentExpenses[idx];
                    final category = categoryProvider.getCategoryById(expense.categoryId);

                    return ExpenseTile(
                      expense: expense,
                      category: category,
                      currencySymbol: currency,
                      onTap: () => AddEditExpenseModal.show(context, existingExpense: expense),
                      onDelete: () async {
                        await expenseProvider.deleteExpense(expense.id!);
                        if (context.mounted) {
                          await context.read<AccountProvider>().refreshAccounts();
                        }
                        if (context.mounted) {
                          context.read<ReportsProvider>().loadReportSummary(
                            categories: categoryProvider.categories,
                            currencySymbol: currency,
                            showLoadingIndicator: false,
                          );
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(
    BuildContext context,
    Account acc,
    int balPaise,
    String currency, {
    bool isCompact = false,
    bool isCurrentMonth = true,
    String? monthLabel,
  }) {
    final theme = Theme.of(context);
    final accColor = Color(acc.colorValue);

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: acc.isDefault ? accColor : theme.dividerColor.withValues(alpha: 0.5),
          width: acc.isDefault ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 4 : 6),
                decoration: BoxDecoration(
                  color: accColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(acc.iconData, color: accColor, size: isCompact ? 14 : 16),
              ),
              SizedBox(width: isCompact ? 6 : 8),
              Expanded(
                child: Text(
                  acc.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isCompact ? 12 : 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isCurrentMonth && monthLabel != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$monthLabel End',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatPaise(balPaise, symbol: currency),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 13 : 16,
                color: balPaise >= 0 ? accColor : theme.colorScheme.error,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricSubCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _MetricSubCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              amount,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
