import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/income.dart';
import '../models/transfer.dart';
import '../core/database/database_helper.dart';

class AccountProvider with ChangeNotifier {
  bool _isDisposed = false;
  List<Account> _accounts = [];

  /// Overall balances (all-time) for every account
  Map<int, int> _overallAccountBalances = {};

  /// Monthly balances keyed by [year][month] — loaded on demand
  Map<int, int> _monthlyAccountBalances = {};

  Account? _defaultAccount;
  List<Income> _recentIncomes = [];
  List<Transfer> _recentTransfers = [];
  bool _isLoading = false;

  /// The currently selected month used for monthly-mode balance display.
  /// Defaults to the current month and is updated externally when the user
  /// changes the dashboard/income month selector.
  int _selectedBalanceYear = DateTime.now().year;
  int _selectedBalanceMonth = DateTime.now().month;

  // Monthly Income History State
  DateTime _selectedIncomeMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Income> _monthlyIncomes = [];
  int _monthlyTotalIncomePaise = 0;
  Map<int, int> _accountIncomeBreakdown = {};
  int? _incomeFilterAccountId;
  String _incomeSearchQuery = '';

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

  List<Account> get accounts => List.unmodifiable(_accounts);
  Map<int, int> get accountBalances => Map.unmodifiable(_overallAccountBalances);
  Account? get defaultAccount => _defaultAccount;
  List<Income> get recentIncomes => List.unmodifiable(_recentIncomes);
  List<Transfer> get recentTransfers => List.unmodifiable(_recentTransfers);
  bool get isLoading => _isLoading;

  DateTime get selectedIncomeMonth => _selectedIncomeMonth;
  List<Income> get monthlyIncomes => List.unmodifiable(_monthlyIncomes);
  int get monthlyTotalIncomePaise => _monthlyTotalIncomePaise;
  Map<int, int> get accountIncomeBreakdown => Map.unmodifiable(_accountIncomeBreakdown);
  int? get incomeFilterAccountId => _incomeFilterAccountId;
  String get incomeSearchQuery => _incomeSearchQuery;

  int get selectedBalanceYear => _selectedBalanceYear;
  int get selectedBalanceMonth => _selectedBalanceMonth;

  /// Total combined net worth in Paise across all active accounts.
  /// For accounts in monthly mode, uses the monthly balance for the currently
  /// selected month. For accounts in overall mode, uses the overall balance.
  int get totalNetWorthPaise {
    int total = 0;
    for (final account in _accounts) {
      total += getAccountBalancePaise(account.id!);
    }
    return total;
  }

  /// Returns the appropriate balance for the account based on its balance mode
  /// and the currently selected balance month.
  int getAccountBalancePaise(int accountId) {
    final account = _accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => _accounts.isEmpty
          ? throw StateError('No accounts loaded')
          : _accounts.first,
    );
    if (account.balanceMode == AccountBalanceMode.monthly) {
      return _monthlyAccountBalances[accountId] ?? 0;
    }
    return _overallAccountBalances[accountId] ?? 0;
  }

  /// Returns the raw overall (all-time) balance regardless of account mode.
  int getOverallAccountBalancePaise(int accountId) {
    return _overallAccountBalances[accountId] ?? 0;
  }

  /// Returns the raw monthly balance for the selected month regardless of account mode.
  int getMonthlyAccountBalancePaise(int accountId) {
    return _monthlyAccountBalances[accountId] ?? 0;
  }

  AccountProvider() {
    refreshAccounts();
  }

  /// Called when the user changes the selected display month (e.g., dashboard
  /// month switcher). Loads monthly balances for the new month.
  Future<void> setSelectedBalanceMonth(int year, int month) async {
    if (_selectedBalanceYear == year && _selectedBalanceMonth == month) return;
    _selectedBalanceYear = year;
    _selectedBalanceMonth = month;
    await _refreshMonthlyBalances();
    notifyListeners();
  }

  Future<void> _refreshMonthlyBalances() async {
    try {
      _monthlyAccountBalances = await DatabaseHelper.instance
          .getAccountMonthlyBalances(_selectedBalanceYear, _selectedBalanceMonth);
    } catch (e) {
      debugPrint('Error refreshing monthly balances: $e');
    }
  }

  void setSelectedIncomeMonth(DateTime month) {
    _selectedIncomeMonth = DateTime(month.year, month.month, 1);
    refreshMonthlyIncomes();
  }

  void previousIncomeMonth() {
    setSelectedIncomeMonth(DateTime(_selectedIncomeMonth.year, _selectedIncomeMonth.month - 1, 1));
  }

  void nextIncomeMonth() {
    setSelectedIncomeMonth(DateTime(_selectedIncomeMonth.year, _selectedIncomeMonth.month + 1, 1));
  }

  void setIncomeFilterAccountId(int? accountId) {
    _incomeFilterAccountId = accountId;
    refreshMonthlyIncomes();
  }

  void setIncomeSearchQuery(String query) {
    _incomeSearchQuery = query;
    refreshMonthlyIncomes();
  }

  Future<void> refreshMonthlyIncomes() async {
    try {
      final db = DatabaseHelper.instance;
      final year = _selectedIncomeMonth.year;
      final month = _selectedIncomeMonth.month;
      final lastDay = DateTime(year, month + 1, 0).day;
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month, lastDay, 23, 59, 59);

      final results = await Future.wait([
        db.getIncomesFiltered(
          accountId: _incomeFilterAccountId,
          startDate: start,
          endDate: end,
          searchQuery: _incomeSearchQuery.trim().isEmpty ? null : _incomeSearchQuery.trim(),
        ),
        db.getTotalIncomePaiseForMonth(year, month, accountId: _incomeFilterAccountId),
        db.getAccountIncomeBreakdownForMonth(year, month),
      ]);

      _monthlyIncomes = results[0] as List<Income>;
      _monthlyTotalIncomePaise = results[1] as int;
      _accountIncomeBreakdown = results[2] as Map<int, int>;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing monthly incomes: $e');
    }
  }

  Future<void> refreshAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final db = DatabaseHelper.instance;
      final results = await Future.wait([
        db.getAccounts(),
        db.getAccountCalculatedBalances(),
        db.getAccountMonthlyBalances(_selectedBalanceYear, _selectedBalanceMonth),
        db.getDefaultAccount(),
        db.getIncomes(limit: 10),
        db.getTransfers(limit: 10),
      ]);

      _accounts = results[0] as List<Account>;
      _overallAccountBalances = results[1] as Map<int, int>;
      _monthlyAccountBalances = results[2] as Map<int, int>;
      _defaultAccount = results[3] as Account?;
      _recentIncomes = results[4] as List<Income>;
      _recentTransfers = results[5] as List<Transfer>;
      await refreshMonthlyIncomes();
    } catch (e) {
      debugPrint('Error refreshing accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addAccount(Account account) async {
    await DatabaseHelper.instance.insertAccount(account);
    await refreshAccounts();
  }

  Future<void> updateAccount(Account account) async {
    await DatabaseHelper.instance.updateAccount(account);
    await refreshAccounts();
  }

  Future<void> setDefaultAccount(int accountId) async {
    await DatabaseHelper.instance.setDefaultAccount(accountId);
    await refreshAccounts();
  }

  Future<void> setAccountBalanceMode(int accountId, AccountBalanceMode mode) async {
    await DatabaseHelper.instance.setAccountBalanceMode(accountId, mode.key);
    // Update in-memory account list
    _accounts = _accounts.map((a) {
      if (a.id == accountId) return a.copyWith(balanceMode: mode);
      return a;
    }).toList();
    notifyListeners();
  }

  Future<void> deleteAccount(int accountId) async {
    await DatabaseHelper.instance.deleteAccount(accountId);
    await refreshAccounts();
  }

  Future<void> addIncome(Income income) async {
    await DatabaseHelper.instance.insertIncome(income);
    await refreshAccounts();
  }

  Future<void> updateIncome(Income income) async {
    await DatabaseHelper.instance.updateIncome(income);
    await refreshAccounts();
  }

  Future<void> deleteIncome(int id) async {
    await DatabaseHelper.instance.deleteIncome(id);
    await refreshAccounts();
  }

  Future<void> addTransfer(Transfer transfer) async {
    await DatabaseHelper.instance.insertTransfer(transfer);
    await refreshAccounts();
  }

  Future<void> updateTransfer(Transfer transfer) async {
    await DatabaseHelper.instance.updateTransfer(transfer);
    await refreshAccounts();
  }

  Future<void> deleteTransfer(int id) async {
    await DatabaseHelper.instance.deleteTransfer(id);
    await refreshAccounts();
  }
}
