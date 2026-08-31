import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category.dart';
import '../../providers/category_provider.dart';

class CategoryFormDialog extends StatefulWidget {
  final Category? existingCategory;

  const CategoryFormDialog({super.key, this.existingCategory});

  static Future<void> show(BuildContext context, {Category? existingCategory}) async {
    await showDialog(
      context: context,
      builder: (ctx) => CategoryFormDialog(existingCategory: existingCategory),
    );
  }

  @override
  State<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<CategoryFormDialog> {
  final _nameController = TextEditingController();
  final _budgetController = TextEditingController();
  late int _selectedIconCode;
  late int _selectedColorValue;
  bool _isSaving = false;

  static const List<IconData> availableIcons = [
    Icons.restaurant,
    Icons.shopping_cart,
    Icons.directions_car,
    Icons.receipt_long,
    Icons.local_gas_station,
    Icons.shopping_bag,
    Icons.medical_services,
    Icons.school,
    Icons.movie,
    Icons.home,
    Icons.subscriptions,
    Icons.person,
    Icons.fitness_center,
    Icons.flight,
    Icons.sports_esports,
    Icons.pets,
    Icons.work,
    Icons.card_giftcard,
    Icons.build,
    Icons.more_horiz,
  ];

  static const List<int> availableColors = [
    0xFFFF5722, // Orange
    0xFF4CAF50, // Green
    0xFF2196F3, // Blue
    0xFF9C27B0, // Purple
    0xFFFF9800, // Amber
    0xFFE91E63, // Pink
    0xFFF44336, // Red
    0xFF3F51B5, // Indigo
    0xFF673AB7, // Deep Purple
    0xFF795548, // Brown
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF607D8B, // Blue Grey
    0xFF8BC34A, // Light Green
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingCategory != null) {
      final cat = widget.existingCategory!;
      _nameController.text = cat.name;
      _selectedIconCode = cat.iconCodePoint;
      _selectedColorValue = cat.colorValue;
      if (cat.isBudgetSet) {
        _budgetController.text = cat.monthlyBudgetDouble.toStringAsFixed(0);
      }
    } else {
      _selectedIconCode = availableIcons.first.codePoint;
      _selectedColorValue = availableColors.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Category name cannot be empty')),
      );
      return;
    }

    int? budgetPaise;
    final budgetText = _budgetController.text.trim();
    if (budgetText.isNotEmpty) {
      final doubleVal = double.tryParse(budgetText);
      if (doubleVal != null && doubleVal >= 0) {
        budgetPaise = (doubleVal * 100).round();
      }
    }

    setState(() {
      _isSaving = true;
    });

    final categoryProvider = context.read<CategoryProvider>();

    try {
      if (widget.existingCategory == null) {
        final newCategory = Category(
          name: name,
          iconCodePoint: _selectedIconCode,
          colorValue: _selectedColorValue,
          isDefault: false,
          createdAt: DateTime.now(),
          monthlyBudgetPaise: budgetPaise,
        );
        await categoryProvider.addCategory(newCategory);
      } else {
        final updatedCategory = widget.existingCategory!.copyWith(
          name: name,
          iconCodePoint: _selectedIconCode,
          colorValue: _selectedColorValue,
          monthlyBudgetPaise: budgetPaise,
          resetMonthlyBudget: budgetText.isEmpty,
        );
        await categoryProvider.updateCategory(updatedCategory);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving category: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existingCategory == null ? 'Add Category' : 'Edit Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Category Name',
                hintText: 'e.g. Subscriptions, Gaming...',
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly Budget (Optional)',
                hintText: 'e.g. 5000 (Default: ₹0 limit)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),

            Text('Select Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            SizedBox(
              height: 120,
              width: double.maxFinite,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: availableIcons.length,
                itemBuilder: (ctx, idx) {
                  final icon = availableIcons[idx];
                  final isSelected = icon.codePoint == _selectedIconCode;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedIconCode = icon.codePoint;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? Color(_selectedColorValue).withValues(alpha: 0.2) : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected ? Border.all(color: Color(_selectedColorValue), width: 2) : null,
                      ),
                      child: Icon(icon, color: Color(_selectedColorValue), size: 20),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            Text('Select Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableColors.map((colorVal) {
                final isSelected = colorVal == _selectedColorValue;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColorValue = colorVal;
                    });
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(colorVal),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(color: Color(colorVal).withValues(alpha: 0.5), blurRadius: 6),
                            ]
                          : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
