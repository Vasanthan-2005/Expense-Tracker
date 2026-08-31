import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/models/transfer.dart';
import 'package:expense_tracker/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Unit & Performance Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      // Clear database before each test
      await dbHelper.clearAllData();
    });

    test('Default categories and accounts pre-populated correctly', () async {
      final categories = await dbHelper.getCategories();
      expect(categories.length, greaterThanOrEqualTo(4));
      expect(categories.any((c) => c.name == 'Groceries'), isTrue);

      final accounts = await dbHelper.getAccounts();
      expect(accounts.length, greaterThanOrEqualTo(2));
      expect(accounts.any((a) => a.name == 'Salary Account'), isTrue);
      expect(accounts.any((a) => a.name == 'Expense Account' || a.name == 'Cash'), isTrue);
    });

    test('Accounts & Balance System: Opening balance + Transfer + Expense flow', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');
      final expenseAcc = accounts.firstWhere((a) => a.name == 'Expense Account' || a.name == 'Cash');

      // 1. Initial Salary Account opening balance is 0
      var balances = await dbHelper.getAccountCalculatedBalances();
      expect(balances[salaryAcc.id], equals(0));
      expect(balances[expenseAcc.id], equals(0));

      final now = DateTime.now();

      // Add ₹40,000 salary income to Salary Account
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 4000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Monthly Salary',
        date: now,
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      // 2. Transfer ₹20,000 (2000000 paise) from Salary Account -> Expense Account
      await dbHelper.insertTransfer(Transfer(
        amountMinorUnits: 2000000,
        fromAccountId: salaryAcc.id!,
        toAccountId: expenseAcc.id!,
        note: 'Monthly expense allocation',
        date: now,
        timeString: '10:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      // Salary Account: 4000000 - 2000000 = 2000000 (₹20,000)
      expect(balances[salaryAcc.id], equals(2000000));
      // Expense Account: 0 + 2000000 = 2000000 (₹20,000)
      expect(balances[expenseAcc.id], equals(2000000));

      // 3. Spend ₹150 (15000 paise) from Expense Account
      final categories = await dbHelper.getCategories();
      final foodCat = categories.firstWhere((c) => c.name == 'Groceries');

      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 15000, // ₹150
        categoryId: foodCat.id!,
        accountId: expenseAcc.id!,
        note: 'Dinner',
        date: now,
        timeString: '20:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      // Expense Account: 2000000 - 15000 = 1985000 (₹19,850)
      expect(balances[expenseAcc.id], equals(1985000));
      // Salary Account remains ₹20,000
      expect(balances[salaryAcc.id], equals(2000000));

      // 4. Add ₹10,000 (1000000 paise) Income to Salary Account
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Bonus',
        date: now,
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      balances = await dbHelper.getAccountCalculatedBalances();
      // Salary Account: 2000000 + 1000000 = 3000000 (₹30,000)
      expect(balances[salaryAcc.id], equals(3000000));
    });

    test('Expense CRUD with minor unit financial precision', () async {
      final categories = await dbHelper.getCategories();
      final foodCat = categories.firstWhere((c) => c.name == 'Groceries');

      final now = DateTime.now();
      final expense = Expense(
        amountMinorUnits: 1550, // ₹ 15.50
        categoryId: foodCat.id!,
        note: 'Lunch at Cafe',
        date: DateTime(2026, 8, 25),
        timeString: '12:30',
        createdAt: now,
        updatedAt: now,
      );

      // Insert
      final id = await dbHelper.insertExpense(expense);
      expect(id, greaterThan(0));

      // Read
      final expenses = await dbHelper.getExpenses();
      expect(expenses.length, equals(1));
      expect(expenses.first.amountMinorUnits, equals(1550));
      expect(expenses.first.amountDouble, equals(15.50));
      expect(expenses.first.note, equals('Lunch at Cafe'));

      // Update
      final updatedExpense = expenses.first.copyWith(
        amountMinorUnits: 2000,
        note: 'Updated Lunch',
      );
      final updateCount = await dbHelper.updateExpense(updatedExpense);
      expect(updateCount, equals(1));

      final reFetched = await dbHelper.getExpenses();
      expect(reFetched.first.amountMinorUnits, equals(2000));
      expect(reFetched.first.note, equals('Updated Lunch'));

      // Delete
      final deleteCount = await dbHelper.deleteExpense(id);
      expect(deleteCount, equals(1));

      final remaining = await dbHelper.getExpenses();
      expect(remaining.isEmpty, isTrue);
    });

    test('Category Deletion with Safe Re-assignment', () async {
      final customCat = Category(
        name: 'Custom Gaming',
        iconCodePoint: 0xe000,
        colorValue: 0xFF123456,
        createdAt: DateTime.now(),
      );
      final catId = await dbHelper.insertCategory(customCat);

      final expense = Expense(
        amountMinorUnits: 50000, // ₹ 500.00
        categoryId: catId,
        note: 'Steam Game',
        date: DateTime.now(),
        timeString: '14:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await dbHelper.insertExpense(expense);

      // Delete custom category (will fallback to first remaining category since 'Other' was removed or re-assigned)
      await dbHelper.deleteCategory(catId);

      // Check expense was safely reassigned instead of breaking
      final expenses = await dbHelper.getExpenses();
      expect(expenses.length, equals(1));
      expect(expenses.first.categoryId, isNot(equals(catId)));
    });

    test('Fast SQLite Aggregates for Dashboard Totals', () async {
      final categories = await dbHelper.getCategories();
      final foodCat = categories.firstWhere((c) => c.name == 'Groceries');

      final today = DateTime.now();
      final todayIso = "${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 10000, // 100.00
        categoryId: foodCat.id!,
        date: today,
        timeString: '10:00',
        createdAt: today,
        updatedAt: today,
      ));

      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 25050, // 250.50
        categoryId: foodCat.id!,
        date: today,
        timeString: '13:00',
        createdAt: today,
        updatedAt: today,
      ));

      final totalPaise = await dbHelper.getTotalPaiseForDateRange(todayIso, todayIso);
      expect(totalPaise, equals(35050));
    });
  });
}
