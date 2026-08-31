import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/report_summary.dart';
import '../core/utils/currency_formatter.dart';

class SpendingLineChart extends StatelessWidget {
  final List<TrendDataPoint> trends;
  final String currencySymbol;
  final double height;

  const SpendingLineChart({
    super.key,
    required this.trends,
    required this.currencySymbol,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.primary;

    if (trends.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('No trend data available')),
      );
    }

    final maxVal = trends.fold<double>(0.0, (max, item) => math.max(max, item.totalDouble));

    return Column(
      children: [
        SizedBox(
          height: height - 30,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              trends: trends,
              maxValue: maxVal == 0 ? 100 : maxVal,
              lineColor: lineColor,
              gridColor: theme.dividerColor.withValues(alpha: 0.2),
              textColor: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6) ?? Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Horizontal Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: trends.asMap().entries.map((entry) {
            // Show subset of labels if many points
            final showLabel = trends.length <= 7 || entry.key % (trends.length ~/ 4) == 0;
            return Text(
              showLabel ? entry.value.label : '',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<TrendDataPoint> trends;
  final double maxValue;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;

  _LineChartPainter({
    required this.trends,
    required this.maxValue,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trends.length < 2) return;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGrid = Paint()
      ..color = gridColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final paintDot = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    final paintDotInner = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Draw horizontal grid lines (3 lines)
    for (int i = 0; i <= 3; i++) {
      final y = size.height - (size.height / 3 * i);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paintGrid);
    }

    final double stepX = size.width / (trends.length - 1);
    final List<Offset> points = [];

    for (int i = 0; i < trends.length; i++) {
      final x = i * stepX;
      final normalizedY = (trends[i].totalDouble / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalizedY * (size.height - 20)) - 10;
      points.add(Offset(x, y));
    }

    // Path for gradient fill
    final pathArea = Path();
    pathArea.moveTo(points.first.dx, size.height);
    pathArea.lineTo(points.first.dx, points.first.dy);

    final pathLine = Path();
    pathLine.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlPoint1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlPoint2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);

      pathLine.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
      pathArea.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p2.dx, p2.dy);
    }

    pathArea.lineTo(points.last.dx, size.height);
    pathArea.close();

    // Area Gradient
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.35),
        lineColor.withValues(alpha: 0.0),
      ],
    );

    final paintArea = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(pathArea, paintArea);
    canvas.drawPath(pathLine, paintLine);

    // Draw data dots
    for (final pt in points) {
      canvas.drawCircle(pt, 5, paintDot);
      canvas.drawCircle(pt, 2.5, paintDotInner);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.trends != trends ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor;
  }
}

class CategoryDonutChart extends StatelessWidget {
  final List<CategorySpend> categories;
  final String currencySymbol;
  final double size;

  const CategoryDonutChart({
    super.key,
    required this.categories,
    required this.currencySymbol,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPaise = categories.fold<int>(0, (sum, item) => sum + item.totalMinorUnits);

    if (totalPaise == 0) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('No expense data')),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutChartPainter(
              categories: categories,
              totalPaise: totalPaise,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                CurrencyFormatter.formatPaise(totalPaise, symbol: currencySymbol),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<CategorySpend> categories;
  final int totalPaise;

  _DonutChartPainter({
    required this.categories,
    required this.totalPaise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 20.0;

    double startAngle = -math.pi / 2;

    for (final cat in categories) {
      final sweepAngle = (cat.totalMinorUnits / totalPaise) * 2 * math.pi;

      final paint = Paint()
        ..color = Color(cat.colorValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.04, // slight spacing gap between segments
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.categories != categories || oldDelegate.totalPaise != totalPaise;
  }
}

class CategoryPieChart extends StatelessWidget {
  final List<CategorySpend> categories;
  final String currencySymbol;
  final double size;

  const CategoryPieChart({
    super.key,
    required this.categories,
    required this.currencySymbol,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    final totalPaise = categories.fold<int>(0, (sum, item) => sum + item.totalMinorUnits);

    if (totalPaise == 0) {
      return SizedBox(
        height: size,
        child: const Center(child: Text('No expense data')),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _PieChartPainter(
          categories: categories,
          totalPaise: totalPaise,
        ),
      ),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<CategorySpend> categories;
  final int totalPaise;

  _PieChartPainter({
    required this.categories,
    required this.totalPaise,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;

    double startAngle = -math.pi / 2;

    for (final cat in categories) {
      final sweepAngle = (cat.totalMinorUnits / totalPaise) * 2 * math.pi;

      final paintSlice = Paint()
        ..color = Color(cat.colorValue)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paintSlice,
      );

      final paintBorder = Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paintBorder,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) {
    return oldDelegate.categories != categories || oldDelegate.totalPaise != totalPaise;
  }
}
