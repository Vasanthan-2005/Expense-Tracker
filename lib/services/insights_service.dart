import '../models/category.dart';
import '../models/report_summary.dart';
import '../core/utils/currency_formatter.dart';

class InsightsService {
  static List<InsightItem> generateInsights({
    required int weekTotalMinor,
    required int previousWeekTotalMinor,
    required int monthTotalMinor,
    required int highestExpenseMinor,
    required String? highestExpenseNote,
    required Map<int, int> currentWeekCategoryTotals,
    required Map<int, int> previousWeekCategoryTotals,
    required List<Category> categories,
    required String currencySymbol,
  }) {
    final List<InsightItem> insights = [];

    // 1. Overall Week-over-Week Comparison Rule
    if (previousWeekTotalMinor > 0 && weekTotalMinor > 0) {
      final double diff = (weekTotalMinor - previousWeekTotalMinor) / previousWeekTotalMinor.toDouble();
      final double percent = (diff * 100).abs();
      final String formattedPercent = percent.toStringAsFixed(1);

      if (diff > 0.05) {
        insights.add(InsightItem(
          title: 'Spending Increased',
          message: 'You spent $formattedPercent% more this week (${CurrencyFormatter.formatPaise(weekTotalMinor, symbol: currencySymbol)}) compared to last week (${CurrencyFormatter.formatPaise(previousWeekTotalMinor, symbol: currencySymbol)}).',
          type: InsightType.warning,
          percentageChange: diff * 100,
        ));
      } else if (diff < -0.05) {
        insights.add(InsightItem(
          title: 'Great Savings!',
          message: 'You spent $formattedPercent% less this week (${CurrencyFormatter.formatPaise(weekTotalMinor, symbol: currencySymbol)}) compared to last week. Keep it up!',
          type: InsightType.success,
          percentageChange: diff * 100,
        ));
      } else {
        insights.add(InsightItem(
          title: 'Consistent Spending',
          message: 'Your spending this week is on par with last week (${CurrencyFormatter.formatPaise(weekTotalMinor, symbol: currencySymbol)}).',
          type: InsightType.info,
          percentageChange: 0,
        ));
      }
    }

    // 2. Category Specific Spikes Rule
    if (currentWeekCategoryTotals.isNotEmpty) {
      final categoryMap = {for (var c in categories) c.id!: c};

      int highestCatId = -1;
      int highestCatAmount = 0;

      currentWeekCategoryTotals.forEach((catId, amount) {
        if (amount > highestCatAmount) {
          highestCatAmount = amount;
          highestCatId = catId;
        }
      });

      if (highestCatId != -1 && categoryMap.containsKey(highestCatId)) {
        final catName = categoryMap[highestCatId]!.name;
        final double categoryShare = weekTotalMinor > 0 ? (highestCatAmount / weekTotalMinor) * 100 : 0;

        final prevCatAmount = previousWeekCategoryTotals[highestCatId] ?? 0;
        if (prevCatAmount > 0) {
          final double catDiff = (highestCatAmount - prevCatAmount) / prevCatAmount.toDouble();
          if (catDiff > 0.1) {
            insights.add(InsightItem(
              title: '$catName Category Spike',
              message: 'You spent ${(catDiff * 100).toStringAsFixed(0)}% more on $catName this week than last week, accounting for ${categoryShare.toStringAsFixed(0)}% of total expenses.',
              type: InsightType.warning,
              percentageChange: catDiff * 100,
            ));
          }
        } else {
          insights.add(InsightItem(
            title: 'Top Category: $catName',
            message: '$catName is your highest spending category this week, taking up ${categoryShare.toStringAsFixed(0)}% of your expenses.',
            type: InsightType.info,
          ));
        }
      }
    }

    // 3. Daily Average Rule
    if (weekTotalMinor > 0) {
      final double dailyAvg = weekTotalMinor / 7.0;
      insights.add(InsightItem(
        title: 'Daily Spending Pace',
        message: 'Your average daily spending this week is ${CurrencyFormatter.formatDouble(dailyAvg / 100.0, symbol: currencySymbol)} per day.',
        type: InsightType.info,
      ));
    }

    // 4. Single Major Expense Impact Rule
    if (highestExpenseMinor > 0 && weekTotalMinor > 0) {
      final double ratio = highestExpenseMinor / weekTotalMinor.toDouble();
      if (ratio >= 0.3) {
        final noteText = (highestExpenseNote != null && highestExpenseNote.isNotEmpty) ? ' ($highestExpenseNote)' : '';
        insights.add(InsightItem(
          title: 'Major Single Expense',
          message: 'Your highest transaction$noteText of ${CurrencyFormatter.formatPaise(highestExpenseMinor, symbol: currencySymbol)} accounted for ${(ratio * 100).toStringAsFixed(0)}% of this week\'s total.',
          type: InsightType.warning,
        ));
      }
    }

    if (insights.isEmpty) {
      insights.add(const InsightItem(
        title: 'Ready for Analysis',
        message: 'Add more expenses over consecutive days to generate personalized financial insights.',
        type: InsightType.info,
      ));
    }

    return insights;
  }
}
