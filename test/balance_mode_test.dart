import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/income.dart';
import 'package:expense_tracker/models/transfer.dart';
import 'package:expense_tracker/core/database/database_helper.dart';
import 'package:expense_tracker/providers/account_provider.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Account Balance — Monthly vs Overall Mode Tests', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
    });

    test('1. Default balance mode is overall for newly created accounts', () async {
      final accounts = await dbHelper.getAccounts();
      expect(accounts.isNotEmpty, isTrue);
      for (final acc in accounts) {
        expect(acc.balanceMode, equals(AccountBalanceMode.overall));
      }
    });

    test('2. Persisting balance mode to database survives reload', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');

      // Change to monthly mode
      await dbHelper.setAccountBalanceMode(salaryAcc.id!, 'monthly');

      // Reload accounts
      final reloadedAccounts = await dbHelper.getAccounts();
      final updatedSalary = reloadedAccounts.firstWhere((a) => a.id == salaryAcc.id);
      expect(updatedSalary.balanceMode, equals(AccountBalanceMode.monthly));

      // Change back to overall mode
      await dbHelper.setAccountBalanceMode(salaryAcc.id!, 'overall');
      final reloaded2 = await dbHelper.getAccounts();
      final updated2 = reloaded2.firstWhere((a) => a.id == salaryAcc.id);
      expect(updated2.balanceMode, equals(AccountBalanceMode.overall));
    });

    test('3. Dynamic monthly balance resets to 0 at new month without deleting past transactions (Prompt Example)', () async {
      final accounts = await dbHelper.getAccounts();
      final categories = await dbHelper.getCategories();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');
      final cat = categories.first;

      // Set Salary Account to monthly balance mode
      await dbHelper.setAccountBalanceMode(salaryAcc.id!, 'monthly');

      final jan10 = DateTime(2026, 1, 10);
      final jan15 = DateTime(2026, 1, 15);
      final feb5 = DateTime(2026, 2, 5);
      final feb8 = DateTime(2026, 2, 8);

      // January Transactions:
      // Income: ₹30,000 (3,000,000 paise) on Jan 10, 2026
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 3000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Jan Salary',
        date: jan10,
        timeString: '10:00',
        createdAt: jan10,
        updatedAt: jan10,
      ));

      // Expense: ₹20,000 (2,000,000 paise) on Jan 15, 2026
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 2000000,
        categoryId: cat.id!,
        accountId: salaryAcc.id!,
        note: 'Jan Rent & Food',
        date: jan15,
        timeString: '12:00',
        createdAt: jan15,
        updatedAt: jan15,
      ));

      // Verify January Monthly Balance is ₹10,000 (1,000,000 paise)
      final janBalances = await dbHelper.getAccountMonthlyBalances(2026, 1);
      expect(janBalances[salaryAcc.id], equals(1000000));

      // February: New month starts with 0 transactions.
      // February Monthly Balance starts at ₹0 dynamically!
      final febInitialBalances = await dbHelper.getAccountMonthlyBalances(2026, 2);
      expect(febInitialBalances[salaryAcc.id], equals(0));

      // Add February income: ₹32,000 on Feb 5, 2026
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 3200000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Feb Salary',
        date: feb5,
        timeString: '09:00',
        createdAt: feb5,
        updatedAt: feb5,
      ));

      // Add February expense: ₹12,000 on Feb 8, 2026
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 1200000,
        categoryId: cat.id!,
        accountId: salaryAcc.id!,
        note: 'Feb Utilities',
        date: feb8,
        timeString: '15:00',
        createdAt: feb8,
        updatedAt: feb8,
      ));

      // February Monthly balance: 32,000 - 12,000 = ₹20,000 (2,000,000 paise)
      // Must NOT carry January's balance of ₹10,000!
      final febBalances = await dbHelper.getAccountMonthlyBalances(2026, 2);
      expect(febBalances[salaryAcc.id], equals(2000000));

      // Verify January transactions were NOT modified or deleted
      final janBalancesAgain = await dbHelper.getAccountMonthlyBalances(2026, 1);
      expect(janBalancesAgain[salaryAcc.id], equals(1000000));

      // Verify Overall Balance calculates cumulative history across all months:
      // Jan net (10,000) + Feb net (20,000) = ₹30,000 (3,000,000 paise)
      final overallBalances = await dbHelper.getAccountCalculatedBalances();
      expect(overallBalances[salaryAcc.id], equals(3000000));
    });

    test('4. Transfers between accounts in Monthly mode affect both accounts correctly', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');
      final otherAcc = accounts.firstWhere((a) => a.id != salaryAcc.id);
      final jan1 = DateTime(2026, 1, 1);
      final jan5 = DateTime(2026, 1, 5);

      // Add initial January income to salary account: ₹50,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 5000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Jan Pay',
        date: jan1,
        timeString: '10:00',
        createdAt: jan1,
        updatedAt: jan1,
      ));

      // Transfer ₹15,000 from Salary -> Other in January
      await dbHelper.insertTransfer(Transfer(
        amountMinorUnits: 1500000,
        fromAccountId: salaryAcc.id!,
        toAccountId: otherAcc.id!,
        date: jan5,
        timeString: '11:00',
        note: 'Monthly allocation',
        createdAt: jan5,
        updatedAt: jan5,
      ));

      // In January:
      // Salary monthly balance: +50,000 - 15,000 = 35,000 (3,500,000 paise)
      // Other monthly balance: +15,000 (1,500,000 paise)
      final janMonthly = await dbHelper.getAccountMonthlyBalances(2026, 1);
      expect(janMonthly[salaryAcc.id], equals(3500000));
      expect(janMonthly[otherAcc.id], equals(1500000));

      // In February (no transfers in Feb):
      // Both accounts have ₹0 monthly balance
      final febMonthly = await dbHelper.getAccountMonthlyBalances(2026, 2);
      expect(febMonthly[salaryAcc.id], equals(0));
      expect(febMonthly[otherAcc.id], equals(0));
    });

    test('5. AccountProvider respects account balance modes independently', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');
      final expenseAcc = accounts.firstWhere((a) => a.id != salaryAcc.id);

      // Salary Account -> Monthly mode
      await dbHelper.setAccountBalanceMode(salaryAcc.id!, 'monthly');
      // Expense Account -> Overall mode (default)
      await dbHelper.setAccountBalanceMode(expenseAcc.id!, 'overall');

      final jan1 = DateTime(2026, 1, 1);
      final feb1 = DateTime(2026, 2, 1);

      // Jan: Salary receives ₹40,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 4000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Jan Salary',
        date: jan1,
        timeString: '09:00',
        createdAt: jan1,
        updatedAt: jan1,
      ));

      // Jan: Expense account receives ₹10,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1000000,
        accountId: expenseAcc.id!,
        sourceOrNote: 'Jan Bonus to Expense',
        date: jan1,
        timeString: '09:30',
        createdAt: jan1,
        updatedAt: jan1,
      ));

      // Feb: Salary receives ₹5,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 500000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Feb Side Gig',
        date: feb1,
        timeString: '10:00',
        createdAt: feb1,
        updatedAt: feb1,
      ));

      final provider = AccountProvider();
      await provider.refreshAccounts();

      // Check January
      await provider.setSelectedBalanceMonth(2026, 1);
      // Salary in Jan (monthly): ₹40,000
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(4000000));
      // Expense in Jan (overall): total across all months = ₹10,000
      expect(provider.getAccountBalancePaise(expenseAcc.id!), equals(1000000));

      // Check February
      await provider.setSelectedBalanceMonth(2026, 2);
      // Salary in Feb (monthly): only Feb transactions = ₹5,000 (starts fresh!)
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(500000));
      // Expense in Feb (overall): still all-time total = ₹10,000
      expect(provider.getAccountBalancePaise(expenseAcc.id!), equals(1000000));
    });

    test('6. Dynamic switching from Monthly to Overall immediately returns overall balance', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name == 'Salary Account');

      // Start with Monthly
      await dbHelper.setAccountBalanceMode(salaryAcc.id!, 'monthly');

      final jan1 = DateTime(2026, 1, 1);
      final feb1 = DateTime(2026, 2, 1);

      // Jan income: 30,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 3000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Jan Salary',
        date: jan1,
        timeString: '09:00',
        createdAt: jan1,
        updatedAt: jan1,
      ));

      // Feb income: 10,000
      await dbHelper.insertIncome(Income(
        amountMinorUnits: 1000000,
        accountId: salaryAcc.id!,
        sourceOrNote: 'Feb Salary',
        date: feb1,
        timeString: '09:00',
        createdAt: feb1,
        updatedAt: feb1,
      ));

      final provider = AccountProvider();
      await provider.refreshAccounts();
      await provider.setSelectedBalanceMonth(2026, 2);

      // In Feb, monthly balance is 10,000
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(1000000));

      // Switch to overall mode
      await provider.setAccountBalanceMode(salaryAcc.id!, AccountBalanceMode.overall);

      // Immediately reflects overall balance: 30,000 + 10,000 = 40,000
      expect(provider.getAccountBalancePaise(salaryAcc.id!), equals(4000000));
    });
  });
}
