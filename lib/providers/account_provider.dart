import 'package:flutter/foundation.dart';

import '../models/account.dart';
import '../models/income.dart';
import '../models/transfer.dart';
import '../core/database/database_helper.dart';

class AccountProvider with ChangeNotifier {
  bool _isDisposed = false;
  List<Account> _accounts = [];
  Map<int, int> _accountBalances = {};
  Account? _defaultAccount;
  List<Income> _recentIncomes = [];
  List<Transfer> _recentTransfers = [];
  bool _isLoading = false;

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
  Map<int, int> get accountBalances => Map.unmodifiable(_accountBalances);
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

  /// Total combined net worth in Paise across all active accounts
  int get totalNetWorthPaise {
    int total = 0;
    for (final bal in _accountBalances.values) {
      total += bal;
    }
    return total;
  }

  int getAccountBalancePaise(int accountId) {
    return _accountBalances[accountId] ?? 0;
  }

  AccountProvider() {
    refreshAccounts();
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
      _accounts = await db.getAccounts();
      _accountBalances = await db.getAccountCalculatedBalances();
      _defaultAccount = await db.getDefaultAccount();
      _recentIncomes = await db.getIncomes(limit: 10);
      _recentTransfers = await db.getTransfers(limit: 10);
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
