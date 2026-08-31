import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../core/database/database_helper.dart';
import '../services/native_bubble_service.dart';

class SettingsProvider with ChangeNotifier {
  bool _isDisposed = false;
  AppSettings _settings = const AppSettings();
  bool _isLoading = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  AppSettings get settings => _settings;
  AppThemeOption get themeOption => _settings.themeOption;
  String get currencySymbol => _settings.currencySymbol;
  bool get isFloatingBubbleEnabled => _settings.isFloatingBubbleEnabled;
  bool get isAccountsSectionEnabled => _settings.isAccountsSectionEnabled;
  int? get lastCategoryId => _settings.lastCategoryId;
  String get exportFolderPath => _settings.exportFolderPath;
  bool get isLoading => _isLoading;

  SettingsProvider() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _settings = await DatabaseHelper.instance.getSettings();
      await NativeBubbleService.updateTheme(_settings.themeOption.name);
      if (_settings.isFloatingBubbleEnabled) {
        final granted = await NativeBubbleService.checkPermission();
        if (granted) {
          await NativeBubbleService.startBubble();
        }
      }
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> checkAndSyncBubbleState() async {
    if (_settings.isFloatingBubbleEnabled) {
      final granted = await NativeBubbleService.checkPermission();
      if (granted) {
        await NativeBubbleService.startBubble();
      }
    }
  }

  Future<void> setThemeOption(AppThemeOption option) async {
    _settings = _settings.copyWith(themeOption: option);
    notifyListeners();
    await DatabaseHelper.instance.updateSetting('theme_mode', option.name);
    await NativeBubbleService.updateTheme(option.name);
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _settings = _settings.copyWith(currencySymbol: symbol);
    notifyListeners();
    await DatabaseHelper.instance.updateSetting('currency_symbol', symbol);
  }

  Future<void> setAccountsSectionEnabled(bool enabled) async {
    _settings = _settings.copyWith(isAccountsSectionEnabled: enabled);
    notifyListeners();
    await DatabaseHelper.instance.updateSetting('accounts_section_enabled', enabled ? 'true' : 'false');
  }

  Future<void> setFloatingBubbleEnabled(bool enabled) async {
    if (enabled) {
      _settings = _settings.copyWith(isFloatingBubbleEnabled: true);
      notifyListeners();
      await DatabaseHelper.instance.updateSetting('floating_bubble_enabled', 'true');

      final granted = await NativeBubbleService.checkPermission();
      if (!granted) {
        await NativeBubbleService.requestPermission();
        final recheck = await NativeBubbleService.checkPermission();
        if (recheck) {
          await NativeBubbleService.startBubble();
        }
        return;
      }
      await NativeBubbleService.startBubble();
    } else {
      _settings = _settings.copyWith(isFloatingBubbleEnabled: false);
      notifyListeners();
      await DatabaseHelper.instance.updateSetting('floating_bubble_enabled', 'false');
      await NativeBubbleService.stopBubble();
    }
  }

  Future<void> setLastCategoryId(int categoryId) async {
    _settings = _settings.copyWith(lastCategoryId: categoryId);
    notifyListeners();
    await DatabaseHelper.instance.updateSetting('last_category_id', categoryId.toString());
  }

  Future<void> setExportFolderPath(String path) async {
    final cleanPath = path.trim().isEmpty ? 'et_app_export' : path.trim();
    _settings = _settings.copyWith(exportFolderPath: cleanPath);
    notifyListeners();
    await DatabaseHelper.instance.updateSetting('export_folder_path', cleanPath);
  }

  Future<void> reloadSettings() async {
    await loadSettings();
  }
}
