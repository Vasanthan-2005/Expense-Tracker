import 'package:flutter/foundation.dart';

import '../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseProvider with ChangeNotifier {
  bool _isDisposed = false;
  List<Expense> _expenses = [];
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

  // Filter & Search states
  String _searchQuery = '';
  final List<int> _selectedCategoryIds = [];
  DateTime? _startDate;
  DateTime? _endDate;
  bool _oldestFirst = false;

  // Selected Month State (defaults to current month)
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Dashboard Aggregate Fast Totals (Paise)
  int _todayTotalPaise = 0;
  int _weekTotalPaise = 0;
  int _monthTotalPaise = 0;

  List<Expense> get expenses => List.unmodifiable(_expenses);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  List<int> get selectedCategoryIds => List.unmodifiable(_selectedCategoryIds);
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool get oldestFirst => _oldestFirst;
  DateTime get selectedMonth => _selectedMonth;

  int get todayTotalPaise => _todayTotalPaise;
  int get weekTotalPaise => _weekTotalPaise;
  int get monthTotalPaise => _monthTotalPaise;

  ExpenseProvider() {
    refreshAll();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = DateTime(month.year, month.month, 1);
    _startDate = null;
    _endDate = null;
    refreshAll();
  }

  void previousMonth() {
    setSelectedMonth(DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  void nextMonth() {
    setSelectedMonth(DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  }

  Future<void> refreshAll() async {
    _isLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final todayIso = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));
      final weekStartIso = "${monday.year.toString().padLeft(4, '0')}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}";
      final weekEndIso = "${sunday.year.toString().padLeft(4, '0')}-${sunday.month.toString().padLeft(2, '0')}-${sunday.day.toString().padLeft(2, '0')}";

      final selYearStr = _selectedMonth.year.toString().padLeft(4, '0');
      final selMonthStr = _selectedMonth.month.toString().padLeft(2, '0');
      final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
      final monthStartIso = "$selYearStr-$selMonthStr-01";
      final monthEndIso = "$selYearStr-$selMonthStr-${lastDay.toString().padLeft(2, '0')}";

      final effectiveStart = _startDate ?? DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final effectiveEnd = _endDate ?? DateTime(_selectedMonth.year, _selectedMonth.month, lastDay, 23, 59, 59);

      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getExpenses(
          searchQuery: _searchQuery,
          categoryIds: _selectedCategoryIds.isNotEmpty ? _selectedCategoryIds : null,
          startDate: effectiveStart,
          endDate: effectiveEnd,
          oldestFirst: _oldestFirst,
        ),
        db.getTotalPaiseForDateRange(todayIso, todayIso),
        db.getTotalPaiseForDateRange(weekStartIso, weekEndIso),
        db.getTotalPaiseForDateRange(monthStartIso, monthEndIso),
      ]);

      _expenses = results[0] as List<Expense>;
      _todayTotalPaise = results[1] as int;
      _weekTotalPaise = results[2] as int;
      _monthTotalPaise = results[3] as int;
    } catch (e) {
      debugPrint('Error refreshing expense provider: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchExpenses() async {
    await refreshAll();
  }

  Future<void> addExpense(Expense expense) async {
    await DatabaseHelper.instance.insertExpense(expense);
    await refreshAll();
  }

  Future<void> updateExpense(Expense expense) async {
    await DatabaseHelper.instance.updateExpense(expense);
    await refreshAll();
  }

  Future<void> deleteExpense(int id) async {
    await DatabaseHelper.instance.deleteExpense(id);
    await refreshAll();
  }

  void setSearchQuery(String query) {
    if (_searchQuery != query) {
      _searchQuery = query;
      fetchExpenses();
    }
  }

  void toggleCategoryFilter(int categoryId) {
    if (_selectedCategoryIds.contains(categoryId)) {
      _selectedCategoryIds.remove(categoryId);
    } else {
      _selectedCategoryIds.add(categoryId);
    }
    fetchExpenses();
  }

  void clearCategoryFilter() {
    if (_selectedCategoryIds.isNotEmpty) {
      _selectedCategoryIds.clear();
      fetchExpenses();
    }
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _startDate = start;
    _endDate = end;
    fetchExpenses();
  }

  void clearDateRange() {
    _startDate = null;
    _endDate = null;
    fetchExpenses();
  }

  void toggleSortOrder() {
    _oldestFirst = !_oldestFirst;
    fetchExpenses();
  }

  void clearAllFilters() {
    _searchQuery = '';
    _selectedCategoryIds.clear();
    _startDate = null;
    _endDate = null;
    _oldestFirst = false;
    fetchExpenses();
  }
}
