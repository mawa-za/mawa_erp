import 'package:intl/intl.dart';

class Invoice {
  final String id;
  final String transactionNumber;
  final String partnerId;
  final DateTime date;
  final DateTime? dueDate;
  final double amount;
  final String status;
  final String customerName;

  Invoice({
    required this.id,
    required this.transactionNumber,
    required this.partnerId,
    required this.date,
    this.dueDate,
    required this.amount,
    required this.status,
    this.customerName = 'Unknown',
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      final dateStr = json['invoiceDate'] ?? json['creationDate'] ?? '';
      parsedDate = DateTime.tryParse(dateStr) ?? 
                  DateFormat('MMM d, yyyy, hh:mm:ss a').parse(dateStr);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedDueDate;
    try {
      if (json['dueDate'] != null) {
        final dueDateStr = json['dueDate'];
        parsedDueDate = DateTime.tryParse(dueDateStr) ?? 
                      DateFormat('MMM d, yyyy, hh:mm:ss a').parse(dueDateStr);
      }
    } catch (e) {
      parsedDueDate = null;
    }

    return Invoice(
      id: json['id'] ?? '',
      transactionNumber: json['invoiceNo'] ?? json['transactionNumber'] ?? '',
      partnerId: json['partnerId'] ?? '',
      date: parsedDate,
      dueDate: parsedDueDate,
      amount: json['totalCents'] != null 
          ? (json['totalCents'] / 100.0) 
          : (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'DRAFT',
      customerName: json['partnerName'] ?? json['customer'] ?? 'Partner: ${json['partnerId'] ?? 'Unknown'}',
    );
  }
}
