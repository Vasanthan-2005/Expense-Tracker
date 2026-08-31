import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String formatPaise(int paise, {String symbol = '₹'}) {
    final double amount = paise / 100.0;
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  static String formatDouble(double amount, {String symbol = '₹'}) {
    final formatter = NumberFormat.currency(
      symbol: '$symbol ',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Compact format for charts and small metric cards (e.g. 1.2k, 5M)
  static String formatCompact(int paise, {String symbol = '₹'}) {
    final double amount = paise / 100.0;
    if (amount >= 1000000) {
      return '$symbol${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 10000) {
      return '$symbol${(amount / 1000).toStringAsFixed(1)}k';
    } else {
      return '$symbol${amount.toStringAsFixed(0)}';
    }
  }
}
