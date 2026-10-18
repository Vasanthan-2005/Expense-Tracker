import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/export_import_service.dart';
import '../../services/native_bubble_service.dart';
import '../../core/database/database_helper.dart';
import '../../models/app_settings.dart';
import '../../models/account.dart';
import '../categories/categories_screen.dart';
import '../../providers/account_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'category_order_screen.dart';
import '../../core/utils/currency_formatter.dart';
import '../celebration/celebrations_screen.dart';
import 'update_app_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _isExporting = false;
  bool _isImporting = false;
  bool _overlayPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final granted = await NativeBubbleService.checkPermission();
    if (mounted) {
      setState(() {
        _overlayPermissionGranted = granted;
      });
    }
  }

  Future<void> _showExportFormatDialog() async {
    final theme = Theme.of(context);
    final folderPath = context.read<SettingsProvider>().exportFolderPath;

    final availableYearsMap = await DatabaseHelper.instance.getAvailableExportYearsAndMonths();

    if (!mounted) return;

    int? selectedYear;
    int? selectedMonth;

    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final availableYears = availableYearsMap.keys.toList();
          final availableMonthsForYear = (selectedYear != null && availableYearsMap.containsKey(selectedYear))
              ? availableYearsMap[selectedYear]!
              : <int>[];

          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Financial Data',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select Year & Month filter (or All)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 16),

                // Dual Dropdowns Row (Year & Month)
                Row(
                  children: [
                    // Year Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: selectedYear,
                            isExpanded: true,
                            hint: const Text('All Years', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Years'),
                              ),
                              ...availableYears.map((y) => DropdownMenuItem<int?>(
                                    value: y,
                                    child: Text('Year $y'),
                                  )),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedYear = val;
                                selectedMonth = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Month Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: selectedMonth,
                            isExpanded: true,
                            hint: const Text('All Months', style: TextStyle(fontWeight: FontWeight.bold)),
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Months'),
                              ),
                              if (selectedYear != null)
                                ...availableMonthsForYear.map((m) => DropdownMenuItem<int?>(
                                      value: m,
                                      child: Text(monthNames[m - 1]),
                                    ))
                              else
                                ...List.generate(12, (index) => index + 1).map((m) => DropdownMenuItem<int?>(
                                      value: m,
                                      child: Text(monthNames[m - 1]),
                                    )),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                selectedMonth = val;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Text(
                  'Choose Export Format',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                ListTile(
                  leading: const Icon(Icons.table_chart, color: Color(0xFF10B981)),
                  title: const Text('Excel Spreadsheet (.xlsx)'),
                  subtitle: Text(
                    selectedYear != null
                        ? 'Formatted workbook for ${selectedMonth != null ? "${monthNames[selectedMonth! - 1]} " : ""}$selectedYear'
                        : 'Formatted workbook for all time records',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pop(ctx, {
                    'format': 'excel',
                    'year': selectedYear,
                    'month': selectedMonth,
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
                  title: const Text('PDF Document (.pdf)'),
                  subtitle: Text(
                    selectedYear != null
                        ? 'Clean summary for ${selectedMonth != null ? "${monthNames[selectedMonth! - 1]} " : ""}$selectedYear'
                        : 'Clean summary report for all records',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pop(ctx, {
                    'format': 'pdf',
                    'year': selectedYear,
                    'month': selectedMonth,
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.receipt_long, color: Color(0xFF3B82F6)),
                  title: const Text('CSV Format (.csv)'),
                  subtitle: const Text('Plain comma-separated data table'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pop(ctx, {
                    'format': 'csv',
                    'year': selectedYear,
                    'month': selectedMonth,
                  }),
                ),
                ListTile(
                  leading: const Icon(Icons.backup_table, color: Color(0xFF8B5CF6)),
                  title: const Text('Full JSON Backup (.json)'),
                  subtitle: const Text('All categories and expenses database snapshot'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pop(ctx, {'format': 'json'}),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result == null) return;

    final format = result['format'] as String;
    final targetYear = result['year'] as int?;
    final targetMonth = result['month'] as int?;

    setState(() => _isExporting = true);
    try {
      String? path;
      if (format == 'excel') {
        path = await ExportImportService.exportToExcel(
          customFolderPath: folderPath,
          targetYear: targetYear,
          targetMonth: targetMonth,
        );
      } else if (format == 'pdf') {
        path = await ExportImportService.exportToPdf(
          customFolderPath: folderPath,
          targetYear: targetYear,
          targetMonth: targetMonth,
        );
      } else if (format == 'csv') {
        path = await ExportImportService.exportToCsv(
          customFolderPath: folderPath,
          targetYear: targetYear,
          targetMonth: targetMonth,
        );
      } else if (format == 'json') {
        path = await ExportImportService.exportBackup(customFolderPath: folderPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              path != null
                  ? 'File exported successfully to: $path'
                  : 'Export completed',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handleExcelImport() async {
    final folderPath = context.read<SettingsProvider>().exportFolderPath;
    setState(() => _isImporting = true);
    try {
      final count = await ExportImportService.importExcelOrCsv(initialFolderPath: folderPath);
      if (count > 0 && mounted) {
        await context.read<ExpenseProvider>().refreshAll();
        if (mounted) {
          await context.read<AccountProvider>().refreshAccounts();
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Successfully imported $count transactions!')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid records found in file.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Excel import failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  Future<void> _confirmClearAllData() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Data?'),
        content: const Text(
          'This action will permanently delete all expense transactions and custom categories. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await DatabaseHelper.instance.clearAllData();
      if (mounted) {
        await context.read<ExpenseProvider>().refreshAll();
        if (mounted) await context.read<AccountProvider>().refreshAccounts();
        if (mounted) await context.read<CategoryProvider>().loadCategories();
        if (mounted) await context.read<SettingsProvider>().reloadSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All expense data cleared.')),
          );
        }
      }
    }
  }

  void _showEditExportPathDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final controller = TextEditingController(text: settingsProvider.exportFolderPath);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.folder_open_outlined, size: 24),
            SizedBox(width: 10),
            Text('Export Folder Path', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set the folder name or full directory path where exported files (Excel, PDF, CSV, JSON) will be saved.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Export Folder Path',
                hintText: 'et_app_export',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_outlined),
                  tooltip: 'Browse Directory',
                  onPressed: () async {
                    try {
                      final selectedDir = await FilePicker.getDirectoryPath();
                      if (selectedDir != null && selectedDir.isNotEmpty) {
                        controller.text = selectedDir;
                      }
                    } catch (_) {}
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newPath = controller.text.trim();
              await settingsProvider.setExportFolderPath(newPath.isEmpty ? 'et_app_export' : newPath);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Path'),
          ),
        ],
      ),
    );
  }

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
              'Set your global monthly spending limit. When your total monthly expenses stay within this limit, you earn a month-end celebration!',
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

  void _showSalaryCreditAmountDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currency = settingsProvider.currencySymbol;
    final currentPaise = settingsProvider.salaryCreditAmountPaise;
    final currentText = currentPaise != null ? (currentPaise / 100.0).toStringAsFixed(0) : '';
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.payments_rounded, color: Color(0xFF3B82F6)),
            SizedBox(width: 10),
            Text('Salary Credit Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set your monthly salary amount. Tapping "Salary Credited" on the Salary Account card will instantly add this income.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Salary Amount',
                prefixText: '$currency ',
                hintText: 'e.g. 50000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (settingsProvider.isSalaryCreditAmountSet)
            TextButton(
              onPressed: () async {
                await settingsProvider.setSalaryCreditAmount(null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                await settingsProvider.setSalaryCreditAmount(null);
              } else {
                final val = double.tryParse(text);
                if (val != null && val > 0) {
                  await settingsProvider.setSalaryCreditAmount((val * 100).round());
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showMonthlyExpenseAmountDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currency = settingsProvider.currencySymbol;
    final currentPaise = settingsProvider.monthlyExpenseAmountPaise;
    final currentText = currentPaise != null ? (currentPaise / 100.0).toStringAsFixed(0) : '';
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 10),
            Text('Expense Transfer Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set a fixed amount to transfer from your Salary Account to your Expense Account each month (e.g. your monthly expense budget).',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Expense Amount',
                prefixText: '$currency ',
                hintText: 'e.g. 20000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          if (settingsProvider.isMonthlyExpenseAmountSet)
            TextButton(
              onPressed: () async {
                await settingsProvider.setMonthlyExpenseAmount(null);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Clear', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) {
                await settingsProvider.setMonthlyExpenseAmount(null);
              } else {
                final val = double.tryParse(text);
                if (val != null && val > 0) {
                  await settingsProvider.setMonthlyExpenseAmount((val * 100).round());
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPickerDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final current = settingsProvider.currencySymbol;

    final currencies = [
      {'symbol': '₹', 'name': 'Indian Rupee (INR)'},
      {'symbol': '\$', 'name': 'US Dollar (USD)'},
      {'symbol': '€', 'name': 'Euro (EUR)'},
      {'symbol': '£', 'name': 'British Pound (GBP)'},
      {'symbol': '¥', 'name': 'Japanese Yen (JPY)'},
      {'symbol': 'C\$', 'name': 'Canadian Dollar (CAD)'},
      {'symbol': 'A\$', 'name': 'Australian Dollar (AUD)'},
      {'symbol': '₩', 'name': 'South Korean Won (KRW)'},
      {'symbol': '₺', 'name': 'Turkish Lira (TRY)'},
      {'symbol': '₱', 'name': 'Philippine Peso (PHP)'},
      {'symbol': 'R\$', 'name': 'Brazilian Real (BRL)'},
      {'symbol': 'AED', 'name': 'UAE Dirham (AED)'},
      {'symbol': 'SAR', 'name': 'Saudi Riyal (SAR)'},
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Select Currency Symbol',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currencies.length,
                itemBuilder: (ctx, i) {
                  final item = currencies[i];
                  final isSelected = item['symbol'] == current;
                  return ListTile(
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item['symbol']!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                    ),
                    title: Text(item['name']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      settingsProvider.setCurrencySymbol(item['symbol']!);
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. APPEARANCE & DISPLAY
            const _SectionHeader(title: 'Appearance & Display', icon: Icons.palette_outlined),
            _ModernCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'App Theme',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _ThemeOptionItem(
                            title: 'Dark',
                            option: AppThemeOption.dark,
                            selected: settingsProvider.themeOption == AppThemeOption.dark,
                            bgPreviewColor: const Color(0xFF1E293B),
                            accentPreviewColor: const Color(0xFF38BDF8),
                            onTap: () => settingsProvider.setThemeOption(AppThemeOption.dark),
                          ),
                          const SizedBox(width: 8),
                          _ThemeOptionItem(
                            title: 'Pitch',
                            option: AppThemeOption.pitchBlack,
                            selected: settingsProvider.themeOption == AppThemeOption.pitchBlack,
                            bgPreviewColor: const Color(0xFF000000),
                            accentPreviewColor: const Color(0xFFE2E8F0),
                            onTap: () => settingsProvider.setThemeOption(AppThemeOption.pitchBlack),
                          ),
                          const SizedBox(width: 8),
                          _ThemeOptionItem(
                            title: 'Light',
                            option: AppThemeOption.light,
                            selected: settingsProvider.themeOption == AppThemeOption.light,
                            bgPreviewColor: const Color(0xFFF8FAFC),
                            accentPreviewColor: const Color(0xFF2563EB),
                            onTap: () => settingsProvider.setThemeOption(AppThemeOption.light),
                          ),
                          const SizedBox(width: 8),
                          _ThemeOptionItem(
                            title: 'Emerald',
                            option: AppThemeOption.emerald,
                            selected: settingsProvider.themeOption == AppThemeOption.emerald,
                            bgPreviewColor: const Color(0xFF064E3B),
                            accentPreviewColor: const Color(0xFF34D399),
                            onTap: () => settingsProvider.setThemeOption(AppThemeOption.emerald),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.currency_exchange_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Currency Symbol',
                  subtitle: 'Current currency: ${settingsProvider.currencySymbol}',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      settingsProvider.currencySymbol,
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 14),
                    ),
                  ),
                  onTap: () => _showCurrencyPickerDialog(context),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bubble_chart_rounded, color: Color(0xFFF97316), size: 20),
                  ),
                  title: const Text('Floating Quick-Add Bubble', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                    _overlayPermissionGranted
                        ? 'Quick logging shortcut over other apps'
                        : 'Tap to grant Android Overlay permission',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: _overlayPermissionGranted ? const Color(0xFF10B981) : null,
                    ),
                  ),
                  value: settingsProvider.isFloatingBubbleEnabled,
                  onChanged: (enabled) async {
                    await settingsProvider.setFloatingBubbleEnabled(enabled);
                    _checkPermissions();
                  },
                ),
                if (!_overlayPermissionGranted && settingsProvider.isFloatingBubbleEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NativeBubbleService.requestPermission();
                          _checkPermissions();
                        },
                        icon: const Icon(Icons.security, size: 16),
                        label: const Text('Grant Overlay Permission'),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // 2. BUDGETS & GOALS
            const _SectionHeader(title: 'Budgets & Goals', icon: Icons.savings_outlined),
            _ModernCard(
              children: [
                _ModernTile(
                  icon: Icons.track_changes_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Monthly Spending Budget',
                  subtitle: settingsProvider.isOverallBudgetSet
                      ? 'Global limit: ${CurrencyFormatter.formatPaise(settingsProvider.overallMonthlyBudgetPaise!, symbol: settingsProvider.currencySymbol)} / month'
                      : 'Set a global spending limit to track targets',
                  trailing: settingsProvider.isOverallBudgetSet
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            CurrencyFormatter.formatPaise(settingsProvider.overallMonthlyBudgetPaise!, symbol: settingsProvider.currencySymbol),
                            style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () => _showOverallBudgetDialog(context),
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.emoji_events_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Celebrations & Milestones',
                  subtitle: 'Month-end popups, achievement history & streaks',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('HUB 🏆', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 10, fontWeight: FontWeight.bold)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 14, color: Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const CelebrationsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3. ACCOUNTS & QUICK CREDITS
            const _SectionHeader(title: 'Accounts & Quick Credits', icon: Icons.account_balance_wallet_outlined),
            Consumer<SettingsProvider>(
              builder: (ctx, sp, _) => _ModernCard(
                children: [
                  SwitchListTile(
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF06B6D4), size: 20),
                    ),
                    title: const Text('Accounts Feature', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Enable or disable accounts tab & live balances', style: TextStyle(fontSize: 11.5)),
                    value: sp.isAccountsSectionEnabled,
                    onChanged: (enabled) => sp.setAccountsSectionEnabled(enabled),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
                    ),
                    title: const Text('Salary Credited Button', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      sp.isSalaryCreditEnabled
                          ? (sp.isSalaryCreditAmountSet
                              ? 'Amount: ${CurrencyFormatter.formatPaise(sp.salaryCreditAmountPaise!, symbol: sp.currencySymbol)} (tap to edit)'
                              : 'Tap to set monthly salary amount')
                          : 'Quick 1-tap credit button on Salary Account',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sp.isSalaryCreditEnabled && sp.isSalaryCreditAmountSet)
                          InkWell(
                            onTap: () => _showSalaryCreditAmountDialog(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.formatPaise(sp.salaryCreditAmountPaise!, symbol: sp.currencySymbol),
                                    style: const TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: Color(0xFF10B981)),
                                ],
                              ),
                            ),
                          ),
                        Switch(
                          value: sp.isSalaryCreditEnabled,
                          onChanged: (val) {
                            sp.setSalaryCreditEnabled(val);
                            if (val && !sp.isSalaryCreditAmountSet) {
                              _showSalaryCreditAmountDialog(context);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: sp.isSalaryCreditEnabled ? () => _showSalaryCreditAmountDialog(context) : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    title: const Text('Add Expense Button', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(
                      sp.isMonthlyExpenseEnabled
                          ? (sp.isMonthlyExpenseAmountSet
                              ? 'Amount: ${CurrencyFormatter.formatPaise(sp.monthlyExpenseAmountPaise!, symbol: sp.currencySymbol)} (tap to edit)'
                              : 'Tap to set monthly expense budget')
                          : 'Quick 1-tap credit button on Expense Account',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (sp.isMonthlyExpenseEnabled && sp.isMonthlyExpenseAmountSet)
                          InkWell(
                            onTap: () => _showMonthlyExpenseAmountDialog(context),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    CurrencyFormatter.formatPaise(sp.monthlyExpenseAmountPaise!, symbol: sp.currencySymbol),
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit, size: 12, color: Color(0xFF6366F1)),
                                ],
                              ),
                            ),
                          ),
                        Switch(
                          value: sp.isMonthlyExpenseEnabled,
                          onChanged: (val) {
                            sp.setMonthlyExpenseEnabled(val);
                            if (val && !sp.isMonthlyExpenseAmountSet) {
                              _showMonthlyExpenseAmountDialog(context);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: sp.isMonthlyExpenseEnabled ? () => _showMonthlyExpenseAmountDialog(context) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. ACCOUNT BALANCE MODES
            const _SectionHeader(title: 'Account Balance Modes', icon: Icons.tune_rounded),
            const _BalanceCalculationSection(),
            const SizedBox(height: 18),

            // 5. CATEGORIES
            const _SectionHeader(title: 'Categories', icon: Icons.category_outlined),
            _ModernCard(
              children: [
                _ModernTile(
                  icon: Icons.category_outlined,
                  iconColor: const Color(0xFF8B5CF6),
                  title: 'Manage Categories',
                  subtitle: 'Add, edit, delete categories & individual budgets',
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const CategoriesScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.swap_vert_rounded,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Category Display Order',
                  subtitle: 'Drag and drop to reorder category list',
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const CategoryOrderScreen()),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 6. BACKUP & DATA
            const _SectionHeader(title: 'Backup & Data', icon: Icons.folder_shared_outlined),
            _ModernCard(
              children: [
                _ModernTile(
                  icon: Icons.upload_file_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Export Data',
                  subtitle: 'Export to Excel (.xlsx), PDF, CSV, or JSON',
                  trailing: _isExporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: _isExporting ? null : _showExportFormatDialog,
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.table_chart_outlined,
                  iconColor: const Color(0xFF3B82F6),
                  title: 'Import Data (Excel / CSV)',
                  subtitle: 'Import expenses from spreadsheet (.xlsx, .csv)',
                  trailing: _isImporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: _isImporting ? null : _handleExcelImport,
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.folder_open_outlined,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Export Storage Folder',
                  subtitle: settingsProvider.exportFolderPath,
                  trailing: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                  onTap: () => _showEditExportPathDialog(context),
                ),
                const Divider(height: 1),
                _ModernTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: theme.colorScheme.error,
                  title: 'Clear All Data',
                  subtitle: 'Delete all transactions and reset data',
                  isDestructive: true,
                  onTap: _confirmClearAllData,
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 7. ABOUT & INFO
            const _SectionHeader(title: 'About', icon: Icons.info_outline_rounded),
            _ModernCard(
              children: [
                _ModernTile(
                  icon: Icons.system_update_rounded,
                  iconColor: const Color(0xFF6366F1),
                  title: 'Update App',
                  subtitle: 'Check for updates from GitHub Releases',
                  trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (ctx) => const UpdateAppScreen()),
                    );
                  },
                ),
                const Divider(height: 1),
                const _ModernTile(
                  icon: Icons.verified_user_outlined,
                  iconColor: Color(0xFF10B981),
                  title: 'Expense Tracker Pro',
                  subtitle: 'Version 1.0.0 • 100% Offline & Private',
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'All your financial data is stored 100% locally on your device with no cloud servers, no ads, and no tracking.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _SectionHeader({required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernCard extends StatelessWidget {
  final List<Widget> children;

  const _ModernCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _ModernTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ModernTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isDestructive ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

class _ThemeOptionItem extends StatelessWidget {
  final String title;
  final AppThemeOption option;
  final bool selected;
  final Color bgPreviewColor;
  final Color accentPreviewColor;
  final VoidCallback onTap;

  const _ThemeOptionItem({
    required this.title,
    required this.option,
    required this.selected,
    required this.bgPreviewColor,
    required this.accentPreviewColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: bgPreviewColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: accentPreviewColor, width: 2),
                ),
                child: selected
                    ? Icon(Icons.check, size: 16, color: accentPreviewColor)
                    : null,
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? theme.colorScheme.primary : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows per-account balance mode selection (Overall vs Monthly).
class _BalanceCalculationSection extends StatelessWidget {
  const _BalanceCalculationSection();

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

    if (accounts.isEmpty) {
      return _ModernCard(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No accounts found. Add an account to configure balance modes.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return _ModernCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose how each account calculates its displayed balance.',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
              const SizedBox(height: 4),
              const Text(
                '• Overall: Cumulative balance from all transactions\n'
                '• Monthly: Only transactions in the selected month (resets to ₹0 each month)',
                style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.5),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...accounts.asMap().entries.map((entry) {
          final index = entry.key;
          final account = entry.value;
          final accColor = Color(account.colorValue);
          final isLast = index == accounts.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: accColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(account.iconData, color: accColor, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _BalanceModeChips(
                      accountId: account.id!,
                      currentMode: account.balanceMode,
                      onModeChanged: (mode) async {
                        await accountProvider.setAccountBalanceMode(account.id!, mode);
                      },
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1),
            ],
          );
        }),
      ],
    );
  }
}

class _BalanceModeChips extends StatelessWidget {
  final int accountId;
  final AccountBalanceMode currentMode;
  final ValueChanged<AccountBalanceMode> onModeChanged;

  const _BalanceModeChips({
    required this.accountId,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip(AccountBalanceMode mode, String label) {
      final selected = currentMode == mode;
      return GestureDetector(
        onTap: selected ? null : () {
          HapticFeedback.selectionClick();
          onModeChanged(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : theme.textTheme.bodySmall?.color,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(AccountBalanceMode.overall, 'Overall'),
        const SizedBox(width: 6),
        chip(AccountBalanceMode.monthly, 'Monthly'),
      ],
    );
  }
}
