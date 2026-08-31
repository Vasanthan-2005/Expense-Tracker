import 'package:intl/intl.dart';

class DateFormatter {
  static String formatRelativeDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatDateFull(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  static String formatDateIso(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  static String formatTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2000, 1, 1, hour, minute);
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return timeString;
  }

  static String formatTimeFromDateTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }

  static String formatMonthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }
}
