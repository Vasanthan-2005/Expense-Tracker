import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/reports_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/empty_state.dart';
import '../expense/add_edit_expense_modal.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key});

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<ExpenseProvider>().setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final categoryProvider = context.watch<CategoryProvider>();

    final currency = settings.currencySymbol;
    final categories = categoryProvider.categories;
    final expenses = expenseProvider.expenses;

    // Flatten expenses into header & transaction items for 100% lazy ListView virtualization
    final List<_HistoryListItem> flatItems = [];
    final Map<String, List<Expense>> groupedExpenses = {};
    for (final exp in expenses) {
      final dateKey = DateFormatter.formatRelativeDate(exp.date);
      groupedExpenses.putIfAbsent(dateKey, () => []).add(exp);
    }

    groupedExpenses.forEach((dateHeader, dayExpenses) {
      final dayTotalPaise = dayExpenses.fold<int>(0, (sum, item) => sum + item.amountMinorUnits);
      flatItems.add(_DateHeaderItem(dateHeader, dayTotalPaise));
      for (final exp in dayExpenses) {
        flatItems.add(_ExpenseEntryItem(exp));
      }
    });

    final hasActiveFilters = expenseProvider.searchQuery.isNotEmpty ||
        expenseProvider.selectedCategoryIds.isNotEmpty ||
        expenseProvider.startDate != null;

    return Scaffold(
      appBar: AppBar(
        title: _isSearchVisible
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search note or category...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
              )
            : const Text('Expense History'),
        actions: [
          IconButton(
            icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearchVisible) {
                  _searchController.clear();
                  expenseProvider.setSearchQuery('');
                }
                _isSearchVisible = !_isSearchVisible;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Icons.swap_vert,
              color: expenseProvider.oldestFirst ? theme.colorScheme.primary : null,
            ),
            tooltip: expenseProvider.oldestFirst ? 'Oldest First' : 'Newest First',
            onPressed: () => expenseProvider.toggleSortOrder(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Dashboard-Matched Month Switcher Bar with From-To Date Range Picker
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    final prev = DateTime(expenseProvider.selectedMonth.year, expenseProvider.selectedMonth.month - 1, 1);
                    expenseProvider.setSelectedMonth(prev);
                    context.read<ReportsProvider>().setSelectedMonth(prev);
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expenseProvider.selectedMonth,
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
                            expenseProvider.startDate != null && expenseProvider.endDate != null
                                ? '${DateFormatter.formatRelativeDate(expenseProvider.startDate!)} - ${DateFormatter.formatRelativeDate(expenseProvider.endDate!)}'
                                : DateFormatter.formatMonthYear(expenseProvider.selectedMonth),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: expenseProvider.startDate != null ? theme.colorScheme.primary : null,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Select From - To Date Range',
                      onPressed: () {
                        _showCustomDateRangeModal(
                          context: context,
                          initialStart: expenseProvider.startDate ?? expenseProvider.selectedMonth,
                          initialEnd: expenseProvider.endDate ?? DateTime.now(),
                          onApply: (start, end) {
                            expenseProvider.setDateRange(start, end);
                            if (context.mounted) {
                              context.read<ReportsProvider>().setCustomDateRange(start, end);
                            }
                          },
                        );
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: (expenseProvider.selectedMonth.year == DateTime.now().year && expenseProvider.selectedMonth.month == DateTime.now().month)
                            ? theme.disabledColor
                            : null,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      tooltip: 'Next Month',
                      onPressed: (expenseProvider.selectedMonth.year == DateTime.now().year && expenseProvider.selectedMonth.month == DateTime.now().month)
                          ? null
                          : () {
                              final next = DateTime(expenseProvider.selectedMonth.year, expenseProvider.selectedMonth.month + 1, 1);
                              expenseProvider.setSelectedMonth(next);
                              context.read<ReportsProvider>().setSelectedMonth(next);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Category Filter Chips Carousel
          if (categories.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length + 1,
                itemBuilder: (ctx, idx) {
                  if (idx == 0) {
                    final isAll = expenseProvider.selectedCategoryIds.isEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All Categories'),
                        selected: isAll,
                        onSelected: (_) => expenseProvider.clearCategoryFilter(),
                      ),
                    );
                  }

                  final cat = categories[idx - 1];
                  final isSelected = expenseProvider.selectedCategoryIds.contains(cat.id);
                  final catColor = Color(cat.colorValue);

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(cat.iconData, size: 14, color: isSelected ? Colors.white : catColor),
                      label: Text(cat.name),
                      selected: isSelected,
                      selectedColor: catColor,
                      onSelected: (_) => expenseProvider.toggleCategoryFilter(cat.id!),
                    ),
                  );
                },
              ),
            ),

          // Active Filters Reset Bar
          if (hasActiveFilters)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters Active (${expenses.length} found)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _searchController.clear();
                      expenseProvider.clearAllFilters();
                    },
                    child: Text(
                      'Clear Filters',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Grouped Transaction List
          Expanded(
            child: expenseProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : flatItems.isEmpty
                    ? EmptyStateWidget(
                        title: 'No Expenses in ${DateFormatter.formatMonthYear(expenseProvider.selectedMonth)}',
                        description: hasActiveFilters
                            ? 'Try adjusting or clearing your search and filter criteria.'
                            : 'No expense transactions recorded for this month.',
                        actionLabel: hasActiveFilters ? 'Clear Filters' : 'Add Expense',
                        onAction: () {
                          if (hasActiveFilters) {
                            _searchController.clear();
                            expenseProvider.clearAllFilters();
                          } else {
                            AddEditExpenseModal.show(context);
                          }
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: flatItems.length,
                        itemBuilder: (ctx, idx) {
                          final item = flatItems[idx];

                          if (item is _DateHeaderItem) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.dateHeader,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(item.totalPaise, symbol: currency),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          } else if (item is _ExpenseEntryItem) {
                            final exp = item.expense;
                            final category = categoryProvider.getCategoryById(exp.categoryId);
                            return ExpenseTile(
                              key: ValueKey('history_tile_${exp.id}'),
                              expense: exp,
                              category: category,
                              currencySymbol: currency,
                              onTap: () => AddEditExpenseModal.show(context, existingExpense: exp),
                              onDelete: () async {
                                await expenseProvider.deleteExpense(exp.id!);
                                if (context.mounted) {
                                  context.read<ReportsProvider>().loadReportSummary(
                                    categories: categoryProvider.categories,
                                    currencySymbol: currency,
                                    showLoadingIndicator: false,
                                  );
                                }
                              },
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

abstract class _HistoryListItem {}

class _DateHeaderItem extends _HistoryListItem {
  final String dateHeader;
  final int totalPaise;
  _DateHeaderItem(this.dateHeader, this.totalPaise);
}

class _ExpenseEntryItem extends _HistoryListItem {
  final Expense expense;
  _ExpenseEntryItem(this.expense);
}
