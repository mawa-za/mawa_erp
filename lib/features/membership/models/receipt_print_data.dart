import 'package:intl/intl.dart';

class ReceiptPrintData {
  final String receiptNo;
  final String traceId;
  final String memberName;
  final String membershipNo;
  final String identityNumber;
  final String planName;
  final String premiumPeriodYYYYMM;
  final int amountCents;
  final String paymentMethod;
  final String receiptDate;
  final String employeeResponsible;

  String get formattedReceiptDate {
    final parsed = DateTime.tryParse(receiptDate);
    return parsed == null
        ? receiptDate
        : DateFormat('yyyy-MM-dd HH:mm').format(parsed.toLocal());
  }

  const ReceiptPrintData({
    required this.receiptNo,
    required this.traceId,
    required this.memberName,
    required this.membershipNo,
    required this.identityNumber,
    required this.planName,
    required this.premiumPeriodYYYYMM,
    required this.amountCents,
    required this.paymentMethod,
    required this.receiptDate,
    required this.employeeResponsible,
  });

  factory ReceiptPrintData.fromJson(Map<String, dynamic> json) =>
      ReceiptPrintData(
        receiptNo: (json['receiptNo'] ?? '').toString(),
        traceId: (json['traceId'] ?? '').toString(),
        memberName: (json['memberName'] ?? '').toString(),
        membershipNo: (json['membershipNo'] ?? '').toString(),
        identityNumber: (json['identityNumber'] ?? '').toString(),
        planName: (json['planName'] ?? '').toString(),
        premiumPeriodYYYYMM:
            (json['premiumPeriodYYYYMM'] ?? '').toString(),
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        paymentMethod: (json['paymentMethod'] ?? '').toString(),
        receiptDate: (json['receiptDate'] ?? '').toString(),
        employeeResponsible:
            (json['employeeResponsible'] ?? '').toString(),
      );
}
