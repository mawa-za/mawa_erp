import '../../../core/utils/app_date_utils.dart';
import 'receipt_response.dart';

class PaymentBatchResponse {
  final String id;
  final String paymentBatchNo;
  final String sourceType;
  final String membershipId;
  final String? receivedFromPartnerId;
  final String paymentMethod;
  final int totalAmountCents;
  final String paymentDate;
  final String status;
  final String syncStatus;
  final String? paidUpToPeriod;
  final List<ReceiptResponse> receipts;

  PaymentBatchResponse({
    required this.id,
    required this.paymentBatchNo,
    required this.sourceType,
    required this.membershipId,
    this.receivedFromPartnerId,
    required this.paymentMethod,
    required this.totalAmountCents,
    required this.paymentDate,
    required this.status,
    required this.syncStatus,
    this.paidUpToPeriod,
    required this.receipts,
  });

  double get totalAmount => totalAmountCents / 100.0;

  factory PaymentBatchResponse.fromJson(Map<String, dynamic> json) {
    var list = json['receipts'] as List? ?? [];
    List<ReceiptResponse> receiptsList = list.map((i) => ReceiptResponse.fromJson(i)).toList();

    return PaymentBatchResponse(
      id: (json['id'] ?? '').toString(),
      paymentBatchNo: (json['paymentBatchNo'] ?? '').toString(),
      sourceType: (json['sourceType'] ?? '').toString(),
      membershipId: (json['membershipId'] ?? '').toString(),
      receivedFromPartnerId: json['receivedFromPartnerId']?.toString(),
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      totalAmountCents: (json['totalAmountCents'] as num?)?.toInt() ?? int.tryParse('${json['totalAmountCents'] ?? 0}') ?? 0,
      paymentDate: AppDateUtils.normalizeDateTime(json['paymentDate']),
      status: (json['status'] ?? '').toString(),
      syncStatus: (json['syncStatus'] ?? '').toString(),
      paidUpToPeriod: json['paidUpToPeriod']?.toString(),
      receipts: receiptsList,
    );
  }
}
