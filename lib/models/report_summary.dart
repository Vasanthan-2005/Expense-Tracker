enum InsightType { info, warning, success }

class InsightItem {
  final String title;
  final String message;
  final InsightType type;
  final double? percentageChange;

  const InsightItem({
    required this.title,
    required this.message,
    required this.type,
    this.percentageChange,
  });
}

class CategorySpend {
  final int categoryId;
  final String categoryName;
  final int colorValue;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int totalMinorUnits;
  final double percentage;
  final int expenseCount;

  const CategorySpend({
    required this.categoryId,
    required this.categoryName,
    required this.colorValue,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.totalMinorUnits,
    required this.percentage,
    required this.expenseCount,
  });

  double get totalDouble => totalMinorUnits / 100.0;
}

class TrendDataPoint {
  final DateTime date;
  final String label; // e.g. "Mon", "15 Aug"
  final int totalMinorUnits;

  const TrendDataPoint({
    required this.date,
    required this.label,
    required this.totalMinorUnits,
  });

  double get totalDouble => totalMinorUnits / 100.0;
}

class ReportSummary {
  final int todayTotalMinor;
  final int weekTotalMinor;
  final int monthTotalMinor;
  final int previousWeekTotalMinor;
  final int previousMonthTotalMinor;
  final int highestExpenseMinor;
  final String? highestExpenseNote;
  final double dailyAverageMinor;
  final List<CategorySpend> categoryBreakdown;
  final List<TrendDataPoint> dailyTrends; // e.g., last 7/30 days
  final List<InsightItem> insights;
  final int totalIncomeMinor;
  final int totalExpenseMinor;

  const ReportSummary({
    required this.todayTotalMinor,
    required this.weekTotalMinor,
    required this.monthTotalMinor,
    required this.previousWeekTotalMinor,
    required this.previousMonthTotalMinor,
    required this.highestExpenseMinor,
    this.highestExpenseNote,
    required this.dailyAverageMinor,
    required this.categoryBreakdown,
    required this.dailyTrends,
    required this.insights,
    this.totalIncomeMinor = 0,
    this.totalExpenseMinor = 0,
  });

  CategorySpend? get topCategory => categoryBreakdown.isNotEmpty ? categoryBreakdown.first : null;
  int get totalSpentMinor => totalExpenseMinor > 0 ? totalExpenseMinor : categoryBreakdown.fold(0, (sum, item) => sum + item.totalMinorUnits);
  double get todayTotalDouble => todayTotalMinor / 100.0;
  double get weekTotalDouble => weekTotalMinor / 100.0;
  double get monthTotalDouble => monthTotalMinor / 100.0;
  double get dailyAverageDouble => dailyAverageMinor / 100.0;
  double get highestExpenseDouble => highestExpenseMinor / 100.0;
  double get totalIncomeDouble => totalIncomeMinor / 100.0;
  double get totalExpenseDouble => totalExpenseMinor / 100.0;
}
