import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/models/transfer.dart';
import 'package:expense_tracker/core/database/database_helper.dart';
import 'package:expense_tracker/providers/reports_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Income Categories & Enhanced Reports Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
      await dbHelper.syncDefaultCategories();
    });

    test('1. Default Income categories are seeded: Salary, Jman Claim, Rapido', () async {
      final incomeCats = await dbHelper.getCategories(type: 'income');
      expect(incomeCats.length, greaterThanOrEqualTo(3));

      final names = incomeCats.map((c) => c.name.toLowerCase()).toList();
      expect(names, contains('salary'));
      expect(names, contains('jman claim'));
      expect(names, contains('rapido'));

      for (final cat in incomeCats) {
        expect(cat.type, equals('income'));
        expect(cat.isIncome, isTrue);
      }
    });

    test('2. Income categories can be added, updated, and reordered independently', () async {
      // Add custom income category
      final newCat = Category(
        name: 'Freelance',
        colorValue: 0xFF22C55E,
        iconCodePoint: 0xe84f,
        type: 'income',
        createdAt: DateTime.now(),
      );
      final id = await dbHelper.insertCategory(newCat);
      expect(id, greaterThan(0));

      var incomeCats = await dbHelper.getCategories(type: 'income');
      expect(incomeCats.any((c) => c.name == 'Freelance'), isTrue);

      // Verify expense categories are untouched
      final expenseCats = await dbHelper.getCategories(type: 'expense');
      expect(expenseCats.any((c) => c.name == 'Freelance'), isFalse);

      // Update income category
      final createdCat = incomeCats.firstWhere((c) => c.name == 'Freelance');
      final updatedCat = createdCat.copyWith(name: 'Freelance Consulting');
      await dbHelper.updateCategory(updatedCat);

      incomeCats = await dbHelper.getCategories(type: 'income');
      expect(incomeCats.any((c) => c.name == 'Freelance Consulting'), isTrue);
    });

    test('3. Income transactions store categoryId and report aggregates by category', () async {
      final accounts = await dbHelper.getAccounts();
      final defaultAccount = accounts.first;
      final incomeCats = await dbHelper.getCategories(type: 'income');

      final salaryCat = incomeCats.firstWhere((c) => c.name.toLowerCase() == 'salary');
      final rapidoCat = incomeCats.firstWhere((c) => c.name.toLowerCase() == 'rapido');

      final now = DateTime.now();
      final dateIso = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Insert salary income: ₹50,000 (5,000,000 paise)
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 5000000,
        accountId: defaultAccount.id!,
        categoryId: salaryCat.id,
        sourceOrNote: 'Monthly Salary',
        date: now,
        timeString: '10:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Insert rapido income: ₹500 (50,000 paise)
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 50000,
        accountId: defaultAccount.id!,
        categoryId: rapidoCat.id,
        sourceOrNote: 'Weekend Trips',
        date: now,
        timeString: '18:30',
        createdAt: now,
        updatedAt: now,
      ));

      // Test database aggregation for income categories
      final catTotals = await dbHelper.getIncomeCategoryTotalsForDateRange(dateIso, dateIso);
      expect(catTotals[salaryCat.id], equals(5000000));
      expect(catTotals[rapidoCat.id], equals(50000));

      // Test query incomes by category
      final salaryIncomes = await dbHelper.getIncomesByCategory(
        categoryId: salaryCat.id,
        startDate: now,
        endDate: now,
      );
      expect(salaryIncomes.length, equals(1));
      expect(salaryIncomes.first.amountMinorUnits, equals(5000000));

      final rapidoIncomes = await dbHelper.getIncomesByCategory(
        categoryId: rapidoCat.id,
        startDate: now,
        endDate: now,
      );
      expect(rapidoIncomes.length, equals(1));
      expect(rapidoIncomes.first.amountMinorUnits, equals(50000));
    });

    test('4. ReportsProvider computes income category breakdown and transfer summaries', () async {
      final accounts = await dbHelper.getAccounts();
      final acc1 = accounts[0];
      final acc2 = accounts[1];
      final allCats = await dbHelper.getCategories();
      final incomeCats = await dbHelper.getCategories(type: 'income');

      final salaryCat = incomeCats.firstWhere((c) => c.name.toLowerCase() == 'salary');
      final jmanCat = incomeCats.firstWhere((c) => c.name.toLowerCase() == 'jman claim');

      final now = DateTime.now();

      // Income 1: ₹40,000 Salary
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 4000000,
        accountId: acc1.id!,
        categoryId: salaryCat.id,
        date: now,
        timeString: '09:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Income 2: ₹10,000 Jman Claim
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1000000,
        accountId: acc1.id!,
        categoryId: jmanCat.id,
        date: now,
        timeString: '14:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Transfer: ₹5,000 from acc1 to acc2
      await dbHelper.insertTransfer(Transfer(
        amountMinorUnits: 500000,
        fromAccountId: acc1.id!,
        toAccountId: acc2.id!,
        note: 'Savings allocation',
        date: now,
        timeString: '15:00',
        createdAt: now,
        updatedAt: now,
      ));

      final reportsProv = ReportsProvider();
      await reportsProv.loadReportSummary(
        categories: allCats,
        currencySymbol: '₹',
        showLoadingIndicator: false,
      );

      final summary = reportsProv.summary;
      expect(summary, isNotNull);
      expect(summary!.totalIncomeMinor, equals(5000000)); // ₹50,000
      expect(summary.incomeCategoryBreakdown.length, equals(2));

      // Top income category is Salary
      final topIncome = summary.topIncomeCategory;
      expect(topIncome, isNotNull);
      expect(topIncome!.categoryName.toLowerCase(), equals('salary'));
      expect(topIncome.totalMinorUnits, equals(4000000));
      expect(topIncome.percentage, closeTo(80.0, 0.1));

      // Transfer stats
      expect(summary.totalTransferMinor, equals(500000));
      expect(summary.transferCount, equals(1));
      expect(summary.periodTransfers.length, equals(1));
      expect(summary.periodTransfers.first.fromAccountId, equals(acc1.id));
      expect(summary.periodTransfers.first.toAccountId, equals(acc2.id));
    });

    test('5. Deleting income updates account balance and removes transaction from reports', () async {
      final accounts = await dbHelper.getAccounts();
      final acc = accounts.first;
      final incomeCats = await dbHelper.getCategories(type: 'income');
      final salaryCat = incomeCats.firstWhere((c) => c.name.toLowerCase() == 'salary');

      final now = DateTime.now();
      final incomeId = await dbHelper.insertIncome(Income(
        amountMinorUnits: 2500000, // ₹25,000
        accountId: acc.id!,
        categoryId: salaryCat.id,
        sourceOrNote: 'Bonus',
        date: now,
        timeString: '11:00',
        createdAt: now,
        updatedAt: now,
      ));

      // Verify balance increased
      var calcBalances = await dbHelper.getAccountCalculatedBalances();
      final initialBalance = calcBalances[acc.id]!;

      // Delete income
      await dbHelper.deleteIncome(incomeId);

      // Verify balance reduced by ₹25,000
      calcBalances = await dbHelper.getAccountCalculatedBalances();
      expect(calcBalances[acc.id]!, equals(initialBalance - 2500000));

      // Verify not returned in category incomes
      final incomes = await dbHelper.getIncomesByCategory(
        categoryId: salaryCat.id,
        startDate: now,
        endDate: now,
      );
      expect(incomes.any((i) => i.id == incomeId), isFalse);
    });

    test('6. Past month balance behavior: monthly added vs cumulative added', () async {
      final accounts = await dbHelper.getAccounts();
      final monthlyAcc = accounts.first;
      final overallAcc = accounts[1];

      await dbHelper.setAccountBalanceMode(monthlyAcc.id!, 'monthly');
      await dbHelper.setAccountBalanceMode(overallAcc.id!, 'overall');

      // Month 1: 2024-01
      final janDate = DateTime(2024, 1, 15);
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 3000000, // ₹30,000
        accountId: monthlyAcc.id!,
        date: janDate,
        timeString: '10:00',
        createdAt: janDate,
        updatedAt: janDate,
      ));
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 2000000, // ₹20,000
        accountId: overallAcc.id!,
        date: janDate,
        timeString: '10:00',
        createdAt: janDate,
        updatedAt: janDate,
      ));

      // Month 2: 2024-02
      final febDate = DateTime(2024, 2, 10);
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1500000, // ₹15,000
        accountId: monthlyAcc.id!,
        date: febDate,
        timeString: '10:00',
        createdAt: febDate,
        updatedAt: febDate,
      ));
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1000000, // ₹10,000
        accountId: overallAcc.id!,
        date: febDate,
        timeString: '10:00',
        createdAt: febDate,
        updatedAt: febDate,
      ));

      // Test February added balances
      final febMonthlyAdded = await dbHelper.getAccountMonthlyAddedBalances(2024, 2);
      final febCumulativeAdded = await dbHelper.getAccountCumulativeAddedBalances(2024, 2);

      // Monthly account in Feb shows what was added in Feb only (₹15,000)
      expect(febMonthlyAdded[monthlyAcc.id], equals(1500000));

      // Overall account in Feb shows cumulative added up to Feb (₹20,000 + ₹10,000 = ₹30,000)
      expect(febCumulativeAdded[overallAcc.id], equals(3000000));
    });
  });
}
