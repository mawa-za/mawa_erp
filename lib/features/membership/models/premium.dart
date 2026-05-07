import '../../../core/models/field_option.dart';

class SalesRepresentative {
  final String id;
  final String name;

  SalesRepresentative({required this.id, required this.name});

  factory SalesRepresentative.fromJson(Map<String, dynamic> json) {
    return SalesRepresentative(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? json['displayName'] ?? '').toString(),
    );
  }
}

class Premium {
  final String id;
  final String receiptNumber;
  final String creationDate;
  final String creationTime;
  final SalesRepresentative employeeResponsible;
  final String membershipPeriod;
  final FieldOption tenderType;
  final double amount;
  final String? externalReceiptNo;

  Premium({
    required this.id,
    required this.receiptNumber,
    required this.creationDate,
    required this.creationTime,
    required this.employeeResponsible,
    required this.membershipPeriod,
    required this.tenderType,
    required this.amount,
    this.externalReceiptNo,
  });

  factory Premium.fromJson(Map<String, dynamic> json) {
    return Premium(
      id: json['id'] ?? '',
      receiptNumber: json['receiptNumber'] ?? '',
      creationDate: json['creationDate'] ?? '',
      creationTime: json['creationTime'] ?? '',
      employeeResponsible: SalesRepresentative.fromJson(json['employeeResponsible'] ?? {}),
      membershipPeriod: json['membershipPeriod'] ?? '',
      tenderType: FieldOption.fromJson(json['tenderType'] ?? {}),
      amount: (json['amount'] ?? 0.0).toDouble(),
      externalReceiptNo: json['externalReceiptNo'],
    );
  }
}
