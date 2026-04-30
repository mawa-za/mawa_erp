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
