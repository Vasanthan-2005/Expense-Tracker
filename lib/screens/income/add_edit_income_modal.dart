import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/income.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/date_formatter.dart';

class AddEditIncomeModal extends StatefulWidget {
  final Income? existingIncome;

  const AddEditIncomeModal({super.key, this.existingIncome});

  static Future<void> show(BuildContext context, {Income? existingIncome}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddEditIncomeModal(existingIncome: existingIncome),
    );
  }

  @override
  State<AddEditIncomeModal> createState() => _AddEditIncomeModalState();
}

class _AddEditIncomeModalState extends State<AddEditIncomeModal> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingIncome != null) {
      final inc = widget.existingIncome!;
      _amountController.text = inc.amountDouble.toStringAsFixed(2);
      _noteController.text = inc.sourceOrNote ?? '';
      _selectedAccountId = inc.accountId;
      _selectedDate = inc.date;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final accounts = context.read<AccountProvider>().accounts;
        final defaultAccount = context.read<AccountProvider>().defaultAccount;
        if (mounted) {
          setState(() {
            _selectedAccountId = defaultAccount?.id ?? (accounts.isNotEmpty ? accounts.first.id : null);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter an income amount');
      return;
    }

    final doubleAmount = double.tryParse(amountText);
    if (doubleAmount == null || doubleAmount <= 0) {
      _showSnackBar('Please enter a valid positive amount');
      return;
    }

    if (_selectedAccountId == null) {
      _showSnackBar('Please select a target account');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final timeStr = widget.existingIncome?.timeString ?? "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final amountPaise = Income.doubleToMinorUnits(doubleAmount);

    final income = Income(
      id: widget.existingIncome?.id,
      amountMinorUnits: amountPaise,
      accountId: _selectedAccountId!,
      sourceOrNote: _noteController.text.trim(),
      date: _selectedDate,
      timeString: timeStr,
      createdAt: widget.existingIncome?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final accountProvider = context.read<AccountProvider>();
      if (widget.existingIncome == null) {
        await accountProvider.addIncome(income);
      } else {
        await accountProvider.updateIncome(income);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error saving income: $e');
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
    final accounts = context.watch<AccountProvider>().accounts;

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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_downward_rounded, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.existingIncome == null ? 'Add Income' : 'Edit Income',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
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
                color: const Color(0xFF10B981).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    settings.currencySymbol,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: widget.existingIncome == null,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
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

            // Target Account Dropdown
            DropdownButtonFormField<int>(
              initialValue: _selectedAccountId,
              decoration: InputDecoration(
                labelText: 'Target Account',
                prefixIcon: const Icon(Icons.account_balance),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
              items: accounts.map((acc) {
                return DropdownMenuItem<int>(
                  value: acc.id,
                  child: Row(
                    children: [
                      Icon(acc.iconData, size: 20, color: Color(acc.colorValue)),
                      const SizedBox(width: 10),
                      Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedAccountId = val;
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            // Source / Description Input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Income Source / Description',
                hintText: 'Salary, Freelance payout, Dividend...',
                prefixIcon: Icon(Icons.description_outlined),
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

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveIncome,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        widget.existingIncome == null ? 'Save Income' : 'Update Income',
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
