import 'package:intl/intl.dart';

class Invoice {
  final String id;
  final String transactionNumber;
  final String customerName;
  final DateTime date;
  final double amount;
  final String status;

  Invoice({
    required this.id,
    required this.transactionNumber,
    required this.customerName,
    required this.date,
    required this.amount,
    required this.status,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Format: "Feb 20, 2025, 12:00:00 AM"
    DateTime parsedDate;
    try {
      final dateStr = json['creationDate'] ?? '';
      parsedDate = DateFormat('MMM d, yyyy, hh:mm:ss a').parse(dateStr);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return Invoice(
      id: json['id'] ?? '',
      transactionNumber: json['transactionNumber'] ?? '',
      customerName: json['customer'] ?? 'Unknown Customer',
      date: parsedDate,
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'Draft',
    );
  }
}
