import 'funeral_enums.dart';

class FuneralInvoicePreviewLineDto {
  final String entityName;
  final InvoiceEntityType entityType;
  final int amountCents;
  final String description;

  FuneralInvoicePreviewLineDto({
    required this.entityName,
    required this.entityType,
    required this.amountCents,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityName': entityName,
      'entityType': entityType.name,
      'amountCents': amountCents,
      'description': description,
    };
  }

  factory FuneralInvoicePreviewLineDto.fromJson(Map<String, dynamic> json) {
    return FuneralInvoicePreviewLineDto(
      entityName: json['entityName']?.toString() ?? '',
      entityType: InvoiceEntityType.parse(json['entityType']?.toString()),
      amountCents: _toInt(json['amountCents'] ?? json['amount_cents']),
      description: json['description']?.toString() ?? '',
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
