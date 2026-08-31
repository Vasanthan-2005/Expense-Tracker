import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Three Required Features Unit Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
    });

    test('1. Category Budget Limits: Default is ₹0, setting budget, dynamic monthly spent calculation & reset', () async {
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');

      // Default budget limit is ₹0 / unconfigured
      expect(groceries.monthlyBudgetPaise, isNull);
      expect(groceries.monthlyBudgetDouble, equals(0.0));

      // Set ₹5,000 monthly budget limit for Groceries (500000 paise)
      await dbHelper.updateCategoryBudget(groceries.id!, 500000);
      final updatedCats = await dbHelper.getCategories();
      final updatedGroceries = updatedCats.firstWhere((c) => c.id == groceries.id);
      expect(updatedGroceries.monthlyBudgetPaise, equals(500000));
      expect(updatedGroceries.monthlyBudgetDouble, equals(5000.0));

      final now = DateTime.now();

      // Add ₹4,200 expense in current month
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 420000,
        categoryId: groceries.id!,
        note: 'Supermarket',
        date: DateTime(now.year, now.month, 10),
        timeString: '12:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Spent for current month should be ₹4,200
      final currentMonthSpent = await dbHelper.getCategorySpentPaiseForMonth(groceries.id!, now.year, now.month);
      expect(currentMonthSpent, equals(420000));

      // Spent for next month (simulated month reset) should automatically be ₹0 while budget limit stays ₹5,000
      final nextMonth = now.month == 12 ? 1 : now.month + 1;
      final nextYear = now.month == 12 ? now.year + 1 : now.year;
      final nextMonthSpent = await dbHelper.getCategorySpentPaiseForMonth(groceries.id!, nextYear, nextMonth);
      expect(nextMonthSpent, equals(0));
      expect(updatedGroceries.monthlyBudgetPaise, equals(500000));
    });

    test('1b. Category Budget Limits: Previous month expense edits update past month calculation without affecting current month', () async {
      final categories = await dbHelper.getCategories();
      final petrol = categories.firstWhere((c) => c.name == 'Petrol');
      final now = DateTime.now();

      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;

      // Add expense in previous month
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 150000,
        categoryId: petrol.id!,
        note: 'Past Month Fuel',
        date: DateTime(prevYear, prevMonth, 15),
        timeString: '10:00',
        createdAt: now,
        updatedAt: now,
      ));

      final currentMonthSpent = await dbHelper.getCategorySpentPaiseForMonth(petrol.id!, now.year, now.month);
      final prevMonthSpent = await dbHelper.getCategorySpentPaiseForMonth(petrol.id!, prevYear, prevMonth);

      expect(prevMonthSpent, equals(150000));
      expect(currentMonthSpent, equals(0));
    });

    test('2. Use Accounts Instead of UPI/Cash in Add Expense: Accounts CRUD & Default Account handling', () async {
      final accounts = await dbHelper.getAccounts();
      expect(accounts.isNotEmpty, isTrue);

      final defaultAcc = await dbHelper.getDefaultAccount();
      expect(defaultAcc, isNotNull);

      // Create a custom account
      final newAccId = await dbHelper.insertAccount(Account(
        name: 'HDFC Business Account',
        openingBalanceMinorUnits: 100000,
        iconCodePoint: 0xe000,
        colorValue: 0xFF2196F3,
        isDefault: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      final allAccounts = await dbHelper.getAccounts();
      expect(allAccounts.any((a) => a.id == newAccId && a.name == 'HDFC Business Account'), isTrue);

      // Set new account as default
      await dbHelper.setDefaultAccount(newAccId);
      final updatedDefault = await dbHelper.getDefaultAccount();
      expect(updatedDefault?.id, equals(newAccId));
      expect(updatedDefault?.name, equals('HDFC Business Account'));
    });

    test('3. Custom Category Order: Reordering persistence & appending new categories', () async {
      final initialCategories = await dbHelper.getCategories();
      expect(initialCategories.length, greaterThanOrEqualTo(3));

      // Reverse order of initial categories
      final reversedOrder = initialCategories.reversed.toList();
      await dbHelper.updateCategoryOrder(reversedOrder);

      final reorderedCategories = await dbHelper.getCategories();
      expect(reorderedCategories.first.name, equals(initialCategories.last.name));

      // Insert new category
      final newCatId = await dbHelper.insertCategory(Category(
        name: 'Gaming Subscriptions',
        iconCodePoint: 0xe001,
        colorValue: 0xFF9C27B0,
        createdAt: DateTime.now(),
      ));

      final categoriesAfterAdd = await dbHelper.getCategories();
      // New category should be appended to the end
      expect(categoriesAfterAdd.last.id, equals(newCatId));
      expect(categoriesAfterAdd.last.name, equals('Gaming Subscriptions'));
    });
  });
}
