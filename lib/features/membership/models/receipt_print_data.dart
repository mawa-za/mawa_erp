import 'package:intl/intl.dart';

class ReceiptPrintData {
  final String receiptNo;
  final String traceId;
  final String sourceType;
  final String memberName;
  final String membershipNo;
  final String identityNumber;
  final String planName;
  final String premiumPeriodYYYYMM;
  final String? serverPeriodDescription;
  final String invoiceId;
  final String invoiceNo;
  final String invoiceReference;
  final String customerName;
  final String customerNumber;
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

  String get periodDescription {
    final supplied = serverPeriodDescription?.trim() ?? '';
    if (supplied.isNotEmpty) return supplied;

    final codes = premiumPeriodYYYYMM
        .split(RegExp(r'[,;|]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (codes.isEmpty) return '-';

    return codes.map(_formatPeriodCode).join(', ');
  }

  bool get isInvoice => sourceType.toUpperCase() == 'INVOICE';

  const ReceiptPrintData({
    required this.receiptNo,
    required this.traceId,
    required this.sourceType,
    required this.memberName,
    required this.membershipNo,
    required this.identityNumber,
    required this.planName,
    required this.premiumPeriodYYYYMM,
    this.serverPeriodDescription,
    required this.invoiceId,
    required this.invoiceNo,
    required this.invoiceReference,
    required this.customerName,
    required this.customerNumber,
    required this.amountCents,
    required this.paymentMethod,
    required this.receiptDate,
    required this.employeeResponsible,
  });

  factory ReceiptPrintData.fromJson(Map<String, dynamic> json) =>
      ReceiptPrintData(
        receiptNo: (json['receiptNo'] ?? '').toString(),
        traceId: (json['traceId'] ?? '').toString(),
        sourceType: (json['sourceType'] ?? '').toString(),
        memberName: (json['memberName'] ?? '').toString(),
        membershipNo: (json['membershipNo'] ?? '').toString(),
        identityNumber: (json['identityNumber'] ?? '').toString(),
        planName: (json['planName'] ?? '').toString(),
        premiumPeriodYYYYMM:
            (json['premiumPeriodYYYYMM'] ?? '').toString(),
        serverPeriodDescription: json['periodDescription']?.toString(),
        invoiceId: (json['invoiceId'] ?? '').toString(),
        invoiceNo: (json['invoiceNo'] ?? '').toString(),
        invoiceReference: (json['invoiceReference'] ?? '').toString(),
        customerName: (json['customerName'] ?? '').toString(),
        customerNumber: (json['customerNumber'] ?? '').toString(),
        amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
        paymentMethod: (json['paymentMethod'] ?? '').toString(),
        receiptDate: (json['receiptDate'] ?? '').toString(),
        employeeResponsible:
            (json['employeeResponsible'] ?? '').toString(),
      );

  static String _formatPeriodCode(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) return code;
    final year = int.tryParse(code.substring(0, 4));
    final month = int.tryParse(code.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) {
      return code;
    }
    return '${DateFormat.MMMM('en').format(DateTime(year, month))} $year ($code)';
  }
}
