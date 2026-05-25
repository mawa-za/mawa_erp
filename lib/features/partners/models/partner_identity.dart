import 'package:intl/intl.dart';

class PartnerIdentity {
  final String? partner;
  final String type; // Description or Code of the identity type
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

  factory PartnerIdentity.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        if (value.isEmpty) return null;
        try {
          return DateTime.parse(value);
        } catch (_) {
          try {
            // Handle "Sep 9, 2024" format
            return DateFormat("MMM d, yyyy").parse(value);
          } catch (_) {
            return null;
          }
        }
      }
      // Handle array format [yyyy, mm, dd] or [yyyy, mm, dd, hh, mm, ss]
      if (value is List && value.length >= 3) {
        try {
          return DateTime(
            value[0] as int,
            value[1] as int,
            value[2] as int,
            value.length >= 4 ? value[3] as int : 0,
            value.length >= 5 ? value[4] as int : 0,
            value.length >= 6 ? value[5] as int : 0,
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    String typeValue = '';
    final typeJson = json['type'];
    if (typeJson is Map) {
      typeValue = typeJson['description'] ?? typeJson['code'] ?? '';
    } else if (typeJson is String) {
      typeValue = typeJson;
    }

    return PartnerIdentity(
      partner: json['partner'],
      type: typeValue,
      number: json['number'] ?? '',
      validFrom: parseDate(json['validFrom']),
      validTo: parseDate(json['validTo']),
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
