import 'package:intl/intl.dart';

class PartnerIdentity {
  final String? partner;
  final String type; 
  final String number;
  final DateTime? validFrom;
  final DateTime? validTo;

  PartnerIdentity({
    this.partner,
    required this.type,
    required this.number,
    this.validFrom,
    this.validTo,
  });

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    
    // Handle array format [yyyy, mm, dd] or [yyyy, mm, dd, hh, mm, ss]
    if (value is List && value.length >= 3) {
      try {
        return DateTime(
          (value[0] as num).toInt(),
          (value[1] as num).toInt(),
          (value[2] as num).toInt(),
          value.length >= 4 ? (value[3] as num).toInt() : 0,
          value.length >= 5 ? (value[4] as num).toInt() : 0,
          value.length >= 6 ? (value[5] as num).toInt() : 0,
        );
      } catch (_) {
        return null;
      }
    }

    if (value is num) {
      final val = value.toInt();
      // Handle common timestamp formats (milliseconds or seconds)
      if (val > 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      } else if (val > 0) {
        return DateTime.fromMillisecondsSinceEpoch(val * 1000);
      }
      return null;
    }

    if (value is Map) {
      try {
        final year = value['year'] ?? value['yearValue'] ?? value['year_value'];
        final month = value['month'] ?? value['monthValue'] ?? value['month_value'] ?? 1;
        final day = value['day'] ?? value['dayOfMonth'] ?? value['day_of_month'] ?? 1;
        
        int? y = year is num ? year.toInt() : int.tryParse(year.toString());
        int? m = month is num ? month.toInt() : int.tryParse(month.toString());
        int? d = day is num ? day.toInt() : int.tryParse(day.toString());

        if (y != null && m != null && d != null && y > 1900) {
          return DateTime(
            y, m, d,
            ((value['hour'] ?? value['hourOfDay'] ?? value['hour_of_day'] ?? 0) as num).toInt(),
            ((value['minute'] ?? value['minute_of_hour'] ?? 0) as num).toInt(),
            ((value['second'] ?? value['second_of_minute'] ?? 0) as num).toInt(),
          );
        }
      } catch (_) {}
      return null;
    }

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      
      final iso = DateTime.tryParse(trimmed);
      if (iso != null) return iso;

      final n = int.tryParse(trimmed);
      if (n != null) {
        if (n > 10000000000) return DateTime.fromMillisecondsSinceEpoch(n);
        if (n > 0) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      }

      final humanFormats = [
        "MMM d, yyyy",
        "MMM d, yyyy, hh:mm:ss a",
        "MMM d, yyyy, h:mm:ss a",
        "d MMM yyyy",
        "dd MMM yyyy",
        "yyyy-MM-dd",
        "yyyy-MM-dd HH:mm:ss",
        "yyyy-MM-dd HH:mm",
        "dd-MM-yyyy",
        "dd-MM-yyyy HH:mm:ss",
        "yyyy/MM/dd",
        "dd/MM/yyyy",
        "MM/dd/yyyy",
        "yyyy.MM.dd",
      ];

      for (final format in humanFormats) {
        try {
          return DateFormat(format, 'en_US').parse(trimmed);
        } catch (_) {}
      }
    }
    return null;
  }

  factory PartnerIdentity.fromJson(Map<String, dynamic> json) {
    String typeValue = '';
    final typeJson = json['type'];
    if (typeJson is Map) {
      typeValue = (typeJson['description'] ?? typeJson['code'] ?? typeJson['name'] ?? '').toString();
    } else if (typeJson is String) {
      typeValue = typeJson;
    }

    return PartnerIdentity(
      partner: json['partner']?.toString(),
      type: typeValue,
      number: (json['number'] ?? json['identityNumber'] ?? '').toString(),
      validFrom: parseDate(json['validFrom'] ?? json['valid_from'] ?? json['startDate'] ?? json['effectiveDate'] ?? json['valid_from_date'] ?? json['effective_date']),
      validTo: parseDate(json['validTo'] ?? json['valid_to'] ?? json['endDate'] ?? json['expiryDate'] ?? json['expiry_date'] ?? json['expiredAt'] ?? json['validUntil'] ?? json['valid_until'] ?? json['valid_to_date'] ?? json['expiry_date_time'] ?? json['expirationDate'] ?? json['expiration_date']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (partner != null) 'partner': partner,
      'type': type,
      'number': number,
      if (validFrom != null) 'validFrom': validFrom?.toIso8601String(),
      if (validTo != null) 'validTo': validTo?.toIso8601String(),
    };
  }
}
