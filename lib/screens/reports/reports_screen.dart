import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/icon_data_helper.dart';
import '../../providers/category_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/custom_chart.dart';
import '../../widgets/empty_state.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  ExpenseProvider? _expenseProvider;
  bool _isPieChart = true;

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
    final provider = Provider.of<ExpenseProvider>(context);
    if (_expenseProvider != provider) {
      _expenseProvider?.removeListener(_onExpenseChanged);
      _expenseProvider = provider;
      _expenseProvider?.addListener(_onExpenseChanged);
    }
  }

  @override
  void dispose() {
    _expenseProvider?.removeListener(_onExpenseChanged);
    super.dispose();
  }

  void _onExpenseChanged() {
    if (mounted) {
      _loadReports(showLoadingIndicator: false);
    }
  }

  void _loadReports({bool showLoadingIndicator = false}) {
    if (!mounted) return;
    final categories = context.read<CategoryProvider>().categories;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportsProvider = context.watch<ReportsProvider>();
    final settings = context.watch<SettingsProvider>();

    final currency = settings.currencySymbol;
    final summary = reportsProvider.summary;

    final selMonth = reportsProvider.selectedMonth;
    final now = DateTime.now();
    final isCurrentMonth = (selMonth.year == now.year && selMonth.month == now.month);

    final topCategory = summary?.topCategory;
    final hasNoData = summary == null ||
        (summary.totalSpentMinor == 0 &&
            summary.totalIncomeMinor == 0 &&
            summary.categoryBreakdown.isEmpty);

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

                // Available Years Dropdown (Slightly larger to show full year text)
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

          // 2. MAIN REPORTS CONTENT / EMPTY STATE
          Expanded(
            child: reportsProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasNoData
                    ? const EmptyStateWidget(
                        title: 'No Data Available',
                        description: 'No income or expense records found for this month.',
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SECTION 1: TOTAL INCOME AND TOTAL SPENDINGS TAB
                            Card(
                              elevation: 0,
                              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Total Income Box
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF10B981)),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'Total Income',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    CurrencyFormatter.formatPaise(summary.totalIncomeMinor, symbol: currency),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // Total Spendings Box
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFEF4444)),
                                                    SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        'Total Spendings',
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    CurrencyFormatter.formatPaise(summary.totalSpentMinor, symbol: currency),
                                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFEF4444)),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // SECTION 2: PIE CHART TAB
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
                                        // Icon-Only Segmented Toggle Button for Pie & Donut Chart
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

                                    // Pie / Donut Chart Render
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

                            // SECTION 3: CATEGORIES BREAKDOWN LIST (IMMEDIATELY BELOW PIE CHART)
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

                            // SECTION 4: TOP EXPENSE CATEGORY CARD
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

                            // SECTION 5: SPENDING INSIGHTS CARD
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
                      ),
          ),
        ],
      ),
    );
  }
}
