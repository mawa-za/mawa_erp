import 'package:intl/intl.dart';

class Invoice {
  final String id;
  final String transactionNumber;
  final String reference;
  final String customerName;
  final DateTime date;
  final DateTime? dueDate;
  final double amount;
  final String status;

  Invoice({
    required this.id,
    required this.transactionNumber,
    required this.reference,
    required this.customerName,
    required this.date,
    this.dueDate,
    required this.amount,
    required this.status,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Robust date parsing
    DateTime parsedDate;
    try {
      final dateStr = json['creationDate'] ?? '';
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
      transactionNumber: json['transactionNumber'] ?? '',
      reference: json['reference'] ?? '',
      customerName: json['customer'] ?? 'Unknown Customer',
      date: parsedDate,
      dueDate: parsedDueDate,
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'Draft',
    );
  }
}
