class GenerateFuneralInvoicesResponseDto {
  final String funeralServiceId;
  final List<String> invoiceIds;

  GenerateFuneralInvoicesResponseDto({
    required this.funeralServiceId,
    required this.invoiceIds,
  });

  Map<String, dynamic> toJson() {
    return {
      'funeralServiceId': funeralServiceId,
      'invoiceIds': invoiceIds,
    };
  }

  factory GenerateFuneralInvoicesResponseDto.fromJson(Map<String, dynamic> json) {
    return GenerateFuneralInvoicesResponseDto(
      funeralServiceId: (json['funeralServiceId'] ?? json['id'] ?? '').toString(),
      invoiceIds: (json['invoiceIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
