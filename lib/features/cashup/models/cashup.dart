class Cashup {
  final String id;
  final int cashupNo;
  final String deviceId;
  final String userId;
  final String cashupDate;
  final int totalCents;
  final int receiptCount;
  final String status;
  final List<CashupPayment> payments;

  Cashup({
    required this.id,
    required this.cashupNo,
    required this.deviceId,
    required this.userId,
    required this.cashupDate,
    required this.totalCents,
    required this.receiptCount,
    required this.status,
    required this.payments,
  });

  double get totalAmount => totalCents / 100;

  factory Cashup.fromJson(Map<String, dynamic> json) {
    String formattedDate = '';
    final rawDate = json['cashupDate'];
    
    if (rawDate is String) {
      formattedDate = rawDate;
    } else if (rawDate is List && rawDate.length >= 3) {
      final year = rawDate[0];
      final month = rawDate[1].toString().padLeft(2, '0');
      final day = rawDate[2].toString().padLeft(2, '0');
      formattedDate = '$year-$month-$day';
    }

    return Cashup(
      id: json['id'] ?? '',
      cashupNo: json['cashupNo'] ?? 0,
      deviceId: json['deviceId'] ?? '',
      userId: json['userId'] ?? '',
      cashupDate: formattedDate,
      totalCents: json['totalCents'] ?? 0,
      receiptCount: json['receiptCount'] ?? 0,
      status: json['status'] ?? '',
      payments: (json['payments'] as List? ?? [])
          .map((p) => CashupPayment.fromJson(p))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cashupNo': cashupNo,
      'deviceId': deviceId,
      'userId': userId,
      'cashupDate': cashupDate,
      'totalCents': totalCents,
      'receiptCount': receiptCount,
      'status': status,
      'payments': payments.map((p) => p.toJson()).toList(),
    };
  }
}

class CashupPayment {
  final String paymentMethod;
  final int amountCents;
  final int paymentCount;

  CashupPayment({
    required this.paymentMethod,
    required this.amountCents,
    required this.paymentCount,
  });

  double get amount => amountCents / 100;

  factory CashupPayment.fromJson(Map<String, dynamic> json) {
    return CashupPayment(
      paymentMethod: json['paymentMethod'] ?? '',
      amountCents: json['amountCents'] ?? 0,
      paymentCount: json['paymentCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'paymentMethod': paymentMethod,
      'amountCents': amountCents,
      'paymentCount': paymentCount,
    };
  }
}
