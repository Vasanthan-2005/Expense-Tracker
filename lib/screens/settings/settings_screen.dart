import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/export_import_service.dart';
import '../../services/native_bubble_service.dart';
import '../../core/database/database_helper.dart';
import '../../models/app_settings.dart';
import '../accounts/accounts_screen.dart';
import '../categories/categories_screen.dart';
import '../../providers/account_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'category_order_screen.dart';

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
    final format = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export Data',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose your preferred file export format',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.table_chart_outlined,
                color: Colors.green,
              ),
              title: const Text(
                'Excel Spreadsheet (.xlsx)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Categorized sheet with all transactions'),
              onTap: () => Navigator.pop(ctx, 'excel'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.red,
              ),
              title: const Text(
                'PDF Report (.pdf)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Formatted expense statement report'),
              onTap: () => Navigator.pop(ctx, 'pdf'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.blue),
              title: const Text(
                'CSV File (.csv)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Raw CSV data format'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.integration_instructions_outlined,
                color: Colors.purple,
              ),
              title: const Text(
                'JSON Backup (.json)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Complete offline database backup'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
          ],
        ),
      ),
    );

    if (format == null) return;

    setState(() => _isExporting = true);
    try {
      String? path;
      if (format == 'excel') {
        path = await ExportImportService.exportToExcel(customFolderPath: folderPath);
      } else if (format == 'pdf') {
        path = await ExportImportService.exportToPdf(customFolderPath: folderPath);
      } else if (format == 'csv') {
        path = await ExportImportService.exportToCsv(customFolderPath: folderPath);
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
    setState(() => _isImporting = true);
    try {
      final count = await ExportImportService.importExcelOrCsv();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Appearance
            _SectionHeader(title: 'Appearance'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<AppThemeOption>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AppThemeOption.dark,
                      label: Text('Dark'),
                      icon: Icon(Icons.dark_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: AppThemeOption.pitchBlack,
                      label: Text('Pitch Black'),
                      icon: Icon(Icons.brightness_1, size: 18),
                    ),
                    ButtonSegment(
                      value: AppThemeOption.light,
                      label: Text('Light'),
                      icon: Icon(Icons.light_mode, size: 18),
                    ),
                    ButtonSegment(
                      value: AppThemeOption.emerald,
                      label: Text('Emerald'),
                      icon: Icon(Icons.eco, size: 18),
                    ),
                  ],
                  selected: {settingsProvider.themeOption},
                  onSelectionChanged: (set) {
                    settingsProvider.setThemeOption(set.first);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Preferences
            _SectionHeader(title: 'Management'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('Accounts Section'),
                    subtitle: const Text('Enable or disable accounts, balances & money transfers'),
                    value: settingsProvider.isAccountsSectionEnabled,
                    onChanged: (enabled) {
                      settingsProvider.setAccountsSectionEnabled(enabled);
                    },
                  ),
                  if (settingsProvider.isAccountsSectionEnabled) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_balance_outlined),
                      title: const Text('Manage Accounts'),
                      subtitle: const Text(
                        'Configure accounts, balances & defaults',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => const AccountsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: const Text('Manage Categories'),
                    subtitle: const Text('Add, edit, delete categories & set budget limits'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const CategoriesScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.swap_vert),
                    title: const Text('Category Display Order'),
                    subtitle: const Text('Drag and drop to reorder category list'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const CategoryOrderScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Native Floating Bubble
            _SectionHeader(title: 'Quick Access'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.bubble_chart_outlined),
                    title: const Text('Floating Quick-Add Bubble'),
                    subtitle: Text(
                      _overlayPermissionGranted
                          ? 'Appears over other apps for fast logging'
                          : 'Requires Android Overlay permission',
                    ),
                    value: settingsProvider.isFloatingBubbleEnabled,
                    onChanged: (enabled) async {
                      await settingsProvider.setFloatingBubbleEnabled(enabled);
                      _checkPermissions();
                    },
                  ),
                  if (!_overlayPermissionGranted &&
                      settingsProvider.isFloatingBubbleEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NativeBubbleService.requestPermission();
                          _checkPermissions();
                        },
                        icon: const Icon(Icons.security),
                        label: const Text('Grant Overlay Permission'),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Data & Backup
            _SectionHeader(title: 'Data Import & Export'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_open_outlined),
                    title: const Text('Export Storage Folder'),
                    subtitle: Text(settingsProvider.exportFolderPath),
                    trailing: const Icon(Icons.edit_outlined, size: 20),
                    onTap: () => _showEditExportPathDialog(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.upload_file),
                    title: const Text('Export Data'),
                    subtitle: const Text(
                      'Export to Excel (.xlsx), PDF, CSV, or JSON',
                    ),
                    trailing: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isExporting ? null : _showExportFormatDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.table_chart_outlined),
                    title: const Text('Import Data (Excel / CSV)'),
                    subtitle: const Text(
                      'Import expenses from spreadsheet (.xlsx, .csv)',
                    ),
                    trailing: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _isImporting ? null : _handleExcelImport,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.delete_forever,
                      color: theme.colorScheme.error,
                    ),
                    title: Text(
                      'Clear All Data',
                      style: TextStyle(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: const Text(
                      'Delete all transactions and custom categories',
                    ),
                    onTap: _confirmClearAllData,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: About App
            _SectionHeader(title: 'About'),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Expense Tracker'),
                    subtitle: Text('Version 1.0.0 • 100% Offline & Private'),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'This application stores all your financial data 100% locally on your device with no cloud servers, no ads, and no data tracking.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.7,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
