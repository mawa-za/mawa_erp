class PayrollBatchSummary {
  final String id;
  final String reference;
  final String dateCreated;
  final String status;
  final double totalAmount;
  final int itemCount;

  PayrollBatchSummary({
    required this.id,
    required this.reference,
    required this.dateCreated,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
  });

  factory PayrollBatchSummary.fromJson(Map<String, dynamic> json) {
    return PayrollBatchSummary(
      id: json['id'] ?? '',
      reference: json['reference'] ?? '',
      dateCreated: json['dateCreated'] ?? '',
      status: json['status'] ?? 'NEW',
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      itemCount: json['itemCount'] ?? 0,
    );
  }
}

class PayrollBatchDetail {
  final String id;
  final String reference;
  final String dateCreated;
  final String status;
  final List<PayrollItem> items;

  PayrollBatchDetail({
    required this.id,
    required this.reference,
    required this.dateCreated,
    required this.status,
    required this.items,
  });

  factory PayrollBatchDetail.fromJson(Map<String, dynamic> json) {
    return PayrollBatchDetail(
      id: json['id'] ?? '',
      reference: json['reference'] ?? '',
      dateCreated: json['dateCreated'] ?? '',
      status: json['status'] ?? 'NEW',
      items: (json['items'] as List? ?? [])
          .map((item) => PayrollItem.fromJson(item))
          .toList(),
    );
  }
}

class PayrollItem {
  final String id;
  final String recipientName;
  final String recipientId;
  final double amount;
  final String reference;
  final Map<String, dynamic>? bankAccount;

  PayrollItem({
    required this.id,
    required this.recipientName,
    required this.recipientId,
    required this.amount,
    required this.reference,
    this.bankAccount,
  });

  factory PayrollItem.fromJson(Map<String, dynamic> json) {
    return PayrollItem(
      id: json['id'] ?? '',
      recipientName: json['recipientName'] ?? '',
      recipientId: json['recipientId'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
      reference: json['reference'] ?? '',
      bankAccount: json['bankAccount'],
    );
  }
}
