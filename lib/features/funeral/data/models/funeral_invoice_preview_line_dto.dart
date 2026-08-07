import 'funeral_enums.dart';

class FuneralInvoicePreviewLineDto {
  final String entityName;
  final InvoiceEntityType entityType;
  final int amountCents;
  final String description;
  final String? invoiceId;
  final String? invoiceNo;
  final String? invoiceStatus;

  FuneralInvoicePreviewLineDto({
    required this.entityName,
    required this.entityType,
    required this.amountCents,
    required this.description,
    this.invoiceId,
    this.invoiceNo,
    this.invoiceStatus,
  });

  Map<String, dynamic> toJson() {
    return {
      'entityName': entityName,
      'entityType': entityType.name,
      'amountCents': amountCents,
      'description': description,
      if (invoiceId != null) 'invoiceId': invoiceId,
      if (invoiceNo != null) 'invoiceNo': invoiceNo,
      if (invoiceStatus != null) 'invoiceStatus': invoiceStatus,
    };
  }

  factory FuneralInvoicePreviewLineDto.fromJson(Map<String, dynamic> json) {
    return FuneralInvoicePreviewLineDto(
      entityName: json['entityName']?.toString() ?? '',
      entityType: InvoiceEntityType.parse(json['entityType']?.toString()),
      amountCents: json['amountCents'] as int? ?? 0,
      description: json['description']?.toString() ?? '',
      invoiceId: json['invoiceId']?.toString(),
      invoiceNo: json['invoiceNo']?.toString(),
      invoiceStatus: json['invoiceStatus']?.toString(),
    );
  }
}
