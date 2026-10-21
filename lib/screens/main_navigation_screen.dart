import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'dashboard/dashboard_screen.dart';
import 'history/expense_history_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/settings_screen.dart';
import 'expense/add_edit_expense_modal.dart';
import '../services/native_bubble_service.dart';
import '../providers/expense_provider.dart';
import '../providers/reports_provider.dart';

import 'accounts/accounts_screen.dart';
import '../providers/settings_provider.dart';

enum NavTab { dashboard, accounts, history, reports, settings }

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  NavTab _currentTab = NavTab.dashboard;

  @override
  void initState() {
    super.initState();
    NativeBubbleService.initializeListener(() {
      if (mounted) {
        context.read<ExpenseProvider>().refreshAll();
        context.read<ReportsProvider>().loadReportSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isAccountsEnabled = settings.isAccountsSectionEnabled;

    if (!isAccountsEnabled && _currentTab == NavTab.accounts) {
      _currentTab = NavTab.dashboard;
    }

    final List<NavTab> availableTabs = [
      NavTab.dashboard,
      if (isAccountsEnabled) NavTab.accounts,
      NavTab.history,
      NavTab.reports,
      NavTab.settings,
    ];

    int currentIndex = availableTabs.indexOf(_currentTab);
    if (currentIndex == -1) {
      currentIndex = 0;
      _currentTab = NavTab.dashboard;
    }

    final List<Widget> screens = [
      DashboardScreen(
        onViewAllHistory: () {
          setState(() {
            _currentTab = NavTab.history;
          });
        },
      ),
      if (isAccountsEnabled) const AccountsScreen(),
      const ExpenseHistoryScreen(),
      const ReportsScreen(),
      const SettingsScreen(),
    ];

    final List<NavigationDestination> destinations = [
      const NavigationDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      if (isAccountsEnabled)
        const NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Accounts',
        ),
      const NavigationDestination(
        icon: Icon(Icons.history_outlined),
        selectedIcon: Icon(Icons.history),
        label: 'History',
      ),
      const NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Reports',
      ),
      const NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        selectedIcon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: screens,
      ),
      floatingActionButton: _currentTab == NavTab.dashboard
          ? FloatingActionButton.extended(
              onPressed: () => AddEditExpenseModal.show(context),
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'Add Expense',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              elevation: 4,
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentTab = availableTabs[index];
          });
        },
        destinations: destinations,
      ),
    );
  }
}
