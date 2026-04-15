class Invoice {
  final String id;
  final String customerName;
  final DateTime date;
  final double amount;
  final String status;

  Invoice({
    required this.id,
    required this.customerName,
    required this.date,
    required this.amount,
    required this.status,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] ?? '',
      customerName: json['customerName'] ?? 'Unknown Customer',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      amount: (json['amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'Draft',
    );
  }
}
