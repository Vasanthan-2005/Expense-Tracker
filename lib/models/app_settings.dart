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
  final int? overallMonthlyBudgetPaise;
  final String? lastCelebratedMonth;
  final bool isCelebrationEnabled;
  final String celebrationMode; // 'all_reviews' or 'positive_only'

  const AppSettings({
    this.themeOption = AppThemeOption.dark,
    this.currencySymbol = '₹',
    this.isFloatingBubbleEnabled = false,
    this.isAccountsSectionEnabled = true,
    this.lastCategoryId,
    this.exportFolderPath = 'et_app_export',
    this.overallMonthlyBudgetPaise,
    this.lastCelebratedMonth,
    this.isCelebrationEnabled = true,
    this.celebrationMode = 'all_reviews',
  });

  double get overallMonthlyBudgetDouble => (overallMonthlyBudgetPaise ?? 0) / 100.0;
  bool get isOverallBudgetSet => overallMonthlyBudgetPaise != null && overallMonthlyBudgetPaise! > 0;
  bool get isPositiveOnlyCelebration => celebrationMode == 'positive_only';

  AppSettings copyWith({
    AppThemeOption? themeOption,
    String? currencySymbol,
    bool? isFloatingBubbleEnabled,
    bool? isAccountsSectionEnabled,
    int? lastCategoryId,
    String? exportFolderPath,
    int? overallMonthlyBudgetPaise,
    bool resetOverallMonthlyBudget = false,
    String? lastCelebratedMonth,
    bool? isCelebrationEnabled,
    String? celebrationMode,
  }) {
    return AppSettings(
      themeOption: themeOption ?? this.themeOption,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isFloatingBubbleEnabled: isFloatingBubbleEnabled ?? this.isFloatingBubbleEnabled,
      isAccountsSectionEnabled: isAccountsSectionEnabled ?? this.isAccountsSectionEnabled,
      lastCategoryId: lastCategoryId ?? this.lastCategoryId,
      exportFolderPath: exportFolderPath ?? this.exportFolderPath,
      overallMonthlyBudgetPaise: resetOverallMonthlyBudget
          ? null
          : (overallMonthlyBudgetPaise ?? this.overallMonthlyBudgetPaise),
      lastCelebratedMonth: lastCelebratedMonth ?? this.lastCelebratedMonth,
      isCelebrationEnabled: isCelebrationEnabled ?? this.isCelebrationEnabled,
      celebrationMode: celebrationMode ?? this.celebrationMode,
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
      'overall_monthly_budget': overallMonthlyBudgetPaise?.toString() ?? '',
      'last_celebrated_month': lastCelebratedMonth ?? '',
      'celebration_enabled': isCelebrationEnabled ? 'true' : 'false',
      'celebration_mode': celebrationMode,
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

    final overallBudgetStr = map['overall_monthly_budget'];
    final overallBudgetPaise = (overallBudgetStr != null && overallBudgetStr.isNotEmpty)
        ? int.tryParse(overallBudgetStr)
        : null;

    final lastCelebrated = map['last_celebrated_month'];
    final accountsEnabled = map['accounts_section_enabled'] != 'false';
    final celebrationEnabled = map['celebration_enabled'] != 'false';
    final celebrationMode = map['celebration_mode'] ?? 'all_reviews';

    return AppSettings(
      themeOption: option,
      currencySymbol: map['currency_symbol'] ?? '₹',
      isFloatingBubbleEnabled: map['floating_bubble_enabled'] == 'true',
      isAccountsSectionEnabled: accountsEnabled,
      lastCategoryId: categoryId,
      exportFolderPath: map['export_folder_path'] ?? 'et_app_export',
      overallMonthlyBudgetPaise: overallBudgetPaise,
      lastCelebratedMonth: (lastCelebrated != null && lastCelebrated.isNotEmpty) ? lastCelebrated : null,
      isCelebrationEnabled: celebrationEnabled,
      celebrationMode: celebrationMode,
    );
  }
}
