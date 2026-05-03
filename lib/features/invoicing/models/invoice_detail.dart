import 'package:intl/intl.dart';

class InvoiceDetail {
  final String id;
  final String number;
  final String reference;
  final String customerName;
  final String customerNumber;
  final String? customerId;
  final DateTime invoiceDate;
  final DateTime? dueDate;
  final String status;
  final String currency;
  final List<InvoiceItem> items;
  final List<InvoicePayment> payments;
  final int subtotalCents;
  final int taxCents;
  final int discountCents;
  final int totalCents;
  final int paidCents;
  final int balanceCents;

  InvoiceDetail({
    required this.id,
    required this.number,
    required this.reference,
    required this.customerName,
    required this.customerNumber,
    this.customerId,
    required this.invoiceDate,
    this.dueDate,
    required this.status,
    required this.items,
    this.payments = const [],
    this.currency = 'ZAR',
    this.subtotalCents = 0,
    this.taxCents = 0,
    this.discountCents = 0,
    this.totalCents = 0,
    this.paidCents = 0,
    this.balanceCents = 0,
  });

  double get totalAmount => totalCents / 100.0;
  double get vatAmount => taxCents / 100.0;
  double get subtotalAmount => subtotalCents / 100.0;
  double get discountAmount => discountCents / 100.0;
  double get paidAmount => paidCents / 100.0;
  double get balanceAmount => balanceCents / 100.0;

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] ?? {};
    final partner = json['partner'] ?? {};

    // Support both old and new customer field structures
    final name1 = customer['name1'] ?? partner['name1'] ?? '';
    final name2 = customer['name2'] ?? partner['name2'] ?? '';
    final name3 = customer['name3'] ?? partner['name3'] ?? '';
    final fullName = [name1, name2, name3].where((s) => s.isNotEmpty).join(' ');

    DateTime parsedDate;
    try {
      final dateStr = json['invoiceDate'] ?? '';
      try {
        parsedDate = DateTime.parse(dateStr);
      } catch (_) {
        parsedDate = DateFormat('MMM d, yyyy, h:mm:ss a').parse(dateStr);
      }
    } catch (e) {
      parsedDate = DateTime.now();
    }

    DateTime? parsedDueDate;
    try {
      if (json['dueDate'] != null) {
        try {
          parsedDueDate = DateTime.parse(json['dueDate']);
        } catch (_) {
          parsedDueDate = DateFormat('MMM d, yyyy, h:mm:ss a').parse(json['dueDate']);
        }
      }
    } catch (e) {
      parsedDueDate = null;
    }

    return InvoiceDetail(
      id: json['id'] ?? '',
      number: json['invoiceNo'] ?? json['number'] ?? '',
      reference: json['externalRef'] ?? json['reference'] ?? '',
      customerName: fullName.isEmpty ? 'Unknown' : fullName,
      customerNumber: customer['number'] ?? partner['partnerNo'] ?? '',
      customerId: json['partnerId'] ?? customer['id'],
      invoiceDate: parsedDate,
      dueDate: parsedDueDate,
      status: json['status'] ?? 'Unknown',
      currency: json['currency'] ?? 'ZAR',
      items: (json['lines'] as List? ?? json['items'] as List? ?? [])
          .map((i) => InvoiceItem.fromJson(i))
          .toList(),
      payments: (json['payments'] as List? ?? [])
          .map((p) => InvoicePayment.fromJson(p))
          .toList(),
      subtotalCents: json['subtotalCents'] ?? 0,
      taxCents: json['taxCents'] ?? 0,
      discountCents: json['discountCents'] ?? 0,
      totalCents: json['totalCents'] ?? 0,
      paidCents: json['paidCents'] ?? 0,
      balanceCents: json['balanceCents'] ?? 0,
    );
  }
}

class InvoiceItem {
  final String id;
  final String? productId;
  final String productName;
  final String productCode;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double discountPercentage;
  final int unitPriceCents;
  final int discountCents;
  final int taxCents;
  final int subtotalCents;
  final int totalCents;

  InvoiceItem({
    required this.id,
    this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.discountPercentage = 0,
    this.unitPriceCents = 0,
    this.discountCents = 0,
    this.taxCents = 0,
    this.subtotalCents = 0,
    this.totalCents = 0,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? {};
    return InvoiceItem(
      id: json['id'] ?? '',
      productId: json['productId'] ?? product['id'],
      productName: json['description'] ?? product['description'] ?? 'Unknown Product',
      productCode: product['code'] ?? '',
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unitPrice: json['unitPriceCents'] != null 
          ? json['unitPriceCents'] / 100.0 
          : (json['unitPrice'] ?? 0.0).toDouble(),
      lineTotal: json['totalCents'] != null 
          ? json['totalCents'] / 100.0 
          : (json['lineTotal'] ?? 0.0).toDouble(),
      discountPercentage: (json['discountPercentage'] ?? 0.0).toDouble(),
      unitPriceCents: json['unitPriceCents'] ?? 0,
      discountCents: json['discountCents'] ?? 0,
      taxCents: json['taxCents'] ?? 0,
      subtotalCents: json['subtotalCents'] ?? 0,
      totalCents: json['totalCents'] ?? 0,
    );
  }
}

class InvoicePayment {
  final String id;
  final DateTime paymentDate;
  final int amountCents;
  final String paymentMethod;
  final String referenceNo;

  InvoicePayment({
    required this.id,
    required this.paymentDate,
    required this.amountCents,
    required this.paymentMethod,
    required this.referenceNo,
  });

  double get amount => amountCents / 100.0;

  factory InvoicePayment.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['paymentDate'] ?? '');
    } catch (e) {
      parsedDate = DateTime.now();
    }

    return InvoicePayment(
      id: json['id'] ?? '',
      paymentDate: parsedDate,
      amountCents: json['amountCents'] ?? 0,
      paymentMethod: json['paymentMethod'] ?? '',
      referenceNo: json['referenceNo'] ?? '',
    );
  }
}
