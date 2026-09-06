import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/income.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_income_modal.dart';

class IncomeHistoryScreen extends StatefulWidget {
  const IncomeHistoryScreen({super.key});

  static Future<void> show(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => const IncomeHistoryScreen(),
      ),
    );
  }

  @override
  State<IncomeHistoryScreen> createState() => _IncomeHistoryScreenState();
}

typedef IncomeHistoryModal = IncomeHistoryScreen;

class _IncomeHistoryScreenState extends State<IncomeHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currency = settings.currencySymbol;

    final selMonth = accountProvider.selectedIncomeMonth;
    final monthName = _monthNames[selMonth.month - 1];
    final now = DateTime.now();
    final isCurrentMonth = selMonth.year == now.year && selMonth.month == now.month;

    final accounts = accountProvider.accounts;
    final accountMap = {for (var a in accounts) a.id!: a};

    final incomes = accountProvider.monthlyIncomes;
    final totalIncomePaise = accountProvider.monthlyTotalIncomePaise;
    final accountBreakdown = accountProvider.accountIncomeBreakdown;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Income History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Income',
            onPressed: () => AddEditIncomeScreen.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                children: [
                  // Month Switcher Bar
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => accountProvider.previousIncomeMonth(),
                          tooltip: 'Previous Month',
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              '$monthName ${selMonth.year}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isCurrentMonth ? theme.disabledColor : null,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: isCurrentMonth ? null : () => accountProvider.nextIncomeMonth(),
                          tooltip: 'Next Month',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Monthly Total Income Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TOTAL RECEIVED IN $monthName'.toUpperCase(),
                              style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 1.1),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '+${CurrencyFormatter.formatPaise(totalIncomePaise, symbol: currency)}',
                              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${incomes.length} transaction${incomes.length == 1 ? '' : 's'} recorded',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: const BoxDecoration(
                            color: Colors.white24,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 26),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Account Breakdown Chips (if more than 1 account received income)
                  if (accountBreakdown.isNotEmpty) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            selected: accountProvider.incomeFilterAccountId == null,
                            label: const Text('All Accounts', style: TextStyle(fontSize: 12)),
                            onSelected: (_) => accountProvider.setIncomeFilterAccountId(null),
                          ),
                          const SizedBox(width: 8),
                          ...accountBreakdown.entries.map((entry) {
                            final acc = accountMap[entry.key];
                            if (acc == null) return const SizedBox.shrink();
                            final isSelected = accountProvider.incomeFilterAccountId == acc.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                selected: isSelected,
                                avatar: Icon(acc.iconData, size: 14, color: Color(acc.colorValue)),
                                label: Text(
                                  '${acc.name}: +${CurrencyFormatter.formatPaise(entry.value, symbol: currency)}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                ),
                                onSelected: (_) {
                                  accountProvider.setIncomeFilterAccountId(isSelected ? null : acc.id);
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search incomes by note or source...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                accountProvider.setIncomeSearchQuery('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (val) => accountProvider.setIncomeSearchQuery(val),
                  ),
                  const SizedBox(height: 14),

                  // Income Items List
                  if (incomes.isEmpty)
                    EmptyStateWidget(
                      title: 'No Income in $monthName',
                      description: 'Tap "+ Add Income" to record income received into your accounts.',
                      actionLabel: 'Add Income',
                      onAction: () => AddEditIncomeScreen.show(context),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: incomes.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final income = incomes[idx];
                        final acc = accountMap[income.accountId];
                        final accColor = acc != null ? Color(acc.colorValue) : const Color(0xFF10B981);

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: accColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(acc?.iconData ?? Icons.account_balance_wallet, color: accColor, size: 22),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    income.sourceOrNote?.isNotEmpty == true ? income.sourceOrNote! : 'Income Received',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '+${CurrencyFormatter.formatPaise(income.amountMinorUnits, symbol: currency)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: accColor.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          acc?.name ?? 'Account',
                                          style: TextStyle(color: accColor, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "${DateFormatter.formatRelativeDate(income.date)} • ${income.timeString}",
                                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        AddEditIncomeScreen.show(context, existingIncome: income);
                                      } else if (action == 'delete') {
                                        _confirmDeleteIncome(context, income);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 18),
                                            SizedBox(width: 8),
                                            Text('Edit'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 18),
                                            const SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(color: theme.colorScheme.error)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            onTap: () => AddEditIncomeScreen.show(context, existingIncome: income),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteIncome(BuildContext context, Income income) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Income Record?'),
        content: const Text(
          'This income transaction will be deleted and your live account balance will be updated automatically.',
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
      await context.read<AccountProvider>().deleteIncome(income.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income record deleted.')),
        );
      }
    }
  }
}
