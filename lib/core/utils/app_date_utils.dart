import 'package:intl/intl.dart';

/// Central date parsing and presentation for MAWA ERP.
///
/// Spring/Jackson can serialize Java LocalDate/LocalDateTime values either as
/// ISO strings or arrays such as [2026, 8, 14, 21, 30, 45]. This helper keeps
/// those transport representations out of the UI and gives the application one
/// consistent human-readable date format.
class AppDateUtils {
  AppDateUtils._();

  static final DateFormat _displayDate = DateFormat('dd MMM yyyy');
  static final DateFormat _displayDateTime = DateFormat('dd MMM yyyy HH:mm');
  static final DateFormat _apiDate = DateFormat('yyyy-MM-dd');

  static DateTime? parse(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    if (value is List && value.length >= 3) {
      int part(int index, [int fallback = 0]) {
        if (index >= value.length) return fallback;
        final raw = value[index];
        if (raw is num) return raw.toInt();
        return int.tryParse(raw.toString()) ?? fallback;
      }

      try {
        final fraction = part(6);
        final millisecond = fraction > 999 ? fraction ~/ 1000000 : fraction;
        return DateTime(
          part(0),
          part(1, 1),
          part(2, 1),
          part(3),
          part(4),
          part(5),
          millisecond,
        );
      } catch (_) {
        return null;
      }
    }

    if (value is Map) {
      int? number(String key) {
        final raw = value[key];
        if (raw is num) return raw.toInt();
        return int.tryParse(raw?.toString() ?? '');
      }

      final year = number('year');
      final month = number('month') ?? number('monthValue');
      final day = number('day') ?? number('dayOfMonth');
      if (year != null && month != null && day != null) {
        try {
          return DateTime(
            year,
            month,
            day,
            number('hour') ?? 0,
            number('minute') ?? 0,
            number('second') ?? 0,
            (number('nano') ?? 0) ~/ 1000000,
          );
        } catch (_) {
          return null;
        }
      }
    }

    final text = value.toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  static String normalizeDate(dynamic value, {String fallback = ''}) {
    final parsed = parse(value);
    return parsed == null ? fallback : _apiDate.format(parsed);
  }

  static String normalizeDateTime(dynamic value, {String fallback = ''}) {
    final parsed = parse(value);
    return parsed == null ? fallback : parsed.toIso8601String();
  }

  static String displayDate(dynamic value, {String fallback = 'N/A'}) {
    final parsed = parse(value);
    return parsed == null ? fallback : _displayDate.format(parsed);
  }

  static String displayDateTime(dynamic value, {String fallback = 'N/A'}) {
    final parsed = parse(value);
    return parsed == null ? fallback : _displayDateTime.format(parsed.toLocal());
  }

  static String apiDate(DateTime value) => _apiDate.format(value);
}
