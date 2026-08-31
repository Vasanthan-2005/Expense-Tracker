import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/category.dart';
import 'package:expense_tracker/models/report_summary.dart';
import 'package:expense_tracker/services/insights_service.dart';

void main() {
  group('InsightsService Offline Analytics Rule Engine', () {
    final now = DateTime.now();
    final categories = [
      Category(id: 1, name: 'Food', iconCodePoint: Icons.restaurant.codePoint, colorValue: 0xFFFF5722, createdAt: now),
      Category(id: 2, name: 'Travel', iconCodePoint: Icons.directions_car.codePoint, colorValue: 0xFF2196F3, createdAt: now),
    ];

    test('Generates warning insight on week-over-week spending increase', () {
      final insights = InsightsService.generateInsights(
        weekTotalMinor: 15000, // ₹ 150.00
        previousWeekTotalMinor: 10000, // ₹ 100.00 (50% increase)
        monthTotalMinor: 40000,
        highestExpenseMinor: 2000,
        highestExpenseNote: null,
        currentWeekCategoryTotals: {1: 15000},
        previousWeekCategoryTotals: {1: 10000},
        categories: categories,
        currencySymbol: '₹',
      );

      expect(insights.any((i) => i.type == InsightType.warning && i.title == 'Spending Increased'), isTrue);
    });

    test('Generates savings achievement insight on week-over-week reduction', () {
      final insights = InsightsService.generateInsights(
        weekTotalMinor: 8000, // ₹ 80.00
        previousWeekTotalMinor: 10000, // ₹ 100.00 (20% savings)
        monthTotalMinor: 30000,
        highestExpenseMinor: 1000,
        highestExpenseNote: null,
        currentWeekCategoryTotals: {1: 8000},
        previousWeekCategoryTotals: {1: 10000},
        categories: categories,
        currencySymbol: '₹',
      );

      expect(insights.any((i) => i.type == InsightType.success && i.title == 'Great Savings!'), isTrue);
    });

    test('Identifies category spike rule', () {
      final insights = InsightsService.generateInsights(
        weekTotalMinor: 20000,
        previousWeekTotalMinor: 18000,
        monthTotalMinor: 50000,
        highestExpenseMinor: 3000,
        highestExpenseNote: 'Cab fare',
        currentWeekCategoryTotals: {2: 12000, 1: 8000},
        previousWeekCategoryTotals: {2: 4000, 1: 14000},
        categories: categories,
        currencySymbol: '₹',
      );

      expect(insights.any((i) => i.title.contains('Travel Category Spike')), isTrue);
    });
  });
}
