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
      amountCents: json['amountCents'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }
}
