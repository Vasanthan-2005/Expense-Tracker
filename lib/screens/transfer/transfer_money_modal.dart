import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/transfer.dart';
import '../../providers/account_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/date_formatter.dart';

class TransferMoneyScreen extends StatefulWidget {
  final Transfer? existingTransfer;

  const TransferMoneyScreen({super.key, this.existingTransfer});

  static Future<void> show(BuildContext context, {Transfer? existingTransfer}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => TransferMoneyScreen(existingTransfer: existingTransfer),
      ),
    );
  }

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

typedef TransferMoneyModal = TransferMoneyScreen;

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  int? _fromAccountId;
  int? _toAccountId;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingTransfer != null) {
      final tr = widget.existingTransfer!;
      _amountController.text = tr.amountDouble.toStringAsFixed(2);
      _noteController.text = tr.note ?? '';
      _fromAccountId = tr.fromAccountId;
      _toAccountId = tr.toAccountId;
      _selectedDate = tr.date;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final accounts = context.read<AccountProvider>().accounts;
        if (accounts.length >= 2) {
          setState(() {
            _fromAccountId = accounts[0].id;
            _toAccountId = accounts[1].id;
          });
        } else if (accounts.isNotEmpty) {
          setState(() {
            _fromAccountId = accounts[0].id;
          });
        }
      });
    }

    // Explicitly request focus after transition
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          _amountFocusNode.requestFocus();
        }
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveTransfer() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnackBar('Please enter a transfer amount');
      return;
    }

    final doubleAmount = double.tryParse(amountText);
    if (doubleAmount == null || doubleAmount <= 0) {
      _showSnackBar('Please enter a valid positive amount');
      return;
    }

    if (_fromAccountId == null) {
      _showSnackBar('Please select source (From) account');
      return;
    }

    if (_toAccountId == null) {
      _showSnackBar('Please select destination (To) account');
      return;
    }

    if (_fromAccountId == _toAccountId) {
      _showSnackBar('Source and destination accounts must be different');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final now = DateTime.now();
    final timeStr = widget.existingTransfer?.timeString ?? "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final amountPaise = Transfer.doubleToMinorUnits(doubleAmount);

    final transfer = Transfer(
      id: widget.existingTransfer?.id,
      amountMinorUnits: amountPaise,
      fromAccountId: _fromAccountId!,
      toAccountId: _toAccountId!,
      note: _noteController.text.trim(),
      date: _selectedDate,
      timeString: timeStr,
      createdAt: widget.existingTransfer?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final accountProvider = context.read<AccountProvider>();
      if (widget.existingTransfer == null) {
        await accountProvider.addTransfer(transfer);
      } else {
        await accountProvider.updateTransfer(transfer);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnackBar('Error transferring money: $e');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingTransfer == null ? 'Transfer Money' : 'Edit Transfer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      settings.currencySymbol,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        focusNode: _amountFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        autofocus: widget.existingTransfer == null,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
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

              // Account Selection: From -> To
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _fromAccountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'From Account',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem<int>(
                          value: acc.id,
                          child: Text(acc.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _fromAccountId = val;
                          });
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward_rounded, color: Colors.grey),
                  ),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _toAccountId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'To Account',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                      items: accounts.map((acc) {
                        return DropdownMenuItem<int>(
                          value: acc.id,
                          child: Text(acc.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _toAccountId = val;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Note / Reason Input
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Note / Reason (Optional)',
                  hintText: 'Monthly budget allocation, savings move...',
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
              const SizedBox(height: 28),

              // Save Action Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _saveTransfer,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          widget.existingTransfer == null ? 'Complete Transfer' : 'Update Transfer',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
