import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/income.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import 'add_edit_income_modal.dart';

class IncomeHistoryModal extends StatefulWidget {
  const IncomeHistoryModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const IncomeHistoryModal(),
    );
  }

  @override
  State<IncomeHistoryModal> createState() => _IncomeHistoryModalState();
}

class _IncomeHistoryModalState extends State<IncomeHistoryModal> {
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

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Modal Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF10B981), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Monthly Income History',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 19),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            Expanded(
              child: ListView(
                controller: scrollController,
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
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selMonth,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                accountProvider.setSelectedIncomeMonth(picked);
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF10B981)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '$monthName ${selMonth.year}',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(Icons.arrow_drop_down_rounded, size: 18),
                              ],
                            ),
                          ),
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
                  const SizedBox(height: 14),

                  // Monthly Total Income Hero Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL INCOME IN ${monthName.toUpperCase()}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${incomes.length} ${incomes.length == 1 ? 'entry' : 'entries'}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '+${CurrencyFormatter.formatPaise(totalIncomePaise, symbol: currency)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),

                        // Account breakdown chips
                        if (accountBreakdown.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: accountBreakdown.entries.map((e) {
                              final acc = accountMap[e.key];
                              if (acc == null) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(acc.iconData, color: Colors.white, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${acc.name}: ${CurrencyFormatter.formatPaise(e.value, symbol: currency)}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search income source or notes...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                accountProvider.setIncomeSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (val) {
                      accountProvider.setIncomeSearchQuery(val);
                    },
                  ),
                  const SizedBox(height: 10),

                  // Account Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            label: const Text('All Accounts'),
                            selected: accountProvider.incomeFilterAccountId == null,
                            onSelected: (selected) {
                              accountProvider.setIncomeFilterAccountId(null);
                            },
                          ),
                        ),
                        ...accounts.map((acc) {
                          final isSelected = accountProvider.incomeFilterAccountId == acc.id;
                          final accColor = Color(acc.colorValue);
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              avatar: Icon(acc.iconData, size: 14, color: isSelected ? Colors.white : accColor),
                              label: Text(acc.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                accountProvider.setIncomeFilterAccountId(selected ? acc.id : null);
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Income Entries List
                  if (incomes.isEmpty)
                    EmptyStateWidget(
                      title: 'No Income for $monthName',
                      description: 'No income entries found for $monthName ${selMonth.year}. Tap below to log income.',
                      actionLabel: 'Add Income',
                      onAction: () => AddEditIncomeModal.show(context),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: incomes.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final income = incomes[idx];
                        final targetAccount = accountMap[income.accountId];
                        final accColor = targetAccount != null ? Color(targetAccount.colorValue) : const Color(0xFF10B981);

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.payments_outlined, color: Color(0xFF10B981), size: 22),
                            ),
                            title: Text(
                              income.sourceOrNote?.isNotEmpty == true ? income.sourceOrNote! : 'Income',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Text(
                                    "${DateFormatter.formatRelativeDate(income.date)} • ${income.timeString}",
                                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                                  ),
                                  if (targetAccount != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: accColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        targetAccount.name,
                                        style: TextStyle(color: accColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '+${CurrencyFormatter.formatPaise(income.amountMinorUnits, symbol: currency)}',
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    if (val == 'edit') {
                                      AddEditIncomeModal.show(context, existingIncome: income);
                                    } else if (val == 'delete') {
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
                                          Text('Edit Income'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, color: theme.colorScheme.error, size: 18),
                                          const SizedBox(width: 8),
                                          Text('Delete Income', style: TextStyle(color: theme.colorScheme.error)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => AddEditIncomeModal.show(context, existingIncome: income),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
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
