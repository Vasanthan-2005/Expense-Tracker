import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/core/database/database_helper.dart';
import 'package:expense_tracker/providers/account_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Credit Card & Income History Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
    });

    test('1. Default accounts contain Credit Card with isCreditCard flag', () async {
      final accounts = await dbHelper.getAccounts();
      expect(accounts.any((a) => a.name == 'Credit Card'), isTrue);

      final cc = accounts.firstWhere((a) => a.name == 'Credit Card');
      expect(cc.isCreditCard, isTrue);
      expect(cc.openingBalanceMinorUnits, equals(0));
    });

    test('2. Spending on Credit Card adds values to account (those are credit)', () async {
      final accounts = await dbHelper.getAccounts();
      final cc = accounts.firstWhere((a) => a.isCreditCard);
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');

      // Initial credit is 0
      var balances = await dbHelper.getAccountCalculatedBalances();
      expect(balances[cc.id], equals(0));

      final now = DateTime.now();

      // Spend ₹1,200 on Credit Card (120000 paise)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 120000,
        categoryId: groceries.id!,
        accountId: cc.id!,
        note: 'Supermarket with CC',
        date: now,
        timeString: '12:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      // Values are added: ₹1,200 credit
      expect(balances[cc.id], equals(120000));

      // Spend another ₹450 on Credit Card (45000 paise)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 45000,
        categoryId: groceries.id!,
        accountId: cc.id!,
        note: 'Online snack with CC',
        date: now,
        timeString: '14:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      // Total credit is 120000 + 45000 = 165000 (₹1,650)
      expect(balances[cc.id], equals(165000));
    });

    test('3. Settling credit card minuses credit amount from Salary Account and zeroes the credit', () async {
      final accounts = await dbHelper.getAccounts();
      final cc = accounts.firstWhere((a) => a.isCreditCard);
      final salaryAcc = accounts.firstWhere((a) => a.name.toLowerCase().contains('salary'));
      final categories = await dbHelper.getCategories();
      final foodCat = categories.first;

      final now = DateTime.now();

      // Add ₹50,000 (5,000,000 paise) salary income to Salary Account
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 5000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Monthly Salary',
        date: now,
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Spend ₹3,500 on Credit Card (350000 paise)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 350000,
        categoryId: foodCat.id!,
        accountId: cc.id!,
        note: 'Electronics with CC',
        date: now,
        timeString: '11:00',
        createdAt: now,
        updatedAt: now,
      ));

      var balances = await dbHelper.getAccountCalculatedBalances();
      expect(balances[salaryAcc.id], equals(5000000));
      expect(balances[cc.id], equals(350000));

      // Use AccountProvider to settle Credit Card
      final provider = AccountProvider();
      await provider.refreshAccounts();

      expect(provider.getAccountBalancePaise(cc.id!), equals(350000));
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(5000000));

      // Click "Settled" -> settleCreditCard
      await provider.settleCreditCard(creditCardAccount: cc);

      // Verify Credit Card balance is ZEROED
      expect(provider.getAccountBalancePaise(cc.id!), equals(0));

      // Verify Salary Account is MINUSED by the credit amount (5000000 - 350000 = 4650000)
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(4650000));

      // Verify live dynamic DB balances match
      balances = await dbHelper.getAccountCalculatedBalances();
      expect(balances[cc.id], equals(0));
      expect(balances[salaryAcc.id], equals(4650000));

      // Subsequent spending adds to credit from 0
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 80000, // ₹800
        categoryId: foodCat.id!,
        accountId: cc.id!,
        note: 'Fuel with CC',
        date: now,
        timeString: '18:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      expect(balances[cc.id], equals(80000));
    });

    test('4. Net worth calculation treats credit card as a liability (subtracted from net balance)', () async {
      final accounts = await dbHelper.getAccounts();
      final cc = accounts.firstWhere((a) => a.isCreditCard);
      final salaryAcc = accounts.firstWhere((a) => a.name.toLowerCase().contains('salary'));
      final categories = await dbHelper.getCategories();
      final foodCat = categories.first;

      final now = DateTime.now();

      // Add ₹60,000 income to Salary Account
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 6000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Salary',
        date: now,
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Spend ₹5,000 on Credit Card
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 500000,
        categoryId: foodCat.id!,
        accountId: cc.id!,
        note: 'Shopping with CC',
        date: now,
        timeString: '11:00',
        createdAt: now,
        updatedAt: now,
      ));

      final provider = AccountProvider();
      await provider.refreshAccounts();

      // Before settlement:
      // Salary: ₹60,000
      // CC due: ₹5,000
      // Total Net Balance = 60,000 - 5,000 = ₹55,000 (5500000 paise)
      expect(provider.totalNetWorthPaise, equals(5500000));

      // Settle CC from Salary Account
      await provider.settleCreditCard(creditCardAccount: cc);

      // After settlement:
      // Salary: ₹55,000
      // CC due: ₹0
      // Total Net Balance remains consistently ₹55,000 (5500000 paise)
      expect(provider.totalNetWorthPaise, equals(5500000));
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(5500000));
      expect(provider.getAccountBalancePaise(cc.id!), equals(0));
    });
  });
}
