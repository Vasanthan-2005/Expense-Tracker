import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';

class AddEditAccountModal extends StatefulWidget {
  final Account? existingAccount;

  const AddEditAccountModal({super.key, this.existingAccount});

  static Future<void> show(BuildContext context, {Account? existingAccount}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddEditAccountModal(existingAccount: existingAccount),
    );
  }

  @override
  State<AddEditAccountModal> createState() => _AddEditAccountModalState();
}

class _AddEditAccountModalState extends State<AddEditAccountModal> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();

  int _selectedIconCode = Icons.account_balance.codePoint;
  int _selectedColorValue = 0xFF10B981; // Emerald
  bool _isDefault = false;
  AccountBalanceMode _balanceMode = AccountBalanceMode.overall;
  bool _isSaving = false;

  static const List<IconData> availableIcons = [
    Icons.account_balance,
    Icons.account_balance_wallet,
    Icons.savings,
    Icons.credit_card,
    Icons.monetization_on,
    Icons.payments,
    Icons.currency_rupee,
    Icons.attach_money,
    Icons.work_outline,
    Icons.storefront,
  ];

  static const List<int> availableColors = [
    0xFF10B981, // Emerald
    0xFF6366F1, // Indigo
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
    0xFF8B5CF6, // Purple
    0xFF06B6D4, // Cyan
    0xFFEC4899, // Pink
    0xFF3B82F6, // Blue
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      final acc = widget.existingAccount!;
      _nameController.text = acc.name;
      _openingBalanceController.text = acc.openingBalanceDouble.toStringAsFixed(2);
      _selectedIconCode = acc.iconCodePoint;
      _selectedColorValue = acc.colorValue;
      _isDefault = acc.isDefault;
      _balanceMode = acc.balanceMode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    final nameText = _nameController.text.trim();
    if (nameText.isEmpty) {
      _showSnackBar('Please enter an account name');
      return;
    }

    final balanceText = _openingBalanceController.text.trim();
    final doubleBalance = balanceText.isEmpty ? 0.0 : double.tryParse(balanceText);
    if (doubleBalance == null) {
      _showSnackBar('Please enter a valid opening balance');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final account = Account(
      id: widget.existingAccount?.id,
      name: nameText,
      openingBalanceMinorUnits: Account.doubleToMinorUnits(doubleBalance),
      iconCodePoint: _selectedIconCode,
      colorValue: _selectedColorValue,
      isDefault: _isDefault,
      balanceMode: _balanceMode,
      createdAt: widget.existingAccount?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final accountProvider = context.read<AccountProvider>();
      if (widget.existingAccount == null) {
        await accountProvider.addAccount(account);
      } else {
        await accountProvider.updateAccount(account);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error saving account: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

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
                  widget.existingAccount == null ? 'Create Account' : 'Edit Account',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (widget.existingAccount == null) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    Text('Quick Presets: ', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    ActionChip(
                      avatar: const Icon(Icons.payments, size: 16, color: Color(0xFF10B981)),
                      label: const Text('Cash', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _nameController.text = 'Cash';
                          _selectedIconCode = Icons.payments.codePoint;
                          _selectedColorValue = 0xFF10B981;
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.account_balance_wallet, size: 16, color: Color(0xFF6366F1)),
                      label: const Text('UPI / Bank', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _nameController.text = 'UPI / Bank';
                          _selectedIconCode = Icons.account_balance_wallet.codePoint;
                          _selectedColorValue = 0xFF6366F1;
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    ActionChip(
                      avatar: const Icon(Icons.account_balance, size: 16, color: Color(0xFF3B82F6)),
                      label: const Text('Salary Account', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _nameController.text = 'Salary Account';
                          _selectedIconCode = Icons.account_balance.codePoint;
                          _selectedColorValue = 0xFF3B82F6;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Account Name',
                hintText: 'Salary Account, Emergency Savings...',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Opening Balance Input
            TextField(
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Opening Balance',
                hintText: '0.00',
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    settings.currencySymbol,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Icon Picker Carousel
            Text('Account Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableIcons.length,
                itemBuilder: (ctx, idx) {
                  final icon = availableIcons[idx];
                  final isSelected = icon.codePoint == _selectedIconCode;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedIconCode = icon.codePoint),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Color(_selectedColorValue).withValues(alpha: 0.2)
                              : theme.cardColor,
                          border: Border.all(
                            color: isSelected ? Color(_selectedColorValue) : theme.dividerColor,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Color(_selectedColorValue) : theme.iconTheme.color,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Color Picker Carousel
            Text('Account Color Accent', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: availableColors.length,
                itemBuilder: (ctx, idx) {
                  final colorVal = availableColors[idx];
                  final isSelected = colorVal == _selectedColorValue;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColorValue = colorVal),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(colorVal),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: Color(colorVal).withValues(alpha: 0.5), blurRadius: 8)]
                              : null,
                        ),
                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Set as Default Expense Account Switch
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Default Expense Account', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Automatically selected for quick expenses & floating bubble'),
              value: _isDefault,
              onChanged: (val) => setState(() => _isDefault = val),
            ),
            const SizedBox(height: 16),

            // Balance Calculation Mode Selector
            Text('Balance Calculation Mode', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<AccountBalanceMode>(
              segments: const [
                ButtonSegment(
                  value: AccountBalanceMode.overall,
                  label: Text('Overall Balance'),
                  icon: Icon(Icons.all_inclusive_rounded, size: 16),
                ),
                ButtonSegment(
                  value: AccountBalanceMode.monthly,
                  label: Text('Monthly Balance'),
                  icon: Icon(Icons.calendar_month_rounded, size: 16),
                ),
              ],
              selected: {_balanceMode},
              onSelectionChanged: (set) => setState(() => _balanceMode = set.first),
            ),
            const SizedBox(height: 6),
            Text(
              _balanceMode == AccountBalanceMode.monthly
                  ? '• Starts from ₹0 each month and only counts this month\'s transactions.'
                  : '• Cumulative balance from all historical transactions.',
              style: TextStyle(fontSize: 11.5, color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 24),

            // Save Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _isSaving ? null : _saveAccount,
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
                        widget.existingAccount == null ? 'Create Account' : 'Update Account',
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
