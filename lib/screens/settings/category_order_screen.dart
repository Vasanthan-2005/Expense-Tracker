import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/category_provider.dart';

class CategoryOrderScreen extends StatefulWidget {
  const CategoryOrderScreen({super.key});

  @override
  State<CategoryOrderScreen> createState() => _CategoryOrderScreenState();
}

class _CategoryOrderScreenState extends State<CategoryOrderScreen> {
  String _selectedType = 'expense';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryProvider = context.watch<CategoryProvider>();
    final categories = _selectedType == 'expense'
        ? categoryProvider.expenseCategories
        : categoryProvider.incomeCategories;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Category Display Order'),
      ),
      body: categoryProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'expense',
                        label: Text('Expense Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        icon: Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                      ButtonSegment<String>(
                        value: 'income',
                        label: Text('Income Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        icon: Icon(Icons.arrow_downward_rounded, size: 16),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (val) {
                      setState(() {
                        _selectedType = val.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Card(
                    elevation: 0,
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(Icons.swap_vert, color: theme.colorScheme.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Drag and drop to customize display order. Selectors will reflect this exact order.',
                              style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: categories.length,
                    onReorderItem: (oldIndex, newIndex) {
                      categoryProvider.reorderCategories(oldIndex, newIndex, type: _selectedType);
                    },
                    itemBuilder: (ctx, index) {
                      final cat = categories[index];
                      final catColor = Color(cat.colorValue);

                      return Card(
                        key: ValueKey('category_order_${cat.id}_$index'),
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(cat.iconData, color: catColor, size: 20),
                          ),
                          title: Text(
                            cat.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            cat.isBudgetSet
                                ? 'Budget: ₹${cat.monthlyBudgetDouble.toStringAsFixed(0)}/mo'
                                : 'Order #${index + 1}',
                            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                          ),
                          trailing: ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.drag_handle, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
