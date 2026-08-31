import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/database_helper.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/expense.dart';
import '../../models/income.dart';
import '../../models/transfer.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';

class CalendarViewModal extends StatefulWidget {
  const CalendarViewModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const CalendarViewModal(),
    );
  }

  @override
  State<CalendarViewModal> createState() => _CalendarViewModalState();
}

class _CalendarViewModalState extends State<CalendarViewModal> {
  DateTime _focusedMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();

  Map<String, Map<String, int>> _monthlyTotals = {};
  List<Expense> _dayExpenses = [];
  List<Income> _dayIncomes = [];
  List<Transfer> _dayTransfers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    try {
      final totals = await DatabaseHelper.instance.getMonthlyDailyTotals(
        _focusedMonth.year,
        _focusedMonth.month,
      );
      if (mounted) {
        setState(() {
          _monthlyTotals = totals;
        });
        await _loadSelectedDayDetails();
      }
    } catch (e) {
      debugPrint('Error loading calendar month data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSelectedDayDetails() async {
    final db = DatabaseHelper.instance;
    final expenses = await db.getExpenses(startDate: _selectedDate, endDate: _selectedDate);
    final incomes = await db.getIncomes();
    final transfers = await db.getTransfers();

    final dateIso = DateFormatter.formatDateIso(_selectedDate);
    final dayInc = incomes.where((i) => DateFormatter.formatDateIso(i.date) == dateIso).toList();
    final dayTr = transfers.where((t) => DateFormatter.formatDateIso(t.date) == dateIso).toList();

    if (mounted) {
      setState(() {
        _dayExpenses = expenses;
        _dayIncomes = dayInc;
        _dayTransfers = dayTr;
      });
    }
  }

  void _changeMonth(int increment) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + increment, 1);

    if (newMonth.year > now.year || (newMonth.year == now.year && newMonth.month > now.month)) {
      return;
    }

    setState(() {
      _focusedMonth = newMonth;
      if (_selectedDate.month != _focusedMonth.month || _selectedDate.year != _focusedMonth.year) {
        final lastDayOfNewMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
        final targetDay = _selectedDate.day.clamp(1, lastDayOfNewMonth);
        var candidateDate = DateTime(_focusedMonth.year, _focusedMonth.month, targetDay);
        if (candidateDate.isAfter(today)) {
          candidateDate = today;
        }
        _selectedDate = candidateDate;
      }
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final categoryProvider = context.watch<CategoryProvider>();
    final currency = settings.currencySymbol;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentOrFutureMonth = (_focusedMonth.year > now.year) ||
        (_focusedMonth.year == now.year && _focusedMonth.month >= now.month);

    final monthName = _getMonthName(_focusedMonth.month);
    final yearStr = _focusedMonth.year.toString();

    // Days in month calculation
    final daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday; // 1 = Mon, 7 = Sun

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Header handle & title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Financial Calendar',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Month Navigation Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '$monthName $yearStr',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right,
                  color: isCurrentOrFutureMonth ? theme.disabledColor : null,
                ),
                onPressed: isCurrentOrFutureMonth ? null : () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Weekday Labels Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayLabel('Mon'),
              _WeekdayLabel('Tue'),
              _WeekdayLabel('Wed'),
              _WeekdayLabel('Thu'),
              _WeekdayLabel('Fri'),
              _WeekdayLabel('Sat'),
              _WeekdayLabel('Sun'),
            ],
          ),
          const SizedBox(height: 8),

          // Month Grid View
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.82,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: (firstWeekday - 1) + daysInMonth,
                      itemBuilder: (ctx, idx) {
                        if (idx < firstWeekday - 1) {
                          return const SizedBox.shrink();
                        }

                        final dayNum = idx - (firstWeekday - 1) + 1;
                        final date = DateTime(_focusedMonth.year, _focusedMonth.month, dayNum);
                        final isFutureDay = date.isAfter(today);
                        final dateIso = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

                        final dayTotals = _monthlyTotals[dateIso];
                        final expensePaise = dayTotals?['expense'] ?? 0;
                        final incomePaise = dayTotals?['income'] ?? 0;

                        final isSelected = _selectedDate.year == date.year &&
                            _selectedDate.month == date.month &&
                            _selectedDate.day == date.day;
                        final isToday = today.year == date.year &&
                            today.month == date.month &&
                            today.day == date.day;

                        return InkWell(
                          onTap: isFutureDay
                              ? null
                              : () {
                                  setState(() {
                                    _selectedDate = date;
                                  });
                                  _loadSelectedDayDetails();
                                },
                          borderRadius: BorderRadius.circular(10),
                          child: Opacity(
                            opacity: isFutureDay ? 0.35 : 1.0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                                    : isToday
                                        ? theme.colorScheme.primary.withValues(alpha: 0.05)
                                        : theme.cardColor,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : isToday
                                          ? theme.colorScheme.primary.withValues(alpha: 0.4)
                                          : theme.dividerColor.withValues(alpha: 0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$dayNum',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : isFutureDay
                                              ? theme.disabledColor
                                              : null,
                                    ),
                                  ),
                                Column(
                                  children: [
                                    if (incomePaise > 0)
                                      Text(
                                        '+${_formatCompact(incomePaise)}',
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF10B981),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (expensePaise > 0)
                                      Text(
                                        '-${_formatCompact(expensePaise)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.error,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                               ],
                             ),
                           ),
                         ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Selected Day Details Header & Breakdown
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormatter.formatDateFull(_selectedDate),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_dayExpenses.length + _dayIncomes.length + _dayTransfers.length} transactions',
                            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    if (_dayExpenses.isEmpty && _dayIncomes.isEmpty && _dayTransfers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No transactions recorded on this day.', style: TextStyle(color: Colors.grey)),
                      )
                    else ...[
                      // Incomes List
                      ..._dayIncomes.map((inc) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_downward, color: Color(0xFF10B981), size: 18),
                            ),
                            title: Text(inc.sourceOrNote ?? 'Income', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Time: ${inc.timeString}'),
                            trailing: Text(
                              '+${CurrencyFormatter.formatPaise(inc.amountMinorUnits, symbol: currency)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 15),
                            ),
                          )),

                      // Expenses List
                      ..._dayExpenses.map((exp) {
                        final cat = categoryProvider.getCategoryById(exp.categoryId);
                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (cat != null ? Color(cat.colorValue) : theme.colorScheme.error).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(cat?.iconData ?? Icons.receipt, color: cat != null ? Color(cat.colorValue) : theme.colorScheme.error, size: 18),
                          ),
                          title: Text(exp.note?.isNotEmpty == true ? exp.note! : (cat?.name ?? 'Expense'), style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Category: ${cat?.name ?? "Other"} • ${exp.timeString}'),
                          trailing: Text(
                            '-${CurrencyFormatter.formatPaise(exp.amountMinorUnits, symbol: currency)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.error, fontSize: 15),
                          ),
                        );
                      }),

                      // Transfers List
                      ..._dayTransfers.map((tr) => ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.swap_horiz, color: Color(0xFF6366F1), size: 18),
                            ),
                            title: Text(tr.note?.isNotEmpty == true ? tr.note! : 'Transfer', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Time: ${tr.timeString}'),
                            trailing: Text(
                              CurrencyFormatter.formatPaise(tr.amountMinorUnits, symbol: currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1), fontSize: 15),
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCompact(int paise) {
    final major = (paise / 100.0).round();
    if (major >= 1000) {
      return '${(major / 1000).toStringAsFixed(1)}k';
    }
    return '$major';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;

  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
      ),
    );
  }
}
