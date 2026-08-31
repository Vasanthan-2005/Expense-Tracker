import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/category_provider.dart';
import '../../models/category.dart';
import 'category_form_dialog.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

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
    final categories = categoryProvider.categories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Custom Category',
            onPressed: () => CategoryFormDialog.show(context),
          ),
        ],
      ),
      body: categoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
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
                          ? 'Limit: ₹$budgetStr'
                          : 'Limit: ₹0',
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CategoryFormDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
    );
  }
}
