import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transfer.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../widgets/empty_state.dart';
import 'transfer_money_modal.dart';

class TransferHistoryModal extends StatelessWidget {
  const TransferHistoryModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const TransferHistoryModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final accountProvider = context.watch<AccountProvider>();
    final currency = settings.currencySymbol;

    final transfers = accountProvider.recentTransfers;
    final accounts = accountProvider.accounts;
    final accountMap = {for (var a in accounts) a.id!: a};

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
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
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Transfer History',
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
              child: transfers.isEmpty
                  ? Center(
                      child: EmptyStateWidget(
                        title: 'No Transfers Recorded',
                        description: 'Transfer money between your accounts (e.g. Bank to Cash).',
                        actionLabel: 'Transfer Money',
                        onAction: () => TransferMoneyModal.show(context),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: transfers.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, idx) {
                        final tr = transfers[idx];
                        final fromAcc = accountMap[tr.fromAccountId];
                        final toAcc = accountMap[tr.toAccountId];

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.swap_horiz, color: Color(0xFF6366F1), size: 24),
                            ),
                            title: Row(
                              children: [
                                Text(fromAcc?.name ?? 'Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.grey),
                                ),
                                Text(toAcc?.name ?? 'Account', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                "${DateFormatter.formatRelativeDate(tr.date)} • ${tr.timeString}${tr.note?.isNotEmpty == true ? ' • ${tr.note}' : ''}",
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  CurrencyFormatter.formatPaise(tr.amountMinorUnits, symbol: currency),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF6366F1),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: theme.colorScheme.error),
                                  tooltip: 'Delete Transfer',
                                  onPressed: () => _confirmDeleteTransfer(context, tr),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteTransfer(BuildContext context, Transfer transfer) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transfer?'),
        content: const Text(
          'This transfer will be removed and live account balances will be adjusted automatically.',
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
      await context.read<AccountProvider>().deleteTransfer(transfer.id!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer record deleted.')),
        );
      }
    }
  }
}
