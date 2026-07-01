class InvoiceSummaryDto {
  final String invoiceId;
  final String invoiceNumber;
  final int totalAmountCents;
  final int balanceCents;
  final String status;

  InvoiceSummaryDto({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.totalAmountCents,
    required this.balanceCents,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'totalAmountCents': totalAmountCents,
      'balanceCents': balanceCents,
      'status': status,
    };
  }

  factory InvoiceSummaryDto.fromJson(Map<String, dynamic> json) {
    return InvoiceSummaryDto(
      invoiceId: (json['invoiceId'] ?? json['id'] ?? '').toString(),
      invoiceNumber: (json['invoiceNumber'] ?? json['invoiceNo'] ?? '').toString(),
      totalAmountCents: json['totalAmountCents'] as int? ?? 0,
      balanceCents: json['balanceCents'] as int? ?? 0,
      status: json['status']?.toString() ?? '',
    );
  }
}
