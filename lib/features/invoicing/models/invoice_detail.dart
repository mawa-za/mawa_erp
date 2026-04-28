import 'package:intl/intl.dart';

class InvoiceDetail {
  final String id;
  final String number;
  final String customerName;
  final String customerNumber;
  final DateTime invoiceDate;
  final String status;
  final List<InvoiceItem> items;
  final List<InvoiceAmount> amounts;

  InvoiceDetail({
    required this.id,
    required this.number,
    required this.customerName,
    required this.customerNumber,
    required this.invoiceDate,
    required this.status,
    required this.items,
    required this.amounts,
  });

  double get totalAmount {
    return amounts.firstWhere(
      (a) => a.code == 'TOTAL-INC-VAT',
      orElse: () => InvoiceAmount(code: 'TOTAL', description: 'Total', amount: 0),
    ).amount;
  }

  double get vatAmount {
    return amounts.firstWhere(
      (a) => a.code == 'VAT-AMOUNT',
      orElse: () => InvoiceAmount(code: 'VAT', description: 'VAT', amount: 0),
    ).amount;
  }

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] ?? {};
    final name1 = customer['name1'] ?? '';
    final name2 = customer['name2'] ?? '';
    final name3 = customer['name3'] ?? '';
    final fullName = [name1, name2, name3].where((s) => s.isNotEmpty).join(' ');

    DateTime parsedDate;
    try {
      final dateStr = json['invoiceDate'] ?? '';
      parsedDate = DateFormat('MMM d, yyyy, h:mm:ss a').parse(dateStr);
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return InvoiceDetail(
      id: json['id'] ?? '',
      number: json['number'] ?? '',
      customerName: fullName.isEmpty ? 'Unknown' : fullName,
      customerNumber: customer['number'] ?? '',
      invoiceDate: parsedDate,
      status: json['status']?['description'] ?? json['status']?['code'] ?? 'Unknown',
      items: (json['items'] as List? ?? [])
          .map((i) => InvoiceItem.fromJson(i))
          .toList(),
      amounts: (json['amounts'] as List? ?? [])
          .map((a) => InvoiceAmount.fromJson(a))
          .toList(),
    );
  }
}

class InvoiceItem {
  final String productName;
  final String productCode;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  InvoiceItem({
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return InvoiceItem(
      productName: product['description'] ?? 'Unknown Product',
      productCode: product['code'] ?? '',
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      lineTotal: (json['lineTotal'] ?? 0.0).toDouble(),
    );
  }
}

class InvoiceAmount {
  final String code;
  final String description;
  final double amount;

  InvoiceAmount({
    required this.code,
    required this.description,
    required this.amount,
  });

  factory InvoiceAmount.fromJson(Map<String, dynamic> json) {
    final type = json['type'] ?? {};
    return InvoiceAmount(
      code: type['code'] ?? '',
      description: type['description'] ?? '',
      amount: (json['amount'] ?? 0.0).toDouble(),
    );
  }
}
