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
