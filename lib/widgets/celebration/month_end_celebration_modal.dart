import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/category.dart';
import 'confetti_animation.dart';

class MonthEndCelebrationModal extends StatelessWidget {
  final int year;
  final int month;
  final int totalSpentPaise;
  final int? overallBudgetPaise;
  final int overallSavedPaise;
  final List<Map<String, dynamic>> categoryBreakdown;
  final String currencySymbol;
  final bool isQualified;

  const MonthEndCelebrationModal({
    super.key,
    required this.year,
    required this.month,
    required this.totalSpentPaise,
    this.overallBudgetPaise,
    required this.overallSavedPaise,
    required this.categoryBreakdown,
    this.currencySymbol = '₹',
    this.isQualified = true,
  });

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static Future<void> show(
    BuildContext context, {
    required int year,
    required int month,
    required int totalSpentPaise,
    int? overallBudgetPaise,
    required int overallSavedPaise,
    required List<Map<String, dynamic>> categoryBreakdown,
    String currencySymbol = '₹',
    bool isQualified = true,
  }) async {
    HapticFeedback.mediumImpact();
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: MonthEndCelebrationModal(
          year: year,
          month: month,
          totalSpentPaise: totalSpentPaise,
          overallBudgetPaise: overallBudgetPaise,
          overallSavedPaise: overallSavedPaise,
          categoryBreakdown: categoryBreakdown,
          currencySymbol: currencySymbol,
          isQualified: isQualified,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthName = _monthNames[month - 1];

    final hasOverallBudget = overallBudgetPaise != null && overallBudgetPaise! > 0;
    final budgetedCategories = categoryBreakdown.where((c) => c['isBudgetSet'] == true).toList();
    final exceededCategories = budgetedCategories.where((c) => c['isWithinBudget'] == false).toList();
    final passedCategories = budgetedCategories.where((c) => c['isWithinBudget'] == true).toList();

    double overallSavingsPct = 0;
    if (hasOverallBudget && overallBudgetPaise! > 0) {
      overallSavingsPct = (overallSavedPaise / overallBudgetPaise!.toDouble()) * 100;
      if (overallSavingsPct < 0) overallSavingsPct = 0;
    }

    final modalContent = Container(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 700),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isQualified
              ? const Color(0xFFFFD700).withValues(alpha: 0.6)
              : const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isQualified
                ? const Color(0xFFFFD700).withValues(alpha: 0.25)
                : const Color(0xFF6366F1).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Badge Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isQualified
                      ? const [Color(0xFFFFDF00), Color(0xFFFFA500)]
                      : const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isQualified
                        ? const Color(0xFFFFB300).withValues(alpha: 0.5)
                        : const Color(0xFF6366F1).withValues(alpha: 0.4),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                isQualified ? Icons.emoji_events_rounded : Icons.flag_circle_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Text(
              isQualified ? '🎉 CONGRATULATIONS! 🎉' : '📊 MONTH-END BUDGET REVIEW',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isQualified ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isQualified
                  ? 'Budget Champion for $monthName $year!'
                  : '$monthName $year Performance Overview',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isQualified
                  ? 'You stayed disciplined and completed the month strictly within your budget goals!'
                  : (exceededCategories.isNotEmpty
                      ? '${exceededCategories.length} category ${exceededCategories.length == 1 ? 'limit was' : 'limits were'} exceeded. Review below to build momentum for next month!'
                      : 'Monthly spending review against your financial targets.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Overall Budget Highlight Card (if configured)
            if (hasOverallBudget) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isQualified
                        ? const [Color(0xFF10B981), Color(0xFF059669)]
                        : (overallSavedPaise >= 0
                            ? const [Color(0xFF10B981), Color(0xFF059669)]
                            : const [Color(0xFFEF4444), Color(0xFFDC2626)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: (overallSavedPaise >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          overallSavedPaise >= 0 ? 'OVERALL SAVINGS' : 'BUDGET EXCEEDED',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        if (overallSavingsPct > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${overallSavingsPct.toStringAsFixed(0)}% Saved',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      overallSavedPaise >= 0
                          ? '+${CurrencyFormatter.formatPaise(overallSavedPaise, symbol: currencySymbol)} Saved'
                          : '${CurrencyFormatter.formatPaise(-overallSavedPaise, symbol: currencySymbol)} Over Limit',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Colors.white24, height: 1),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Spent: ${CurrencyFormatter.formatPaise(totalSpentPaise, symbol: currencySymbol)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Budget: ${CurrencyFormatter.formatPaise(overallBudgetPaise!, symbol: currencySymbol)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // Category Achievements Section
            if (budgetedCategories.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'CATEGORY BREAKDOWN (${passedCategories.length}/${budgetedCategories.length} Within Budget)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: isQualified ? const Color(0xFF10B981) : theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: budgetedCategories.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, idx) {
                  final item = budgetedCategories[idx];
                  final cat = item['category'] as Category;
                  final spent = item['spentPaise'] as int;
                  final budget = (item['budgetPaise'] as int?) ?? 0;
                  final isWithin = item['isWithinBudget'] as bool;
                  final savedPaise = (item['savedPaise'] as int?) ?? 0;
                  final color = Color(cat.colorValue);

                  final double progress = budget > 0 ? (spent / budget.toDouble()).clamp(0.0, 1.0) : 1.0;

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isWithin
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(cat.iconData, color: color, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            if (isWithin)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Saved ${CurrencyFormatter.formatPaise(savedPaise, symbol: currencySymbol)}',
                                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Exceeded by ${CurrencyFormatter.formatPaise(-savedPaise, symbol: currencySymbol)}',
                                      style: const TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 4,
                                  backgroundColor: theme.dividerColor.withValues(alpha: 0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isWithin ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${CurrencyFormatter.formatPaise(spent, symbol: currencySymbol)} / ${CurrencyFormatter.formatPaise(budget, symbol: currencySymbol)}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
            ],

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: isQualified ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: Icon(isQualified ? Icons.celebration_rounded : Icons.check_circle_outline, color: Colors.white),
                label: Text(
                  isQualified ? 'Celebrate & Continue! 🏆' : 'Got it & Moving Forward! 🚀',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (isQualified) {
      return ConfettiOverlayWidget(child: modalContent);
    } else {
      return modalContent;
    }
  }
}
