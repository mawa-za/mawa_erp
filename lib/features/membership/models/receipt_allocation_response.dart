class ReceiptAllocationResponse {
  final String id;
  final String allocationType;
  final String referenceId;
  final String referenceNo;
  final String periodYYYYMM;
  final String membershipId;
  final int amountCents;
  final String status;

  ReceiptAllocationResponse({
    required this.id,
    required this.allocationType,
    required this.referenceId,
    required this.referenceNo,
    required this.periodYYYYMM,
    required this.membershipId,
    required this.amountCents,
    required this.status,
  });

  double get amount => amountCents / 100.0;

  factory ReceiptAllocationResponse.fromJson(Map<String, dynamic> json) {
    return ReceiptAllocationResponse(
      id: (json['id'] ?? '').toString(),
      allocationType: (json['allocationType'] ?? '').toString(),
      referenceId: (json['referenceId'] ?? '').toString(),
      referenceNo: (json['referenceNo'] ?? '').toString(),
      periodYYYYMM: (json['periodYYYYMM'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      amountCents: json['amountCents'] ?? 0,
      status: (json['status'] ?? '').toString(),
    );
  }
}
