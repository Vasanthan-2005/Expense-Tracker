import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/income.dart';
import '../../models/transfer.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import 'add_edit_account_modal.dart';
import '../income/add_edit_income_modal.dart';
import '../income/income_history_modal.dart';
import '../transfer/transfer_money_modal.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();

    final accounts = accountProvider.accounts;
    final currency = settings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Accounts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Income History',
            onPressed: () => IncomeHistoryModal.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Add Account',
            onPressed: () => AddEditAccountModal.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddEditAccountModal.show(context),
        icon: const Icon(Icons.add_card_rounded),
        label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: accountProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Actions Bar: Income | Transfer
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => AddEditIncomeModal.show(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF10B981), size: 18),
                          label: const Text('Income', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => TransferMoneyModal.show(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.swap_horiz, color: Color(0xFF6366F1), size: 18),
                          label: const Text('Transfer', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Total Net Worth Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.colorScheme.secondary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Net Balance', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.formatPaise(accountProvider.totalNetWorthPaise, symbol: currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.account_balance, color: theme.colorScheme.primary, size: 24),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Accounts & Live Balances',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: accounts.length,
                    itemBuilder: (ctx, idx) {
                      final account = accounts[idx];
                      final liveBalancePaise = accountProvider.getAccountBalancePaise(account.id!);
                      final color = Color(account.colorValue);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: account.isDefault ? color : theme.dividerColor.withValues(alpha: 0.5),
                            width: account.isDefault ? 2 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(account.iconData, color: color, size: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                account.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (account.isDefault) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: color.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'DEFAULT EXPENSE',
                                                  style: TextStyle(
                                                    color: color,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    onSelected: (val) async {
                                      if (val == 'edit') {
                                        AddEditAccountModal.show(context, existingAccount: account);
                                      } else if (val == 'default') {
                                        await accountProvider.setDefaultAccount(account.id!);
                                      } else if (val == 'delete') {
                                        _confirmDelete(context, account);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 20),
                                            SizedBox(width: 8),
                                            Text('Edit Account'),
                                          ],
                                        ),
                                      ),
                                      if (!account.isDefault)
                                        const PopupMenuItem(
                                          value: 'default',
                                          child: Row(
                                            children: [
                                              Icon(Icons.star_outline, size: 20),
                                              SizedBox(width: 8),
                                              Text('Set as Default'),
                                            ],
                                          ),
                                        ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 20),
                                            const SizedBox(width: 8),
                                            Text('Delete Account', style: TextStyle(color: theme.colorScheme.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Live Balance',
                                    style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(liveBalancePaise, symbol: currency),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: liveBalancePaise >= 0 ? color : theme.colorScheme.error,
                                    ),
                                  ),
                                ],
                              ),
                              // Quick Credit Buttons
                              Builder(builder: (context) {
                                final sp = context.watch<SettingsProvider>();
                                final lowerName = account.name.toLowerCase();
                                final isSalaryAcc = lowerName.contains('salary');
                                final isExpenseAcc = account.isDefault || lowerName.contains('expense');

                                final showSalaryBtn = isSalaryAcc &&
                                    sp.isSalaryCreditEnabled &&
                                    sp.isSalaryCreditAmountSet;
                                final showExpenseBtn = isExpenseAcc &&
                                    sp.isMonthlyExpenseEnabled &&
                                    sp.isMonthlyExpenseAmountSet;

                                if (!showSalaryBtn && !showExpenseBtn) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if (showSalaryBtn)
                                        _QuickCreditButton(
                                          label: 'Salary Credited',
                                          amount: sp.salaryCreditAmountPaise!,
                                          currency: currency,
                                          color: const Color(0xFF10B981),
                                          icon: Icons.payments_rounded,
                                          onTap: () => _creditSalary(
                                            context,
                                            account,
                                            sp.salaryCreditAmountPaise!,
                                            currency,
                                          ),
                                        ),
                                      if (showExpenseBtn)
                                        _QuickCreditButton(
                                          label: 'Monthly Expense',
                                          amount: sp.monthlyExpenseAmountPaise!,
                                          currency: currency,
                                          color: const Color(0xFF6366F1),
                                          icon: Icons.account_balance_wallet_rounded,
                                          onTap: () => _creditExpense(
                                            context,
                                            account,
                                            sp.monthlyExpenseAmountPaise!,
                                            currency,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _confirmDelete(BuildContext context, Account account) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${account.name}?'),
        content: const Text(
          'Any expenses and incomes linked to this account will be safely reassigned to another remaining account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await context.read<AccountProvider>().deleteAccount(account.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${account.name} deleted.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cannot delete account: $e')),
          );
        }
      }
    }
  }

  Future<void> _creditSalary(
    BuildContext context,
    Account account,
    int amountPaise,
    String currency,
  ) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final income = Income(
      amountMinorUnits: amountPaise,
      accountId: account.id!,
      sourceOrNote: 'Salary',
      date: DateTime(now.year, now.month, now.day),
      timeString: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      updatedAt: now,
    );
    await context.read<AccountProvider>().addIncome(income);
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Salary ${CurrencyFormatter.formatPaise(amountPaise, symbol: currency)} credited to ${account.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _creditExpense(
    BuildContext context,
    Account account,
    int amountPaise,
    String currency,
  ) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    // Find the Salary Account
    Account? salaryAccount;
    for (final acc in accounts) {
      if (acc.id != account.id && acc.name.toLowerCase().contains('salary')) {
        salaryAccount = acc;
        break;
      }
    }
    // Fallback to any remaining account if none is explicitly named 'salary'
    if (salaryAccount == null && accounts.length > 1) {
      salaryAccount = accounts.firstWhere((a) => a.id != account.id);
    }

    if (salaryAccount != null) {
      final transfer = Transfer(
        amountMinorUnits: amountPaise,
        fromAccountId: salaryAccount.id!,
        toAccountId: account.id!,
        note: 'Monthly Expense Budget Transfer',
        date: DateTime(now.year, now.month, now.day),
        timeString: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        createdAt: now,
        updatedAt: now,
      );
      await accountProvider.addTransfer(transfer);

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${CurrencyFormatter.formatPaise(amountPaise, symbol: currency)} transferred from ${salaryAccount.name} to ${account.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } else {
      final income = Income(
        amountMinorUnits: amountPaise,
        accountId: account.id!,
        sourceOrNote: 'Monthly Expense Budget',
        date: DateTime(now.year, now.month, now.day),
        timeString: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        createdAt: now,
        updatedAt: now,
      );
      await accountProvider.addIncome(income);
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${CurrencyFormatter.formatPaise(amountPaise, symbol: currency)} credited to ${account.name}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6366F1),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }
}

class _QuickCreditButton extends StatelessWidget {
  final String label;
  final int amount;
  final String currency;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCreditButton({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashColor: color.withValues(alpha: 0.25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  CurrencyFormatter.formatPaise(amount, symbol: currency),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
