enum AppThemeOption {
  dark,
  pitchBlack,
  light,
  emerald,
}

class AppSettings {
  final AppThemeOption themeOption;
  final String currencySymbol;
  final bool isFloatingBubbleEnabled;
  final bool isAccountsSectionEnabled;
  final int? lastCategoryId;
  final String exportFolderPath;

  const AppSettings({
    this.themeOption = AppThemeOption.dark,
    this.currencySymbol = '₹',
    this.isFloatingBubbleEnabled = false,
    this.isAccountsSectionEnabled = true,
    this.lastCategoryId,
    this.exportFolderPath = 'et_app_export',
  });

  AppSettings copyWith({
    AppThemeOption? themeOption,
    String? currencySymbol,
    bool? isFloatingBubbleEnabled,
    bool? isAccountsSectionEnabled,
    int? lastCategoryId,
    String? exportFolderPath,
  }) {
    return AppSettings(
      themeOption: themeOption ?? this.themeOption,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isFloatingBubbleEnabled: isFloatingBubbleEnabled ?? this.isFloatingBubbleEnabled,
      isAccountsSectionEnabled: isAccountsSectionEnabled ?? this.isAccountsSectionEnabled,
      lastCategoryId: lastCategoryId ?? this.lastCategoryId,
      exportFolderPath: exportFolderPath ?? this.exportFolderPath,
    );
  }

  Map<String, String> toMap() {
    return {
      'theme_mode': themeOption.name,
      'currency_symbol': currencySymbol,
      'floating_bubble_enabled': isFloatingBubbleEnabled ? 'true' : 'false',
      'accounts_section_enabled': isAccountsSectionEnabled ? 'true' : 'false',
      'last_category_id': lastCategoryId?.toString() ?? '',
      'export_folder_path': exportFolderPath,
    };
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    AppThemeOption option;
    switch (map['theme_mode']) {
      case 'pitchBlack':
      case 'pitch_black':
        option = AppThemeOption.pitchBlack;
        break;
      case 'light':
        option = AppThemeOption.light;
        break;
      case 'emerald':
        option = AppThemeOption.emerald;
        break;
      case 'dark':
      default:
        option = AppThemeOption.dark;
    }

    final categoryIdStr = map['last_category_id'];
    final categoryId = (categoryIdStr != null && categoryIdStr.isNotEmpty)
        ? int.tryParse(categoryIdStr)
        : null;

    final accountsEnabled = map['accounts_section_enabled'] != 'false';

    return AppSettings(
      themeOption: option,
      currencySymbol: map['currency_symbol'] ?? '₹',
      isFloatingBubbleEnabled: map['floating_bubble_enabled'] == 'true',
      isAccountsSectionEnabled: accountsEnabled,
      lastCategoryId: categoryId,
      exportFolderPath: map['export_folder_path'] ?? 'et_app_export',
    );
  }
}
