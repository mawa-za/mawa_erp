class GenerateFuneralInvoiceResponseDto {
  final String funeralServiceId;
  final List<String> invoiceIds;

  GenerateFuneralInvoiceResponseDto({
    required this.funeralServiceId,
    required this.invoiceIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'funeralServiceId': funeralServiceId,
      'invoiceIds': invoiceIds,
    };
  }

  factory GenerateFuneralInvoiceResponseDto.fromJson(Map<String, dynamic> json) {
    return GenerateFuneralInvoiceResponseDto(
      funeralServiceId: json['funeralServiceId']?.toString() ?? '',
      invoiceIds: (json['invoiceIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
