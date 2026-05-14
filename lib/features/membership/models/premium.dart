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

  factory SalesRepresentative.fromDynamic(dynamic json) {
    if (json is Map) {
      return SalesRepresentative.fromJson(Map<String, dynamic>.from(json));
    }
    return SalesRepresentative(id: '', name: 'Unknown');
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
    // Resilience against nested lists instead of maps
    dynamic er = json['employeeResponsible'];
    dynamic tt = json['tenderType'];

    return Premium(
      id: (json['id'] ?? '').toString(),
      receiptNumber: (json['receiptNumber'] ?? '').toString(),
      creationDate: (json['creationDate'] ?? '').toString(),
      creationTime: (json['creationTime'] ?? '').toString(),
      employeeResponsible: SalesRepresentative.fromDynamic(er),
      membershipPeriod: (json['membershipPeriod'] ?? '').toString(),
      tenderType: FieldOption.fromDynamic(tt),
      amount: (json['amount'] ?? 0.0).toDouble(),
      externalReceiptNo: json['externalReceiptNo']?.toString(),
    );
  }
}
