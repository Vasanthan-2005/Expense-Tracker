import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:expense_tracker/main.dart';
import 'package:expense_tracker/providers/account_provider.dart';
import 'package:expense_tracker/providers/category_provider.dart';
import 'package:expense_tracker/providers/expense_provider.dart';
import 'package:expense_tracker/providers/reports_provider.dart';
import 'package:expense_tracker/providers/settings_provider.dart';
import 'package:expense_tracker/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.closeDatabase();
    await DatabaseHelper.instance.clearAllData();
  });

  testWidgets('Full UI Flow: Launch -> Dashboard -> Verify Navigation and FAB', (WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => SettingsProvider()),
            ChangeNotifierProvider(create: (_) => AccountProvider()),
            ChangeNotifierProvider(create: (_) => CategoryProvider()),
            ChangeNotifierProvider(create: (_) => ExpenseProvider()),
            ChangeNotifierProvider(create: (_) => ReportsProvider()),
          ],
          child: const ExpenseTrackerApp(),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 600));
      await tester.pump();

      // Verify Main Screen launches cleanly with AppBar title
      expect(find.text('Expense Tracker'), findsOneWidget);

      // Verify NavigationBar Destinations
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('History'), findsOneWidget);
      expect(find.text('Reports'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      // Verify Floating Action Button for Add Expense exists
      final fabFinder = find.widgetWithText(FloatingActionButton, 'Add Expense');
      expect(fabFinder, findsOneWidget);
    });
  });
}
