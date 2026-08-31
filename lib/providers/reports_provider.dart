import 'package:flutter/foundation.dart' hide Category;
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/report_summary.dart';
import '../core/database/database_helper.dart';
import '../services/insights_service.dart';

enum ReportPeriodType {
  monthly,
  last6Months,
  thisYear,
  previousYear,
  year,
  customRange,
}

class ReportsProvider with ChangeNotifier {
  bool _isDisposed = false;
  ReportPeriodType _periodType = ReportPeriodType.monthly;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _selectedYear = DateTime.now().year;
  List<int> _availableYears = [DateTime.now().year];
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  ReportSummary? _summary;
  bool _isLoading = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  ReportPeriodType get periodType => _periodType;
  DateTime get selectedMonth => _selectedMonth;
  int get selectedYear => _selectedYear;
  List<int> get availableYears => List.unmodifiable(_availableYears);
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  ReportSummary? get summary => _summary;
  bool get isLoading => _isLoading;

  String get periodTitle {
    final now = DateTime.now();
    switch (_periodType) {
      case ReportPeriodType.last6Months:
        final sixMonthsAgo = DateTime(now.year, now.month - 5, 1);
        return "Last 6 Months (${DateFormat('MMM yyyy').format(sixMonthsAgo)} – ${DateFormat('MMM yyyy').format(now)})";
      case ReportPeriodType.thisYear:
        return "This Year (${now.year})";
      case ReportPeriodType.previousYear:
        return "Previous Year (${now.year - 1})";
      case ReportPeriodType.year:
        return "Year $_selectedYear";
      case ReportPeriodType.customRange:
        if (_customStartDate != null && _customEndDate != null) {
          return "${DateFormat('d MMM yyyy').format(_customStartDate!)} – ${DateFormat('d MMM yyyy').format(_customEndDate!)}";
        }
        return "Custom Range";
      case ReportPeriodType.monthly:
        return DateFormat('MMMM yyyy').format(_selectedMonth);
    }
  }

  void setSelectedMonth(DateTime month) {
    _periodType = ReportPeriodType.monthly;
    final now = DateTime.now();
    final targetMonth = DateTime(month.year, month.month, 1);
    final maxMonth = DateTime(now.year, now.month, 1);

    if (targetMonth.isAfter(maxMonth)) {
      _selectedMonth = maxMonth;
    } else {
      _selectedMonth = targetMonth;
    }
    loadReportSummary();
  }

  void previousMonth() {
    _periodType = ReportPeriodType.monthly;
    setSelectedMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  void nextMonth() {
    _periodType = ReportPeriodType.monthly;
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    if (!next.isAfter(DateTime(now.year, now.month, 1))) {
      setSelectedMonth(next);
    }
  }

  void setLast6Months() {
    _periodType = ReportPeriodType.last6Months;
    loadReportSummary();
  }

  void setThisYear() {
    _periodType = ReportPeriodType.thisYear;
    loadReportSummary();
  }

  void setPreviousYear() {
    _periodType = ReportPeriodType.previousYear;
    loadReportSummary();
  }

  void setSelectedYear(int year) {
    _periodType = ReportPeriodType.year;
    _selectedYear = year;
    loadReportSummary();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    _periodType = ReportPeriodType.customRange;
    _customStartDate = DateTime(start.year, start.month, start.day);
    _customEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    loadReportSummary();
  }

  DateTime get activeStartDate {
    final now = DateTime.now();
    switch (_periodType) {
      case ReportPeriodType.last6Months:
        return DateTime(now.year, now.month - 5, 1);
      case ReportPeriodType.thisYear:
        return DateTime(now.year, 1, 1);
      case ReportPeriodType.previousYear:
        return DateTime(now.year - 1, 1, 1);
      case ReportPeriodType.year:
        return DateTime(_selectedYear, 1, 1);
      case ReportPeriodType.customRange:
        return _customStartDate ?? DateTime(now.year, now.month, 1);
      case ReportPeriodType.monthly:
        return DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    }
  }

  DateTime get activeEndDate {
    final now = DateTime.now();
    switch (_periodType) {
      case ReportPeriodType.last6Months:
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        return DateTime(now.year, now.month, lastDay, 23, 59, 59);
      case ReportPeriodType.thisYear:
        return DateTime(now.year, 12, 31, 23, 59, 59);
      case ReportPeriodType.previousYear:
        return DateTime(now.year - 1, 12, 31, 23, 59, 59);
      case ReportPeriodType.year:
        return DateTime(_selectedYear, 12, 31, 23, 59, 59);
      case ReportPeriodType.customRange:
        return _customEndDate ?? DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      case ReportPeriodType.monthly:
        final year = _selectedMonth.year;
        final month = _selectedMonth.month;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, lastDay, 23, 59, 59);
    }
  }

  Future<void> loadReportSummary({
    List<Category>? categories,
    String currencySymbol = '₹',
    bool showLoadingIndicator = false,
  }) async {
    if (showLoadingIndicator || _summary == null) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();

      final List<Category> activeCategories = categories ?? await db.getCategories();
      final catMap = {for (var c in activeCategories) c.id!: c};

      final startDate = activeStartDate;
      final endDate = activeEndDate;

      final durationDays = endDate.difference(startDate).inDays + 1;
      final prevStartDate = startDate.subtract(Duration(days: durationDays));
      final prevEndDate = startDate.subtract(const Duration(days: 1));

      final startIso = _formatIso(startDate);
      final endIso = _formatIso(endDate);
      final prevStartIso = _formatIso(prevStartDate);
      final prevEndIso = _formatIso(prevEndDate);

      final todayIso = _formatIso(now);

      final results = await Future.wait([
        db.getTotalPaiseForDateRange(todayIso, todayIso),
        db.getTotalPaiseForDateRange(startIso, endIso),
        db.getTotalPaiseForDateRange(prevStartIso, prevEndIso),
        db.getCategoryTotalsForDateRange(startIso, endIso),
        db.getCategoryTotalsForDateRange(prevStartIso, prevEndIso),
        db.getDailySpendTotals(startIso, endIso),
        db.getHighestSingleExpense(startIso, endIso),
        db.getTotalIncomePaiseForDateRange(startIso, endIso),
        db.getAvailableYears(),
      ]);

      final todayTotal = results[0] as int;
      final periodTotal = results[1] as int;
      final prevPeriodTotal = results[2] as int;
      final categoryTotals = results[3] as Map<int, int>;
      final prevCategoryTotals = results[4] as Map<int, int>;
      final dailySpendRows = results[5] as List<Map<String, dynamic>>;
      final highestMap = results[6] as Map<String, dynamic>?;
      final totalIncomePaise = results[7] as int;
      final yearsList = results[8] as List<int>;

      _availableYears = yearsList.isNotEmpty ? yearsList : [DateTime.now().year];
      if (!_availableYears.contains(_selectedYear)) {
        _selectedYear = _availableYears.first;
      }

      // 1. Calculate Category Breakdown
      final List<CategorySpend> categoryBreakdown = [];
      categoryTotals.forEach((catId, total) {
        final cat = catMap[catId];
        if (cat != null) {
          final pct = periodTotal > 0 ? (total / periodTotal.toDouble()) * 100 : 0.0;
          categoryBreakdown.add(CategorySpend(
            categoryId: catId,
            categoryName: cat.name,
            colorValue: cat.colorValue,
            iconCodePoint: cat.iconCodePoint,
            iconFontFamily: cat.iconFontFamily,
            totalMinorUnits: total,
            percentage: pct,
            expenseCount: 0,
          ));
        }
      });
      categoryBreakdown.sort((a, b) => b.totalMinorUnits.compareTo(a.totalMinorUnits));

      // 2. Calculate Daily Trends for Line Chart
      final Map<String, int> dailySpendMap = {};
      for (final row in dailySpendRows) {
        dailySpendMap[row['date'] as String] = (row['total'] as int?) ?? 0;
      }

      final List<TrendDataPoint> trends = [];
      final daysCount = durationDays.clamp(1, 365);
      for (int i = 0; i < daysCount; i++) {
        final date = startDate.add(Duration(days: i));
        if (date.isAfter(endDate)) break;
        final dateIso = _formatIso(date);
        final total = dailySpendMap[dateIso] ?? 0;
        final label = DateFormat('d MMM').format(date);
        trends.add(TrendDataPoint(date: date, label: label, totalMinorUnits: total));
      }

      // 3. Highest expense
      final highestAmount = (highestMap?['amount'] as int?) ?? 0;
      final highestNote = highestMap?['note'] as String?;

      // 4. Daily average
      final dailyAvg = durationDays > 0 ? periodTotal / durationDays.toDouble() : 0.0;

      // 5. Generate Offline Insights
      final insights = InsightsService.generateInsights(
        weekTotalMinor: periodTotal,
        previousWeekTotalMinor: prevPeriodTotal,
        monthTotalMinor: periodTotal,
        highestExpenseMinor: highestAmount,
        highestExpenseNote: highestNote,
        currentWeekCategoryTotals: categoryTotals,
        previousWeekCategoryTotals: prevCategoryTotals,
        categories: activeCategories,
        currencySymbol: currencySymbol,
      );

      _summary = ReportSummary(
        todayTotalMinor: todayTotal,
        weekTotalMinor: periodTotal,
        monthTotalMinor: periodTotal,
        previousWeekTotalMinor: prevPeriodTotal,
        previousMonthTotalMinor: prevPeriodTotal,
        highestExpenseMinor: highestAmount,
        highestExpenseNote: highestNote,
        dailyAverageMinor: dailyAvg,
        categoryBreakdown: categoryBreakdown,
        dailyTrends: trends,
        insights: insights,
        totalIncomeMinor: totalIncomePaise,
        totalExpenseMinor: periodTotal,
      );
    } catch (e) {
      debugPrint('Error generating report summary: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _formatIso(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }
}
