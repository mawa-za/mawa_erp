import 'package:intl/intl.dart';

class Formatters {
  static String formatCentsAsRand(int? cents) {
    if (cents == null) return 'R 0.00';
    final formatter = NumberFormat.currency(symbol: 'R ', locale: 'en_ZA');
    return formatter.format(cents / 100);
  }

  static String formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd').format(date);
  }

  static String formatDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  static String formatFriendlyDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(date);
  }
}
