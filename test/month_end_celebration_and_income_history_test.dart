import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Month-End Celebration, Overall Budget & Income History Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
    });

    test('1. Overall Monthly Budget Setting & Retrieval in AppSettings', () async {
      final defaultSettings = await dbHelper.getSettings();
      expect(defaultSettings.overallMonthlyBudgetPaise, isNull);
      expect(defaultSettings.isOverallBudgetSet, isFalse);

      // Set Overall Monthly Budget to ₹50,000 (5,000,000 Paise)
      await dbHelper.updateSetting('overall_monthly_budget', '5000000');
      final updatedSettings = await dbHelper.getSettings();
      expect(updatedSettings.overallMonthlyBudgetPaise, equals(5000000));
      expect(updatedSettings.overallMonthlyBudgetDouble, equals(50000.0));
      expect(updatedSettings.isOverallBudgetSet, isTrue);

      // Clear budget
      await dbHelper.updateSetting('overall_monthly_budget', '');
      final clearedSettings = await dbHelper.getSettings();
      expect(clearedSettings.overallMonthlyBudgetPaise, isNull);
      expect(clearedSettings.isOverallBudgetSet, isFalse);
    });

    test('2. Month-End Celebration: Under Budget triggers isCelebrationQualified', () async {
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');
      final petrol = categories.firstWhere((c) => c.name == 'Petrol');

      // Set Category Budgets: Groceries ₹5,000, Petrol ₹3,000
      await dbHelper.updateCategoryBudget(groceries.id!, 500000);
      await dbHelper.updateCategoryBudget(petrol.id!, 300000);

      // Set Overall Monthly Budget: ₹50,000
      await dbHelper.updateSetting('overall_monthly_budget', '5000000');

      const year = 2026;
      const month = 8;
      final now = DateTime(year, month, 15);

      // Spend within limits: Groceries ₹3,500, Petrol ₹2,000
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 350000,
        categoryId: groceries.id!,
        note: 'Supermarket',
        date: DateTime(year, month, 5),
        timeString: '12:00',
        createdAt: now,
        updatedAt: now,
      ));

      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 200000,
        categoryId: petrol.id!,
        note: 'Fuel station',
        date: DateTime(year, month, 10),
        timeString: '14:00',
        createdAt: now,
        updatedAt: now,
      ));

      final performance = await dbHelper.getMonthBudgetPerformance(
        year: year,
        month: month,
        overallBudgetPaise: 5000000,
      );

      expect(performance['totalSpentPaise'], equals(550000)); // ₹5,500
      expect(performance['isOverallWithinBudget'], isTrue);
      expect(performance['allCategoriesWithinBudget'], isTrue);
      expect(performance['isCelebrationQualified'], isTrue);
      expect(performance['overallSavedPaise'], equals(4450000)); // Saved ₹44,500
    });

    test('3. Month-End Celebration: Category overspend disallows celebration', () async {
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');

      // Set Groceries Budget: ₹4,000
      await dbHelper.updateCategoryBudget(groceries.id!, 400000);

      const year = 2026;
      const month = 7;
      final now = DateTime(year, month, 15);

      // Spend ₹4,500 (over budget by ₹500)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 450000,
        categoryId: groceries.id!,
        note: 'Big Supermarket',
        date: DateTime(year, month, 5),
        timeString: '12:00',
        createdAt: now,
        updatedAt: now,
      ));

      final performance = await dbHelper.getMonthBudgetPerformance(
        year: year,
        month: month,
        overallBudgetPaise: 5000000,
      );

      expect(performance['allCategoriesWithinBudget'], isFalse);
      expect(performance['isCelebrationQualified'], isFalse);
    });

    test('4. Monthly Income History: Filtering, search, total calculation and account breakdown', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.first;
      final otherAcc = accounts.last;

      const year = 2026;
      const month = 8;
      final now = DateTime(year, month, 10);

      // Insert 2 incomes in August 2026
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 5000000, // ₹50,000
        accountId: salaryAcc.id!,
        sourceOrNote: 'Primary Job Salary',
        date: DateTime(year, month, 1),
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1500000, // ₹15,000
        accountId: otherAcc.id!,
        sourceOrNote: 'Freelance Design',
        date: DateTime(year, month, 15),
        timeString: '16:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Insert 1 income in previous month (July 2026)
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 4800000, // ₹48,000
        accountId: salaryAcc.id!,
        sourceOrNote: 'July Salary',
        date: DateTime(year, 7, 1),
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      // August Monthly Total
      final augTotal = await dbHelper.getTotalIncomePaiseForMonth(year, month);
      expect(augTotal, equals(6500000)); // ₹65,000

      // July Monthly Total
      final julTotal = await dbHelper.getTotalIncomePaiseForMonth(year, 7);
      expect(julTotal, equals(4800000)); // ₹48,000

      // August Incomes filtered by month
      final augIncomes = await dbHelper.getIncomesFiltered(
        startDate: DateTime(year, month, 1),
        endDate: DateTime(year, month, 31, 23, 59, 59),
      );
      expect(augIncomes.length, equals(2));

      // August Search Filter "Freelance"
      final searchIncomes = await dbHelper.getIncomesFiltered(
        startDate: DateTime(year, month, 1),
        endDate: DateTime(year, month, 31, 23, 59, 59),
        searchQuery: 'Freelance',
      );
      expect(searchIncomes.length, equals(1));
      expect(searchIncomes.first.sourceOrNote, equals('Freelance Design'));

      // August Account Breakdown
      final breakdown = await dbHelper.getAccountIncomeBreakdownForMonth(year, month);
      expect(breakdown[salaryAcc.id!], equals(5000000));
      expect(breakdown[otherAcc.id!], equals(1500000));
    });

    test('5. All Months Budget Performance History: Multi-Month evaluation with exceeded counts', () async {
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');

      await dbHelper.updateCategoryBudget(groceries.id!, 400000); // ₹4,000

      // August 2026 expense (within budget)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 250000, // ₹2,500
        categoryId: groceries.id!,
        note: 'Aug Groceries',
        date: DateTime(2026, 8, 10),
        timeString: '10:00',
        createdAt: DateTime(2026, 8, 10),
        updatedAt: DateTime(2026, 8, 10),
      ));

      // July 2026 expense (exceeded budget)
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 450000, // ₹4,500
        categoryId: groceries.id!,
        note: 'Jul Groceries Over',
        date: DateTime(2026, 7, 10),
        timeString: '10:00',
        createdAt: DateTime(2026, 7, 10),
        updatedAt: DateTime(2026, 7, 10),
      ));

      final allHistory = await dbHelper.getAllMonthsBudgetPerformance(
        overallBudgetPaise: 5000000,
      );

      expect(allHistory.length, greaterThanOrEqualTo(2));

      final augHistory = allHistory.firstWhere((m) => m['year'] == 2026 && m['month'] == 8);
      expect(augHistory['totalSpentPaise'], equals(250000));
      expect(augHistory['isCelebrationQualified'], isTrue);
      expect(augHistory['exceededCategoriesCount'], equals(0));

      final julHistory = allHistory.firstWhere((m) => m['year'] == 2026 && m['month'] == 7);
      expect(julHistory['totalSpentPaise'], equals(450000));
      expect(julHistory['isCelebrationQualified'], isFalse);
      expect(julHistory['exceededCategoriesCount'], equals(1));
    });

    test('6. Celebration Settings & Mode: On/Off and All Reviews vs Positive Only toggle', () async {
      final initialSettings = await dbHelper.getSettings();
      expect(initialSettings.isCelebrationEnabled, isTrue);
      expect(initialSettings.celebrationMode, equals('all_reviews'));

      await dbHelper.updateSetting('celebration_enabled', 'false');
      await dbHelper.updateSetting('celebration_mode', 'positive_only');

      final updatedSettings = await dbHelper.getSettings();
      expect(updatedSettings.isCelebrationEnabled, isFalse);
      expect(updatedSettings.celebrationMode, equals('positive_only'));
      expect(updatedSettings.isPositiveOnlyCelebration, isTrue);
    });

    test('7. No Data Month: Empty month does NOT qualify for celebration even if budget is set', () async {
      // Set an overall budget and category budgets
      await dbHelper.updateSetting('overall_monthly_budget', '5000000'); // ₹50,000
      final categories = await dbHelper.getCategories();
      final groceries = categories.firstWhere((c) => c.name == 'Groceries');
      await dbHelper.updateCategoryBudget(groceries.id!, 400000); // ₹4,000

      // Evaluate an empty month with zero expenses (e.g. March 2025)
      const emptyYear = 2025;
      const emptyMonth = 3;

      final performance = await dbHelper.getMonthBudgetPerformance(
        year: emptyYear,
        month: emptyMonth,
        overallBudgetPaise: 5000000,
      );

      // Must have hasData = false, isCelebrationQualified = false, and overallSavedPaise = 0
      expect(performance['hasData'], isFalse);
      expect(performance['expenseCount'], equals(0));
      expect(performance['totalSpentPaise'], equals(0));
      expect(performance['isCelebrationQualified'], isFalse);
      expect(performance['overallSavedPaise'], equals(0));
    });
  });
}
