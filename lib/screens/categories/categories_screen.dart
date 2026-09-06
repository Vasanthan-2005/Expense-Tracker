import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category.dart';
import 'category_form_dialog.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  void _showOverallBudgetDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currency = settingsProvider.currencySymbol;
    final currentPaise = settingsProvider.overallMonthlyBudgetPaise;
    final currentRupees = currentPaise != null ? (currentPaise / 100.0).toStringAsFixed(0) : '';

    final controller = TextEditingController(text: currentRupees);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.savings_outlined, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('Overall Monthly Budget', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your global monthly spending budget limit. When your total expenses stay within this limit, you earn a month-end celebration!',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Monthly Overall Budget',
                prefixText: '$currency ',
                hintText: 'e.g. 50000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (settingsProvider.isOverallBudgetSet)
            TextButton(
              onPressed: () async {
                await settingsProvider.setOverallMonthlyBudget(null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear Limit', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                await settingsProvider.setOverallMonthlyBudget(null);
              } else {
                final doubleVal = double.tryParse(text);
                if (doubleVal != null && doubleVal > 0) {
                  final paise = (doubleVal * 100).round();
                  await settingsProvider.setOverallMonthlyBudget(paise);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context, Category category) {
    final theme = Theme.of(context);
    final categoryProvider = context.read<CategoryProvider>();

    final currentBudgetRupees = category.isBudgetSet
        ? category.monthlyBudgetDouble.toStringAsFixed(0)
        : '0';

    final controller = TextEditingController(text: currentBudgetRupees);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(category.colorValue).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(category.iconData, color: Color(category.colorValue), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${category.name} Budget',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set monthly spending limit for ${category.name}. Setting ₹0 configures a zero-budget limit, or leave empty to disable budget limit.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Monthly Budget Limit (₹)',
                prefixText: '₹ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (category.isBudgetSet)
            TextButton(
              onPressed: () async {
                if (category.id != null) {
                  await categoryProvider.updateCategoryBudget(category.id!, null);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Clear Limit', style: TextStyle(color: theme.colorScheme.error)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                if (category.id != null) {
                  await categoryProvider.updateCategoryBudget(category.id!, null);
                }
              } else {
                final doubleVal = double.tryParse(text);
                if (doubleVal != null && doubleVal >= 0 && category.id != null) {
                  final paise = (doubleVal * 100).round();
                  await categoryProvider.updateCategoryBudget(category.id!, paise);
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Budget'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteCategory(BuildContext context, Category category) async {
    final theme = Theme.of(context);
    final categoryProvider = context.read<CategoryProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text(
          'Any existing expenses assigned to this category will automatically be reassigned to another remaining category to preserve your history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete & Reassign'),
          ),
        ],
      ),
    );

    if (confirmed == true && category.id != null) {
      await categoryProvider.deleteCategory(category.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryProvider = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final categories = categoryProvider.categories;
    final currency = settings.currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories & Budgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Category',
            onPressed: () => CategoryFormDialog.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: categoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overall Monthly Budget Hero Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.15),
                            const Color(0xFF059669).withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.savings_outlined, color: Color(0xFF10B981), size: 28),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Overall Monthly Budget',
                                  style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  settings.isOverallBudgetSet
                                      ? CurrencyFormatter.formatPaise(settings.overallMonthlyBudgetPaise!, symbol: currency)
                                      : 'No Global Budget Set',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                          FilledButton(
                            onPressed: () => _showOverallBudgetDialog(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              settings.isOverallBudgetSet ? 'Edit' : '+ Set Budget',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Section Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
                    child: Text(
                      'CATEGORY BUDGET LIMITS',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: categories.length,
                    itemBuilder: (ctx, idx) {
                      final cat = categories[idx];
                      final color = Color(cat.colorValue);
                      final isBudgetSet = cat.isBudgetSet;
                      final budgetStr = cat.monthlyBudgetDouble.toStringAsFixed(0);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(cat.iconData, color: color, size: 20),
                          ),
                          title: Text(
                            cat.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            isBudgetSet
                                ? 'Limit: $currency$budgetStr / month'
                                : 'Limit: $currency 0 (No limit set)',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isBudgetSet ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                                  size: 20,
                                  color: isBudgetSet ? theme.colorScheme.primary : null,
                                ),
                                tooltip: 'Edit Budget Limit',
                                onPressed: () => _showEditBudgetDialog(context, cat),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Category',
                                onPressed: () => CategoryFormDialog.show(context, existingCategory: cat),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                                tooltip: 'Delete Category',
                                onPressed: () {
                                  if (categories.length <= 1) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Cannot delete the last remaining category.')),
                                    );
                                    return;
                                  }
                                  _confirmDeleteCategory(context, cat);
                                },
                              ),
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
}
