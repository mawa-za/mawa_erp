import 'receipt_allocation_response.dart';

class ReceiptResponse {
  final String id;
  final String receiptNo;
  final String traceId;
  final String paymentBatchId;
  final String paymentBatchNo;
  final String sourceType;
  final String membershipId;
  final String receiptDate;
  final String paymentMethod;
  final int totalAmountCents;
  final String status;
  final String syncStatus;
  final bool printed;
  final int printCount;
  final List<ReceiptAllocationResponse> allocations;

  ReceiptResponse({
    required this.id,
    required this.receiptNo,
    required this.traceId,
    required this.paymentBatchId,
    required this.paymentBatchNo,
    required this.sourceType,
    required this.membershipId,
    required this.receiptDate,
    required this.paymentMethod,
    required this.totalAmountCents,
    required this.status,
    required this.syncStatus,
    required this.printed,
    required this.printCount,
    required this.allocations,
  });

  double get totalAmount => totalAmountCents / 100.0;

  factory ReceiptResponse.fromJson(Map<String, dynamic> json) {
    var list = json['allocations'] as List? ?? [];
    List<ReceiptAllocationResponse> allocationsList = list.map((i) => ReceiptAllocationResponse.fromJson(i)).toList();

    return ReceiptResponse(
      id: (json['id'] ?? '').toString(),
      receiptNo: (json['receiptNo'] ?? '').toString(),
      traceId: (json['traceId'] ?? '').toString(),
      paymentBatchId: (json['paymentBatchId'] ?? '').toString(),
      paymentBatchNo: (json['paymentBatchNo'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      receiptDate: (json['receiptDate'] ?? '').toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      totalAmountCents: json['totalAmountCents'] ?? 0,
      status: (json['status'] ?? '').toString(),
      syncStatus: (json['syncStatus'] ?? '').toString(),
      printed: json['printed'] ?? false,
      printCount: json['printCount'] ?? 0,
      allocations: allocationsList,
    );
  }
}
