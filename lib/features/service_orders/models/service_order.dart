class ServiceOrderLine {
  final String? id;
  final String? productId;
  final String itemType;
  final String description;
  final double quantity;
  final int unitPriceCents;
  final int discountCents;
  final int taxCents;
  final int subtotalCents;
  final int totalCents;
  final String? employeePartnerId;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final String completionStatus;

  const ServiceOrderLine({
    this.id,
    this.productId,
    this.itemType = 'SERVICE',
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    this.discountCents = 0,
    this.taxCents = 0,
    this.subtotalCents = 0,
    this.totalCents = 0,
    this.employeePartnerId,
    this.scheduledStartAt,
    this.scheduledEndAt,
    this.completionStatus = 'NOT_STARTED',
  });

  ServiceOrderLine copyWith({
    String? id,
    String? productId,
    String? itemType,
    String? description,
    double? quantity,
    int? unitPriceCents,
    int? discountCents,
    int? taxCents,
    int? subtotalCents,
    int? totalCents,
    String? employeePartnerId,
    DateTime? scheduledStartAt,
    DateTime? scheduledEndAt,
    String? completionStatus,
  }) {
    return ServiceOrderLine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      itemType: itemType ?? this.itemType,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      discountCents: discountCents ?? this.discountCents,
      taxCents: taxCents ?? this.taxCents,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      totalCents: totalCents ?? this.totalCents,
      employeePartnerId: employeePartnerId ?? this.employeePartnerId,
      scheduledStartAt: scheduledStartAt ?? this.scheduledStartAt,
      scheduledEndAt: scheduledEndAt ?? this.scheduledEndAt,
      completionStatus: completionStatus ?? this.completionStatus,
    );
  }

  factory ServiceOrderLine.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) =>
        value is num ? value.round() : int.tryParse('${value ?? 0}') ?? 0;
    double quantity(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('${value ?? 1}') ?? 1;
    DateTime? date(dynamic value) {
      if (value == null || value.toString().isEmpty) return null;
      return DateTime.tryParse(value.toString());
    }

    return ServiceOrderLine(
      id: json['id']?.toString(),
      productId: json['productId']?.toString(),
      itemType: (json['itemType'] ?? 'SERVICE').toString(),
      description: (json['description'] ?? '').toString(),
      quantity: quantity(json['quantity']),
      unitPriceCents: cents(json['unitPriceCents']),
      discountCents: cents(json['discountCents']),
      taxCents: cents(json['taxCents']),
      subtotalCents: cents(json['subtotalCents']),
      totalCents: cents(json['totalCents']),
      employeePartnerId: json['employeePartnerId']?.toString(),
      scheduledStartAt: date(json['scheduledStartAt']),
      scheduledEndAt: date(json['scheduledEndAt']),
      completionStatus:
          (json['completionStatus'] ?? 'NOT_STARTED').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (productId != null && productId!.isNotEmpty) 'productId': productId,
        'itemType': itemType,
        'description': description,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
        'discountCents': discountCents,
        'taxCents': taxCents,
        if (employeePartnerId != null && employeePartnerId!.isNotEmpty)
          'employeePartnerId': employeePartnerId,
        if (scheduledStartAt != null)
          'scheduledStartAt': scheduledStartAt!.toIso8601String(),
        if (scheduledEndAt != null)
          'scheduledEndAt': scheduledEndAt!.toIso8601String(),
        'completionStatus': completionStatus,
      };
}

class ServiceOrderSource {
  final String sourceType;
  final String sourceId;
  final String sourceNo;

  const ServiceOrderSource({
    required this.sourceType,
    required this.sourceId,
    required this.sourceNo,
  });

  factory ServiceOrderSource.fromJson(Map<String, dynamic> json) =>
      ServiceOrderSource(
        sourceType: (json['sourceType'] ?? '').toString(),
        sourceId: (json['sourceId'] ?? '').toString(),
        sourceNo: (json['sourceNo'] ?? '').toString(),
      );

  String get displayLabel {
    final type = sourceType.replaceAll('_', ' ');
    final reference = sourceNo.isEmpty ? sourceId : sourceNo;
    return reference.isEmpty ? type : '$type • $reference';
  }
}

class ServiceOrder {
  final String id;
  final String serviceOrderNo;
  final String customerPartnerId;
  final String customerName;
  final String? assignedEmployeePartnerId;
  final String assignedEmployeeName;
  final String? salesAreaId;
  final DateTime? orderDate;
  final DateTime? scheduledStartAt;
  final DateTime? scheduledEndAt;
  final String status;
  final String location;
  final String notes;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final String currency;
  final String? invoiceId;
  final String invoiceStatus;
  final List<ServiceOrderSource> sources;
  final List<ServiceOrderLine> lines;

  const ServiceOrder({
    required this.id,
    required this.serviceOrderNo,
    required this.customerPartnerId,
    required this.customerName,
    this.assignedEmployeePartnerId,
    required this.assignedEmployeeName,
    this.salesAreaId,
    required this.orderDate,
    this.scheduledStartAt,
    this.scheduledEndAt,
    required this.status,
    required this.location,
    required this.notes,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    required this.currency,
    this.invoiceId,
    required this.invoiceStatus,
    required this.sources,
    required this.lines,
  });

  bool get isInvoiced => status.toUpperCase() == 'INVOICED' ||
      invoiceStatus.toUpperCase() == 'INVOICED' ||
      (invoiceId != null && invoiceId!.isNotEmpty);

  String get primarySourceLabel =>
      sources.isEmpty ? 'Direct service order' : sources.first.displayLabel;

  factory ServiceOrder.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) =>
        value is num ? value.round() : int.tryParse('${value ?? 0}') ?? 0;
    DateTime? date(dynamic value) {
      if (value == null || value.toString().isEmpty) return null;
      return DateTime.tryParse(value.toString());
    }

    final rawLines = json['lines'];
    final rawSources = json['sources'];
    return ServiceOrder(
      id: (json['id'] ?? '').toString(),
      serviceOrderNo: (json['serviceOrderNo'] ?? '').toString(),
      customerPartnerId: (json['customerPartnerId'] ?? '').toString(),
      customerName: (json['customerName'] ?? 'Customer').toString(),
      assignedEmployeePartnerId: json['assignedEmployeePartnerId']?.toString(),
      assignedEmployeeName:
          (json['assignedEmployeeName'] ?? 'Unassigned').toString(),
      salesAreaId: json['salesAreaId']?.toString(),
      orderDate: date(json['orderDate'] ?? json['serviceDate']),
      scheduledStartAt: date(json['scheduledStartAt']),
      scheduledEndAt: date(json['scheduledEndAt']),
      status: (json['status'] ?? 'DRAFT').toString(),
      location: (json['location'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      subtotalCents: cents(json['subtotalCents']),
      discountCents: cents(json['discountCents']),
      taxCents: cents(json['taxCents']),
      totalCents: cents(json['totalCents']),
      currency: (json['currency'] ?? 'ZAR').toString(),
      invoiceId: json['invoiceId']?.toString(),
      invoiceStatus: (json['invoiceStatus'] ?? 'NOT_INVOICED').toString(),
      sources: rawSources is List
          ? rawSources
              .whereType<Map>()
              .map((source) => ServiceOrderSource.fromJson(
                    Map<String, dynamic>.from(source),
                  ))
              .toList()
          : <ServiceOrderSource>[],
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map((line) => ServiceOrderLine.fromJson(
                    Map<String, dynamic>.from(line),
                  ))
              .toList()
          : <ServiceOrderLine>[],
    );
  }
}
