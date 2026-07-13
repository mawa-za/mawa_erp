class FuneralPaymentSummaryDto {
  final String funeralServiceInvoiceId;
  final String funeralServiceId;
  final String serviceRequestNo;
  final String deceasedName;
  final String invoiceId;
  final String invoiceNo;
  final String entityType;
  final String partnerId;
  final int allocatedAmountCents;
  final int invoiceTotalCents;
  final int paidCents;
  final int balanceCents;
  final String status;
  final DateTime? invoiceDate;

  const FuneralPaymentSummaryDto({
    required this.funeralServiceInvoiceId,
    required this.funeralServiceId,
    required this.serviceRequestNo,
    required this.deceasedName,
    required this.invoiceId,
    required this.invoiceNo,
    required this.entityType,
    required this.partnerId,
    required this.allocatedAmountCents,
    required this.invoiceTotalCents,
    required this.paidCents,
    required this.balanceCents,
    required this.status,
    required this.invoiceDate,
  });

  factory FuneralPaymentSummaryDto.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    DateTime? date(dynamic value) {
      if (value == null) return null;
      if (value is List && value.length >= 3) {
        return DateTime(
          (value[0] as num).toInt(),
          (value[1] as num).toInt(),
          (value[2] as num).toInt(),
        );
      }
      return DateTime.tryParse(value.toString());
    }

    return FuneralPaymentSummaryDto(
      funeralServiceInvoiceId:
          (json['funeralServiceInvoiceId'] ?? '').toString(),
      funeralServiceId: (json['funeralServiceId'] ?? '').toString(),
      serviceRequestNo: (json['serviceRequestNo'] ?? '').toString(),
      deceasedName: (json['deceasedName'] ?? '').toString(),
      invoiceId: (json['invoiceId'] ?? '').toString(),
      invoiceNo: (json['invoiceNo'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      partnerId: (json['partnerId'] ?? '').toString(),
      allocatedAmountCents: cents(json['allocatedAmountCents']),
      invoiceTotalCents: cents(json['invoiceTotalCents']),
      paidCents: cents(json['paidCents']),
      balanceCents: cents(json['balanceCents']),
      status: (json['status'] ?? 'UNKNOWN').toString(),
      invoiceDate: date(json['invoiceDate']),
    );
  }
}
