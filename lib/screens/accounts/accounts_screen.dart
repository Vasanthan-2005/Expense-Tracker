import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../models/category.dart';
import '../../models/income.dart';
import '../../models/transfer.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/database/database_helper.dart';
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
                                            if (account.isCreditCard) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'CREDIT CARD',
                                                  style: TextStyle(
                                                    color: Color(0xFFF59E0B),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ] else if (account.isDefault) ...[
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
                                  Text(
                                    account.isCreditCard
                                        ? (liveBalancePaise > 0 ? 'Outstanding Credit' : 'Credit Balance')
                                        : 'Live Balance',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    CurrencyFormatter.formatPaise(liveBalancePaise, symbol: currency),
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: account.isCreditCard
                                          ? (liveBalancePaise > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981))
                                          : (liveBalancePaise >= 0 ? color : theme.colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                              // Credit Card Settled Module
                              if (account.isCreditCard)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: liveBalancePaise > 0
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: liveBalancePaise > 0
                                            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                            : const Color(0xFF10B981).withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    liveBalancePaise > 0 ? Icons.credit_score_rounded : Icons.verified_rounded,
                                                    size: 16,
                                                    color: liveBalancePaise > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    liveBalancePaise > 0 ? 'Credit to Settle' : 'Credit Settled',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 13,
                                                      color: liveBalancePaise > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                liveBalancePaise > 0
                                                    ? 'Deducts ${CurrencyFormatter.formatPaise(liveBalancePaise, symbol: currency)} from Salary Account'
                                                    : 'No outstanding bill pending',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.75),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: liveBalancePaise > 0
                                              ? () => _settleCreditCard(
                                                    context,
                                                    account,
                                                    liveBalancePaise,
                                                    currency,
                                                  )
                                              : () {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Credit Card has zero outstanding balance.'),
                                                      duration: Duration(seconds: 2),
                                                    ),
                                                  );
                                                },
                                          style: FilledButton.styleFrom(
                                            backgroundColor: liveBalancePaise > 0
                                                ? const Color(0xFFF59E0B)
                                                : const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                          icon: Icon(
                                            liveBalancePaise > 0 ? Icons.check_circle_outline_rounded : Icons.done_all_rounded,
                                            size: 16,
                                          ),
                                          label: Text(
                                            liveBalancePaise > 0 ? 'Settle' : 'Settled ✓',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
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

    final categoryProvider = context.read<CategoryProvider>();
    int? salaryCatId;
    final match = categoryProvider.incomeCategories.cast<Category?>().firstWhere(
      (c) => c?.name.toLowerCase() == 'salary',
      orElse: () => null,
    );
    salaryCatId = match?.id;

    if (salaryCatId == null) {
      final db = DatabaseHelper.instance;
      final incomeCats = await db.getCategories(type: 'income');
      final dbMatch = incomeCats.cast<Category?>().firstWhere(
        (c) => c?.name.toLowerCase() == 'salary',
        orElse: () => incomeCats.isNotEmpty ? incomeCats.first : null,
      );
      if (dbMatch != null) {
        salaryCatId = dbMatch.id;
      } else {
        final newSalaryCat = Category(
          name: 'Salary',
          iconCodePoint: Icons.payments.codePoint,
          colorValue: 0xFF10B981,
          isDefault: true,
          createdAt: now,
          sortOrder: 0,
          type: 'income',
        );
        salaryCatId = await db.insertCategory(newSalaryCat);
        await categoryProvider.loadCategories();
      }
    }

    final income = Income(
      amountMinorUnits: amountPaise,
      accountId: account.id!,
      categoryId: salaryCatId,
      sourceOrNote: 'Salary',
      date: DateTime(now.year, now.month, now.day),
      timeString: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      createdAt: now,
      updatedAt: now,
    );
    await context.read<AccountProvider>().addIncome(income);
    if (context.mounted) {
      final catProv = context.read<CategoryProvider>();
      final settings = context.read<SettingsProvider>();
      context.read<ReportsProvider>().loadReportSummary(
        categories: catProv.allCategories.isNotEmpty
            ? catProv.allCategories
            : catProv.categories,
        currencySymbol: settings.currencySymbol,
        showLoadingIndicator: false,
      );

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
      final categoryProvider = context.read<CategoryProvider>();
      int? defaultCatId;
      if (categoryProvider.incomeCategories.isNotEmpty) {
        defaultCatId = categoryProvider.incomeCategories.first.id;
      }
      final income = Income(
        amountMinorUnits: amountPaise,
        accountId: account.id!,
        categoryId: defaultCatId,
        sourceOrNote: 'Monthly Expense Budget',
        date: DateTime(now.year, now.month, now.day),
        timeString: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        createdAt: now,
        updatedAt: now,
      );
      await accountProvider.addIncome(income);
      if (context.mounted) {
        final catProv = context.read<CategoryProvider>();
        final settings = context.read<SettingsProvider>();
        context.read<ReportsProvider>().loadReportSummary(
          categories: catProv.allCategories.isNotEmpty
              ? catProv.allCategories
              : catProv.categories,
          currencySymbol: settings.currencySymbol,
          showLoadingIndicator: false,
        );

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

  Future<void> _settleCreditCard(
    BuildContext context,
    Account creditCardAccount,
    int totalOutstandingPaise,
    String currency,
  ) async {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    // Find Salary Account (or fallback non-credit account)
    Account? salaryAcc;
    for (final a in accounts) {
      if (a.id != creditCardAccount.id && a.name.toLowerCase().contains('salary')) {
        salaryAcc = a;
        break;
      }
    }
    if (salaryAcc == null) {
      for (final a in accounts) {
        if (a.id != creditCardAccount.id && !a.isCreditCard) {
          salaryAcc = a;
          break;
        }
      }
    }

    if (salaryAcc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bank or salary account found to pay from.')),
      );
      return;
    }

    final double maxAmount = totalOutstandingPaise / 100.0;
    final initialText = maxAmount % 1 == 0 ? maxAmount.toInt().toString() : maxAmount.toStringAsFixed(2);
    final amountController = TextEditingController(text: initialText);
    String? errorText;

    final int? settleAmountPaise = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final theme = Theme.of(ctx);
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.credit_score_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Settle Credit Card',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Outstanding Dues:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              CurrencyFormatter.formatPaise(totalOutstandingPaise, symbol: currency),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFF59E0B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Pay From:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Flexible(
                              child: Text(
                                salaryAcc!.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Settlement Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    autofocus: true,
                    decoration: InputDecoration(
                      prefixText: '$currency ',
                      prefixStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      hintText: '0.00',
                      errorText: errorText,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (val) {
                      if (errorText != null) {
                        setDialogState(() {
                          errorText = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          amountController.text = initialText;
                          errorText = null;
                        });
                      },
                      icon: const Icon(Icons.all_inclusive_rounded, size: 14),
                      label: Text(
                        'Full Amount ($currency$initialText)',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final raw = amountController.text.trim();
                    final parsed = double.tryParse(raw);
                    if (parsed == null || parsed <= 0) {
                      setDialogState(() {
                        errorText = 'Please enter a valid amount';
                      });
                      return;
                    }
                    final enteredPaise = (parsed * 100).round();
                    if (enteredPaise > totalOutstandingPaise) {
                      setDialogState(() {
                        errorText = 'Exceeds dues (${CurrencyFormatter.formatPaise(totalOutstandingPaise, symbol: currency)})';
                      });
                      return;
                    }
                    Navigator.pop(ctx, enteredPaise);
                  },
                  child: const Text('Confirm Settle', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (settleAmountPaise == null || settleAmountPaise <= 0) return;

    HapticFeedback.mediumImpact();
    try {
      await accountProvider.settleCreditCard(
        creditCardAccount: creditCardAccount,
        amountPaise: settleAmountPaise,
        sourceAccount: salaryAcc,
      );

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
                    'Credit card settled! ${CurrencyFormatter.formatPaise(settleAmountPaise, symbol: currency)} deducted from ${salaryAcc.name}.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to settle credit card: $e')),
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
