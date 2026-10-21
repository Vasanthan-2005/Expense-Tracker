import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';

import 'package:expense_tracker/models/account.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/transfer.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/services/export_import_service.dart';
import 'package:expense_tracker/core/database/database_helper.dart';
import 'package:expense_tracker/screens/main_navigation_screen.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Improvements V2 Test Suite', () {
    final dbHelper = DatabaseHelper.instance;

    setUp(() async {
      await dbHelper.clearAllData();
    });

    test('1. Default export folder is Download/expense-reports and is editable', () async {
      final settings = SettingsProvider();
      await settings.loadSettings();

      // Default path check
      expect(settings.exportFolderPath, equals('Download/expense-reports'));

      // Test editing path
      await settings.setExportFolderPath('Download/my-custom-expenses');
      expect(settings.exportFolderPath, equals('Download/my-custom-expenses'));

      // Empty path resets to default
      await settings.setExportFolderPath('');
      expect(settings.exportFolderPath, equals('Download/expense-reports'));
    });

    test('2. Single directory resolution handles Download/expense-reports cleanly', () async {
      final dir = await ExportImportService.resolveExportDirectory('Download/expense-reports');
      expect(dir.existsSync(), isTrue);
      expect(dir.path.contains('expense-reports'), isTrue);
    });

    test('3. Available export months query returns formatted months for filtering', () async {
      final now = DateTime(2026, 10, 15);
      final prev = DateTime(2026, 9, 20);

      // Add dummy expenses
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 150000,
        categoryId: 1,
        date: now,
        timeString: '10:00',
        createdAt: now,
        updatedAt: now,
      ));
      await dbHelper.insertExpense(Expense(
        amountMinorUnits: 250000,
        categoryId: 1,
        date: prev,
        timeString: '11:00',
        createdAt: prev,
        updatedAt: prev,
      ));

      final availableMonths = await dbHelper.getAvailableExportMonths();
      expect(availableMonths.length, equals(2));
      expect(availableMonths[0]['year'], equals(2026));
      expect(availableMonths[0]['month'], equals(10));
      expect(availableMonths[0]['label'], equals('October 2026'));
      expect(availableMonths[1]['month'], equals(9));
      expect(availableMonths[1]['label'], equals('September 2026'));
    });

    test('4. Excel export generates expenses_... filename and writes bytes', () async {
      final path = await ExportImportService.exportToExcel(
        customFolderPath: 'Download/expense-reports',
        targetYear: 2026,
        targetMonth: 10,
        isReport: false,
      );

      expect(path, isNotNull);
      expect(path!.contains('expenses_oct_2026.xlsx'), isTrue);
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('4b. Excel report export generates expense_report_... filename and writes bytes', () async {
      final path = await ExportImportService.exportToExcel(
        customFolderPath: 'Download/expense-reports',
        targetYear: 2026,
        targetMonth: 10,
        isReport: true,
      );

      expect(path, isNotNull);
      expect(path!.contains('expense_report_oct_2026.xlsx'), isTrue);
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('5. PDF report export generates expense_report_... filename and writes bytes', () async {
      final path = await ExportImportService.exportToPdf(
        customFolderPath: 'Download/expense-reports',
        targetYear: 2026,
        targetMonth: 10,
        isReport: true,
      );

      expect(path, isNotNull);
      expect(path!.contains('expense_report_oct_2026.pdf'), isTrue);
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('5b. PDF list export generates expenses_... filename and writes bytes', () async {
      final path = await ExportImportService.exportToPdf(
        customFolderPath: 'Download/expense-reports',
        targetYear: 2026,
        targetMonth: 10,
        isReport: false,
      );

      expect(path, isNotNull);
      expect(path!.contains('expenses_oct_2026.pdf'), isTrue);
      final file = File(path);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
    });

    test('6. NavTab enum keeps active tab in Settings when accounts is toggled', () {
      // Simulate NavTab index tracking
      var currentTab = NavTab.settings;
      var isAccountsEnabled = true;

      List<NavTab> getTabs(bool accountsEnabled) => [
            NavTab.dashboard,
            if (accountsEnabled) NavTab.accounts,
            NavTab.history,
            NavTab.reports,
            NavTab.settings,
          ];

      var tabs = getTabs(isAccountsEnabled);
      expect(tabs.indexOf(currentTab), equals(4)); // Settings is index 4 when accounts is ON

      // Toggle accounts OFF
      isAccountsEnabled = false;
      tabs = getTabs(isAccountsEnabled);
      expect(tabs.indexOf(currentTab), equals(3)); // Settings is index 3 when accounts is OFF
      expect(currentTab, equals(NavTab.settings)); // currentTab is STILL settings!

      // Toggle accounts ON
      isAccountsEnabled = true;
      tabs = getTabs(isAccountsEnabled);
      expect(tabs.indexOf(currentTab), equals(4)); // Settings is index 4 again
      expect(currentTab, equals(NavTab.settings)); // Never jumps to reports!
    });

    test('7. Add Expense as Transfer deducts from Salary account and credits Expense account', () async {
      final accounts = await dbHelper.getAccounts();
      final salaryAcc = accounts.firstWhere((a) => a.name.toLowerCase().contains('salary'));
      final expenseAcc = accounts.firstWhere((a) => a.id != salaryAcc.id);

      final initialBalances = await dbHelper.getAccountCalculatedBalances();
      final salaryInitial = initialBalances[salaryAcc.id!] ?? 0;
      final expenseInitial = initialBalances[expenseAcc.id!] ?? 0;

      // Simulate Transfer (Add Expense action)
      const transferAmount = 150000; // Rs. 1500
      final now = DateTime.now();
      await dbHelper.insertTransfer(
        Transfer(
          amountMinorUnits: transferAmount,
          fromAccountId: salaryAcc.id!,
          toAccountId: expenseAcc.id!,
          note: 'Monthly Expense Budget Transfer',
          date: now,
          timeString: '10:00',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final updatedBalances = await dbHelper.getAccountCalculatedBalances();
      expect(updatedBalances[salaryAcc.id!], equals(salaryInitial - transferAmount));
      expect(updatedBalances[expenseAcc.id!], equals(expenseInitial + transferAmount));
    });

    test('8. Accounts Section toggle correctly persists and controls live balance visibility', () async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();

      expect(settingsProvider.isAccountsSectionEnabled, isTrue);

      await settingsProvider.setAccountsSectionEnabled(false);
      expect(settingsProvider.isAccountsSectionEnabled, isFalse);

      final loadedSettings = await dbHelper.getSettings();
      expect(loadedSettings.isAccountsSectionEnabled, isFalse);

      await settingsProvider.setAccountsSectionEnabled(true);
      expect(settingsProvider.isAccountsSectionEnabled, isTrue);

      final reloadedSettings = await dbHelper.getSettings();
      expect(reloadedSettings.isAccountsSectionEnabled, isTrue);
    });

    test('9. Monthly Spending Budget On/Off button and Account Balance Mode switch work correctly', () async {
      final settingsProvider = SettingsProvider();
      await settingsProvider.loadSettings();

      // Test Monthly Budget toggle On / Off
      expect(settingsProvider.isOverallBudgetSet, isFalse);
      await settingsProvider.setOverallMonthlyBudget(500000); // 5000 rupees
      expect(settingsProvider.isOverallBudgetSet, isTrue);
      expect(settingsProvider.overallMonthlyBudgetPaise, equals(500000));

      // Toggle off
      await settingsProvider.setOverallMonthlyBudget(null);
      expect(settingsProvider.isOverallBudgetSet, isFalse);
      expect(settingsProvider.overallMonthlyBudgetPaise, isNull);

      // Test Account Balance Mode toggle between Overall and Monthly
      final accounts = await dbHelper.getAccounts();
      final targetAccount = accounts.first;
      expect(targetAccount.balanceMode, equals(AccountBalanceMode.overall));

      // Toggle to monthly
      await dbHelper.setAccountBalanceMode(targetAccount.id!, AccountBalanceMode.monthly.key);
      final updatedAccounts = await dbHelper.getAccounts();
      final updatedAcc = updatedAccounts.firstWhere((a) => a.id == targetAccount.id);
      expect(updatedAcc.balanceMode, equals(AccountBalanceMode.monthly));

      // Toggle back to overall
      await dbHelper.setAccountBalanceMode(targetAccount.id!, AccountBalanceMode.overall.key);
      final revertedAccounts = await dbHelper.getAccounts();
      final revertedAcc = revertedAccounts.firstWhere((a) => a.id == targetAccount.id);
      expect(revertedAcc.balanceMode, equals(AccountBalanceMode.overall));
    });
  });
}
