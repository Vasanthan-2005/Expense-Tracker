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

import 'calendar_view_modal.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onViewAllHistory;

  const DashboardScreen({super.key, required this.onViewAllHistory});

  Future<void> _refreshData(BuildContext context) async {
    await Future.wait([
      context.read<ExpenseProvider>().refreshAll(),
      context.read<AccountProvider>().refreshAccounts(),
    ]);
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
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Totals',
            onPressed: () => _refreshData(context),
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
                              child: _buildAccountCard(context, dashboardAccounts[0], accountProvider.getAccountBalancePaise(dashboardAccounts[0].id!), currency),
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
                                  child: _buildAccountCard(context, dashboardAccounts[0], accountProvider.getAccountBalancePaise(dashboardAccounts[0].id!), currency),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildAccountCard(context, dashboardAccounts[1], accountProvider.getAccountBalancePaise(dashboardAccounts[1].id!), currency),
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
                                  child: _buildAccountCard(context, dashboardAccounts[0], accountProvider.getAccountBalancePaise(dashboardAccounts[0].id!), currency, isCompact: true),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildAccountCard(context, dashboardAccounts[1], accountProvider.getAccountBalancePaise(dashboardAccounts[1].id!), currency, isCompact: true),
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
                            CurrencyFormatter.formatPaise(expenseProvider.monthTotalPaise, symbol: currency),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
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
                      onPressed: onViewAllHistory,
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

  Widget _buildAccountCard(BuildContext context, Account acc, int liveBalPaise, String currency, {bool isCompact = false}) {
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
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyFormatter.formatPaise(liveBalPaise, symbol: currency),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 13 : 16,
                color: liveBalPaise >= 0 ? accColor : theme.colorScheme.error,
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
