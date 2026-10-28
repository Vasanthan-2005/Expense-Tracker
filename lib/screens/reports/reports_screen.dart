import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/icon_data_helper.dart';
import '../../models/report_summary.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_chart.dart';
import '../../widgets/empty_state.dart';
import '../income/add_edit_income_modal.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ExpenseProvider? _expenseProvider;
  AccountProvider? _accountProvider;
  bool _isPieChart = true;
  String _selectedReportType = 'expense'; // 'expense', 'income', 'transfer'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReports(showLoadingIndicator: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final expenseProv = Provider.of<ExpenseProvider>(context);
    if (_expenseProvider != expenseProv) {
      _expenseProvider?.removeListener(_onDataChanged);
      _expenseProvider = expenseProv;
      _expenseProvider?.addListener(_onDataChanged);
    }
    final accountProv = Provider.of<AccountProvider>(context);
    if (_accountProvider != accountProv) {
      _accountProvider?.removeListener(_onDataChanged);
      _accountProvider = accountProv;
      _accountProvider?.addListener(_onDataChanged);
    }
  }

  @override
  void dispose() {
    _expenseProvider?.removeListener(_onDataChanged);
    _accountProvider?.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) {
      _loadReports(showLoadingIndicator: false);
    }
  }

  void _loadReports({bool showLoadingIndicator = false}) {
    if (!mounted) return;
    final allCats = context.read<CategoryProvider>().allCategories;
    final categories = allCats.isNotEmpty
        ? allCats
        : context.read<CategoryProvider>().categories;
    final currency = context.read<SettingsProvider>().currencySymbol;
    context.read<ReportsProvider>().loadReportSummary(
          categories: categories,
          currencySymbol: currency,
          showLoadingIndicator: showLoadingIndicator,
        );
  }

  Future<void> _showCustomDateRangeModal({
    required BuildContext context,
    required DateTime initialStart,
    required DateTime initialEnd,
    required Function(DateTime start, DateTime end) onApply,
  }) async {
    DateTime selStart = initialStart;
    DateTime selEnd = initialEnd;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final theme = Theme.of(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.date_range_rounded, color: Color(0xFF6366F1)),
                SizedBox(width: 10),
                Text('Select Date Range', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selStart,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selStart = picked;
                        if (selEnd.isBefore(selStart)) selEnd = selStart;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('From Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(DateFormatter.formatRelativeDate(selStart), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selEnd,
                      firstDate: selStart,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selEnd = picked;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_available, size: 18, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('To Date', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(DateFormatter.formatRelativeDate(selEnd), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onApply(selStart, selEnd);
                },
                child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCategoryExpensesBottomSheet(
    BuildContext context,
    int categoryId,
    String categoryName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final theme = Theme.of(context);
    final currency = context.read<SettingsProvider>().currencySymbol;

    final expenses = await DatabaseHelper.instance.getExpenses(
      categoryIds: [categoryId],
      startDate: startDate,
      endDate: endDate,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    categoryName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${expenses.length} transaction${expenses.length == 1 ? "" : "s"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: expenses.isEmpty
                    ? const Center(child: Text('No expenses recorded for this category.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: expenses.length,
                        itemBuilder: (ctx, idx) {
                          final exp = expenses[idx];
                          final noteStr = (exp.note != null && exp.note!.trim().isNotEmpty) ? exp.note!.trim() : categoryName;
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(
                              noteStr,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(DateFormatter.formatRelativeDate(exp.date)),
                            trailing: Text(
                              CurrencyFormatter.formatPaise(exp.amountMinorUnits, symbol: currency),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryIncomesBottomSheet(
    BuildContext context,
    int categoryId,
    String categoryName,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final theme = Theme.of(context);
    final currency = context.read<SettingsProvider>().currencySymbol;
    final accountProvider = context.read<AccountProvider>();
    final accountMap = {for (final a in accountProvider.accounts) if (a.id != null) a.id!: a.name};

    final incomes = await DatabaseHelper.instance.getIncomesByCategory(
      categoryId: categoryId,
      startDate: startDate,
      endDate: endDate,
    );

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    categoryName,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${incomes.length} transaction${incomes.length == 1 ? "" : "s"}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: incomes.isEmpty
                    ? const Center(child: Text('No income recorded for this category.'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: incomes.length,
                        itemBuilder: (ctx, idx) {
                          final inc = incomes[idx];
                          final noteStr = (inc.sourceOrNote != null && inc.sourceOrNote!.trim().isNotEmpty) ? inc.sourceOrNote!.trim() : categoryName;
                          final accountName = accountMap[inc.accountId] ?? 'Account';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            title: Text(
                              noteStr,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('${DateFormatter.formatRelativeDate(inc.date)} • $accountName'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.formatPaise(inc.amountMinorUnits, symbol: currency),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                                  tooltip: 'Delete Income',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  onPressed: () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('Delete Income Record?'),
                                        content: const Text(
                                          'This income transaction will be deleted and your live account balance will be updated automatically.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dCtx, false),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                            onPressed: () => Navigator.pop(dCtx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmed == true && context.mounted) {
                                      await context.read<AccountProvider>().deleteIncome(inc.id!);
                                      if (context.mounted) {
                                        _loadReports(showLoadingIndicator: false);
                                        Navigator.pop(ctx);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Income record deleted.')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () async {
                              Navigator.pop(ctx);
                              await AddEditIncomeScreen.show(context, existingIncome: inc);
                              if (context.mounted) {
                                _loadReports(showLoadingIndicator: false);
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpenseReportView(
    ThemeData theme,
    ReportSummary summary,
    String currency,
    ReportsProvider reportsProvider,
  ) {
    final topCategory = summary.topCategory;
    final hasNoExpenses = summary.totalSpentMinor == 0 && summary.categoryBreakdown.isEmpty;

    if (hasNoExpenses) {
      return const EmptyStateWidget(
        title: 'No Expenses Found',
        description: 'No expense records found for this period.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Spendings Card
          Card(
            elevation: 0,
            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFFEF4444), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Spendings',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.formatPaise(summary.totalSpentMinor, symbol: currency),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFFEF4444)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${summary.categoryBreakdown.length} categories',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category Breakdown Chart (Pie / Donut)
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Category Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.pie_chart_rounded, size: 16),
                            tooltip: 'Pie Chart',
                          ),
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.donut_large_rounded, size: 16),
                            tooltip: 'Donut Chart',
                          ),
                        ],
                        selected: {_isPieChart},
                        onSelectionChanged: (val) {
                          setState(() {
                            _isPieChart = val.first;
                          });
                        },
                        style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: _isPieChart
                        ? CategoryPieChart(
                            categories: summary.categoryBreakdown,
                            currencySymbol: currency,
                            size: 200,
                          )
                        : CategoryDonutChart(
                            categories: summary.categoryBreakdown,
                            currencySymbol: currency,
                            size: 200,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Categories Breakdown List
          if (summary.categoryBreakdown.isNotEmpty) ...[
            Text(
              'CATEGORIES BREAKDOWN (${summary.categoryBreakdown.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...summary.categoryBreakdown.map((catSpend) {
              final color = Color(catSpend.colorValue);
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showCategoryExpensesBottomSheet(
                    context,
                    catSpend.categoryId,
                    catSpend.categoryName,
                    reportsProvider.activeStartDate,
                    reportsProvider.activeEndDate,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            IconDataHelper.getIcon(catSpend.iconCodePoint, fallback: Icons.category),
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                catSpend.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: (catSpend.percentage / 100.0).clamp(0.0, 1.0),
                                backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                                color: color,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaise(catSpend.totalMinorUnits, symbol: currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${catSpend.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Top Expense Category Card
          if (topCategory != null) ...[
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Top Expense Category',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(topCategory.colorValue).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconDataHelper.getIcon(topCategory.iconCodePoint, fallback: Icons.star),
                            color: Color(topCategory.colorValue),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topCategory.categoryName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${topCategory.percentage.toStringAsFixed(1)}% of total spent',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(topCategory.totalMinorUnits, symbol: currency),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Color(topCategory.colorValue),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Spending Insights Card
          if (summary.insights.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Spending Insights',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...summary.insights.map((insight) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                            Expanded(
                              child: Text(
                                insight.message,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIncomeReportView(
    ThemeData theme,
    ReportSummary summary,
    String currency,
    ReportsProvider reportsProvider,
  ) {
    final topIncome = summary.topIncomeCategory;
    final hasNoIncome = summary.totalIncomeMinor == 0 && summary.incomeCategoryBreakdown.isEmpty;

    if (hasNoIncome) {
      return const EmptyStateWidget(
        title: 'No Income Found',
        description: 'No income records found for this period.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Income Card
          Card(
            elevation: 0,
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Income',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.formatPaise(summary.totalIncomeMinor, symbol: currency),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${summary.incomeCategoryBreakdown.length} categories',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category Breakdown Chart (Pie / Donut)
          if (summary.incomeCategoryBreakdown.isNotEmpty) ...[
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Income Breakdown',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment<bool>(
                              value: true,
                              icon: Icon(Icons.pie_chart_rounded, size: 16),
                              tooltip: 'Pie Chart',
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: Icon(Icons.donut_large_rounded, size: 16),
                              tooltip: 'Donut Chart',
                            ),
                          ],
                          selected: {_isPieChart},
                          onSelectionChanged: (val) {
                            setState(() {
                              _isPieChart = val.first;
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: _isPieChart
                          ? CategoryPieChart(
                              categories: summary.incomeCategoryBreakdown,
                              currencySymbol: currency,
                              size: 200,
                            )
                          : CategoryDonutChart(
                              categories: summary.incomeCategoryBreakdown,
                              currencySymbol: currency,
                              size: 200,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Income Categories Breakdown List
            Text(
              'INCOME CATEGORIES (${summary.incomeCategoryBreakdown.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 12),
            ...summary.incomeCategoryBreakdown.map((catSpend) {
              final color = Color(catSpend.colorValue);
              return Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showCategoryIncomesBottomSheet(
                    context,
                    catSpend.categoryId,
                    catSpend.categoryName,
                    reportsProvider.activeStartDate,
                    reportsProvider.activeEndDate,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            IconDataHelper.getIcon(catSpend.iconCodePoint, fallback: Icons.account_balance_wallet_rounded),
                            color: color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                catSpend.categoryName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              LinearProgressIndicator(
                                value: (catSpend.percentage / 100.0).clamp(0.0, 1.0),
                                backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                                color: color,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              CurrencyFormatter.formatPaise(catSpend.totalMinorUnits, symbol: currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                            ),
                            Text(
                              '${catSpend.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // Top Income Category Card
          if (topIncome != null) ...[
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Top Income Source',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(topIncome.colorValue).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            IconDataHelper.getIcon(topIncome.iconCodePoint, fallback: Icons.account_balance_wallet_rounded),
                            color: Color(topIncome.colorValue),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topIncome.categoryName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${topIncome.percentage.toStringAsFixed(1)}% of total income',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatPaise(topIncome.totalMinorUnits, symbol: currency),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransferReportView(
    ThemeData theme,
    ReportSummary summary,
    String currency,
    ReportsProvider reportsProvider,
    AccountProvider accountProvider,
  ) {
    final transfers = summary.periodTransfers;

    if (transfers.isEmpty) {
      return const EmptyStateWidget(
        title: 'No Transfers Found',
        description: 'No account transfers recorded for this period.',
      );
    }

    final accountMap = {for (final a in accountProvider.accounts) if (a.id != null) a.id!: a.name};

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Total Transfers Summary Card
          Card(
            elevation: 0,
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total Transferred',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            CurrencyFormatter.formatPaise(summary.totalTransferMinor, symbol: currency),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Color(0xFF6366F1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${summary.transferCount} transaction${summary.transferCount == 1 ? "" : "s"}',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Transfers List Header
          Text(
            'TRANSFERS HISTORY (${transfers.length})',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),

          // Transfers List
          ...transfers.map((tr) {
            final fromName = accountMap[tr.fromAccountId] ?? 'Account ${tr.fromAccountId}';
            final toName = accountMap[tr.toAccountId] ?? 'Account ${tr.toAccountId}';
            final dateStr = DateFormatter.formatRelativeDate(tr.date);
            final timeStr = tr.timeString.isNotEmpty ? ' • ${tr.timeString}' : '';
            final noteStr = (tr.note != null && tr.note!.trim().isNotEmpty) ? tr.note!.trim() : null;

            return Card(
              elevation: 0,
              color: theme.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.4)),
              ),
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  fromName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                              ),
                              Flexible(
                                child: Text(
                                  toName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$dateStr$timeStr${noteStr != null ? " • $noteStr" : ""}',
                            style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.formatPaise(tr.amountMinorUnits, symbol: currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportsProvider = context.watch<ReportsProvider>();
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();

    final currency = settings.currencySymbol;
    final summary = reportsProvider.summary;

    final selMonth = reportsProvider.selectedMonth;
    final now = DateTime.now();
    final isCurrentMonth = (selMonth.year == now.year && selMonth.month == now.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterChip(
                  showCheckmark: false,
                  selected: reportsProvider.periodType == ReportPeriodType.monthly,
                  label: Text(
                    'Month',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: reportsProvider.periodType == ReportPeriodType.monthly
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (selected) {
                    if (selected) {
                      reportsProvider.setSelectedMonth(reportsProvider.selectedMonth);
                      context.read<ExpenseProvider>().setSelectedMonth(reportsProvider.selectedMonth);
                    }
                  },
                ),
                const SizedBox(width: 4),
                FilterChip(
                  showCheckmark: false,
                  avatar: Icon(
                    Icons.history_toggle_off,
                    size: 14,
                    color: reportsProvider.periodType == ReportPeriodType.last6Months
                        ? Colors.white
                        : theme.colorScheme.primary,
                  ),
                  selected: reportsProvider.periodType == ReportPeriodType.last6Months,
                  label: Text(
                    'Last 6M',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: reportsProvider.periodType == ReportPeriodType.last6Months
                          ? Colors.white
                          : theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  selectedColor: theme.colorScheme.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  onSelected: (selected) {
                    if (selected) reportsProvider.setLast6Months();
                  },
                ),
                const SizedBox(width: 4),

                // Available Years Dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: (reportsProvider.periodType == ReportPeriodType.year ||
                            reportsProvider.periodType == ReportPeriodType.thisYear ||
                            reportsProvider.periodType == ReportPeriodType.previousYear)
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: (reportsProvider.periodType == ReportPeriodType.year ||
                              reportsProvider.periodType == ReportPeriodType.thisYear ||
                              reportsProvider.periodType == ReportPeriodType.previousYear)
                          ? reportsProvider.selectedYear
                          : null,
                      hint: Text(
                        'Year ▾',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: (reportsProvider.periodType == ReportPeriodType.year ||
                                  reportsProvider.periodType == ReportPeriodType.thisYear ||
                                  reportsProvider.periodType == ReportPeriodType.previousYear)
                              ? Colors.white
                              : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      icon: const SizedBox.shrink(),
                      dropdownColor: theme.cardColor,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color),
                      isDense: true,
                      onChanged: (year) {
                        if (year != null) {
                          reportsProvider.setSelectedYear(year);
                        }
                      },
                      items: reportsProvider.availableYears.map((yr) {
                        return DropdownMenuItem<int>(
                          value: yr,
                          child: Text('$yr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // From-To Date Range Picker Button
                IconButton(
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: reportsProvider.periodType == ReportPeriodType.customRange ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Select From - To Date Range',
                  onPressed: () {
                    _showCustomDateRangeModal(
                      context: context,
                      initialStart: reportsProvider.activeStartDate,
                      initialEnd: reportsProvider.activeEndDate.isAfter(now) ? now : reportsProvider.activeEndDate,
                      onApply: (start, end) {
                        reportsProvider.setCustomDateRange(start, end);
                      },
                    );
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. BELOW APP BAR: MONTH SWITCHER BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 40,
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
                    tooltip: 'Previous Month',
                    onPressed: () {
                      final prev = DateTime(selMonth.year, selMonth.month - 1, 1);
                      reportsProvider.setSelectedMonth(prev);
                      context.read<ExpenseProvider>().setSelectedMonth(prev);
                    },
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
                          reportsProvider.setSelectedMonth(picked);
                          if (context.mounted) {
                            context.read<ExpenseProvider>().setSelectedMonth(picked);
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
                              reportsProvider.periodType == ReportPeriodType.monthly
                                  ? DateFormatter.formatMonthYear(selMonth)
                                  : reportsProvider.periodTitle,
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
                    tooltip: 'Next Month',
                    onPressed: isCurrentMonth ? null : () {
                      final next = DateTime(selMonth.year, selMonth.month + 1, 1);
                      reportsProvider.setSelectedMonth(next);
                      context.read<ExpenseProvider>().setSelectedMonth(next);
                    },
                  ),
                ],
              ),
            ),
          ),

          // 2. REPORT TYPE SELECTOR (Expense, Income, Transfer)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment<String>(
                    value: 'expense',
                    label: Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    icon: Icon(Icons.arrow_upward_rounded, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'income',
                    label: Text('Income', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    icon: Icon(Icons.arrow_downward_rounded, size: 16),
                  ),
                  ButtonSegment<String>(
                    value: 'transfer',
                    label: Text('Transfer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    icon: Icon(Icons.swap_horiz_rounded, size: 16),
                  ),
                ],
                selected: {_selectedReportType},
                onSelectionChanged: (val) {
                  setState(() {
                    _selectedReportType = val.first;
                  });
                },
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),

          // 3. MAIN REPORTS CONTENT / EMPTY STATE
          Expanded(
            child: reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : summary == null
                    ? const EmptyStateWidget(
                        title: 'No Data Available',
                        description: 'No transaction records found for this period.',
                      )
                    : _selectedReportType == 'income'
                        ? _buildIncomeReportView(theme, summary, currency, reportsProvider)
                        : _selectedReportType == 'transfer'
                            ? _buildTransferReportView(theme, summary, currency, reportsProvider, accountProvider)
                            : _buildExpenseReportView(theme, summary, currency, reportsProvider),
          ),
        ],
      ),
    );
  }
}
