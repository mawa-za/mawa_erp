class FuneralGeneratedInvoiceDto {
  final String invoiceId;
  final String invoiceNo;
  final String status;
  final int totalCents;
  final int paidCents;
  final int balanceCents;

  FuneralGeneratedInvoiceDto({
    required this.invoiceId,
    required this.invoiceNo,
    required this.status,
    required this.totalCents,
    required this.paidCents,
    required this.balanceCents,
  });

  factory FuneralGeneratedInvoiceDto.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) => value is num ? value.toInt() : int.tryParse((value ?? '0').toString()) ?? 0;
    return FuneralGeneratedInvoiceDto(
      invoiceId: (json['invoiceId'] ?? json['id'] ?? '').toString(),
      invoiceNo: (json['invoiceNo'] ?? json['invoice_no'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      totalCents: parseInt(json['totalCents'] ?? json['total_cents']),
      paidCents: parseInt(json['paidCents'] ?? json['paid_cents']),
      balanceCents: parseInt(json['balanceCents'] ?? json['balance_cents']),
    );
  }

  Map<String, dynamic> toJson() => {
        'invoiceId': invoiceId,
        'invoiceNo': invoiceNo,
        'status': status,
        'totalCents': totalCents,
        'paidCents': paidCents,
        'balanceCents': balanceCents,
      };
}

class GenerateFuneralInvoicesResponseDto {
  final String funeralServiceId;
  final List<String> invoiceIds;
  final List<FuneralGeneratedInvoiceDto> invoices;

  GenerateFuneralInvoicesResponseDto({
    required this.funeralServiceId,
    required this.invoiceIds,
    required this.invoices,
  });

  Map<String, dynamic> toJson() {
    return {
      'funeralServiceId': funeralServiceId,
      'invoiceIds': invoiceIds,
      'invoices': invoices.map((e) => e.toJson()).toList(),
    };
  }

  factory GenerateFuneralInvoicesResponseDto.fromJson(Map<String, dynamic> json) {
    final invoiceList = (json['invoices'] as List?)
            ?.whereType<Map>()
            .map((e) => FuneralGeneratedInvoiceDto.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];
    final ids = (json['invoiceIds'] as List?)?.map((e) => e.toString()).toList() ??
        invoiceList.map((e) => e.invoiceId).where((id) => id.isNotEmpty).toList();
    return GenerateFuneralInvoicesResponseDto(
      funeralServiceId: (json['funeralServiceId'] ?? json['id'] ?? '').toString(),
      invoiceIds: ids,
      invoices: invoiceList,
    );
  }
}
