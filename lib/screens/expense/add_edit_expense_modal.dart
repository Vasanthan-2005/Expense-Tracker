import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/expense.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/reports_provider.dart';
import '../../providers/account_provider.dart';
import '../../core/utils/date_formatter.dart';

class AddEditExpenseModal extends StatefulWidget {
  final Expense? existingExpense;

  const AddEditExpenseModal({super.key, this.existingExpense});

  static Future<void> show(BuildContext context, {Expense? existingExpense}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddEditExpenseModal(existingExpense: existingExpense),
    );
  }

  @override
  State<AddEditExpenseModal> createState() => _AddEditExpenseModalState();
}

class _AddEditExpenseModalState extends State<AddEditExpenseModal> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _selectedCategoryId;
  int? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      final exp = widget.existingExpense!;
      _amountController.text = exp.amountDouble.toStringAsFixed(2);
      _noteController.text = exp.note ?? '';
      _selectedCategoryId = exp.categoryId;
      _selectedAccountId = exp.accountId;
      _selectedDate = exp.date;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final categories = context.read<CategoryProvider>().categories;
        final accountProvider = context.read<AccountProvider>();

        if (categories.isNotEmpty) {
          _selectedCategoryId = categories.first.id;
        }

        final accounts = accountProvider.accounts;
        final defaultAccount = accountProvider.defaultAccount;
        if (defaultAccount != null) {
          _selectedAccountId = defaultAccount.id;
        } else if (accounts.isNotEmpty) {
          _selectedAccountId = accounts.first.id;
        }

        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter an expense amount');
      return;
    }

    final doubleAmount = double.tryParse(amountText);
    if (doubleAmount == null || doubleAmount <= 0) {
      _showSnackBar('Please enter a valid positive amount');
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackBar('Please select a category');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final timeStr = widget.existingExpense?.timeString ?? "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final amountPaise = Expense.doubleToMinorUnits(doubleAmount);

    final expense = Expense(
      id: widget.existingExpense?.id,
      amountMinorUnits: amountPaise,
      categoryId: _selectedCategoryId!,
      accountId: _selectedAccountId,
      note: _noteController.text.trim(),
      date: _selectedDate,
      timeString: timeStr,
      createdAt: widget.existingExpense?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final expenseProvider = context.read<ExpenseProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final reportsProvider = context.read<ReportsProvider>();
      final accountProvider = context.read<AccountProvider>();

      if (widget.existingExpense == null) {
        await expenseProvider.addExpense(expense);
        await settingsProvider.setLastCategoryId(_selectedCategoryId!);
      } else {
        await expenseProvider.updateExpense(expense);
      }

      await accountProvider.refreshAccounts();
      await categoryProvider.refreshCategorySpent();

      final selectedCat = categoryProvider.getCategoryById(_selectedCategoryId!);
      String? budgetWarningTitle;
      String? budgetWarningBody;

      if (selectedCat != null && selectedCat.isBudgetSet) {
        final spentPaise = categoryProvider.getCategorySpentPaise(_selectedCategoryId!);
        final budgetPaise = selectedCat.monthlyBudgetPaise!;
        if (budgetPaise > 0 && spentPaise >= budgetPaise) {
          final spentStr = (spentPaise / 100.0).toStringAsFixed(0);
          final budgetStr = (budgetPaise / 100.0).toStringAsFixed(0);
          budgetWarningTitle = 'Monthly Budget Exceeded!';
          budgetWarningBody = 'Spending for "${selectedCat.name}" has reached or exceeded your monthly limit.\n\nCurrent Month Spent: ₹$spentStr\nMonthly Budget Limit: ₹$budgetStr';
        } else if (budgetPaise == 0 && spentPaise > 0) {
          final spentStr = (spentPaise / 100.0).toStringAsFixed(0);
          budgetWarningTitle = 'Zero Budget Alert!';
          budgetWarningBody = 'Spending logged for "${selectedCat.name}" which is configured with a ₹0 monthly budget limit.\n\nCurrent Month Spent: ₹$spentStr';
        }
      }

      await reportsProvider.loadReportSummary(
        categories: categoryProvider.categories,
        currencySymbol: settingsProvider.currencySymbol,
        showLoadingIndicator: false,
      );

      if (mounted) {
        final navigator = Navigator.of(context);
        navigator.pop();

        if (budgetWarningTitle != null && budgetWarningBody != null) {
          showDialog(
            context: navigator.context,
            builder: (dialogCtx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      budgetWarningTitle!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Text(
                budgetWarningBody!,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      _showSnackBar('Error saving expense: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final categories = context.watch<CategoryProvider>().categories;
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingExpense == null ? 'Add Expense' : 'Edit Expense',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Text(
                    settings.currencySymbol,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: widget.existingExpense == null,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Account Selection (All accounts created in Account Management)
            if (accounts.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final displayAccounts = accounts;
                  final defaultAccId = accountProvider.defaultAccount?.id ?? displayAccounts.first.id;
                  final currentSelectedId = (_selectedAccountId != null && displayAccounts.any((a) => a.id == _selectedAccountId))
                      ? _selectedAccountId
                      : defaultAccId;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Account',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: displayAccounts.map((acc) {
                            final isSelected = currentSelectedId == acc.id;
                            final accColor = Color(acc.colorValue);

                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                selected: isSelected,
                                showCheckmark: false,
                                avatar: Icon(
                                  acc.iconData,
                                  size: 18,
                                  color: isSelected ? Colors.white : accColor,
                                ),
                                label: Text(
                                  acc.name,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                    color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                                selectedColor: accColor,
                                backgroundColor: theme.cardColor,
                                side: BorderSide(
                                  color: isSelected ? accColor : theme.dividerColor.withValues(alpha: 0.5),
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedAccountId = acc.id;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ],

            // Category Dropdown Menu
            DropdownButtonFormField<int>(
              initialValue: (_selectedCategoryId != null && categories.any((c) => c.id == _selectedCategoryId))
                  ? _selectedCategoryId
                  : (categories.isNotEmpty ? categories.first.id : null),
              decoration: InputDecoration(
                labelText: 'Category',
                prefixIcon: const Icon(Icons.category_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: categories.map((cat) {
                final catColor = Color(cat.colorValue);
                return DropdownMenuItem<int>(
                  value: cat.id,
                  child: Row(
                    children: [
                      Icon(cat.iconData, size: 20, color: catColor),
                      const SizedBox(width: 10),
                      Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategoryId = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Description Input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Dinner with friends, groceries...',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),

            // Date Picker Field
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 12),
                    Text(
                      DateFormatter.formatRelativeDate(_selectedDate),
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveExpense,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        widget.existingExpense == null ? 'Save Expense' : 'Update Expense',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
