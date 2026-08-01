class AppointmentServiceOrderLine {
  final String? id;
  final String? productId;
  final String description;
  final double quantity;
  final int unitPriceCents;
  final int discountCents;
  final int taxCents;
  final int subtotalCents;
  final int totalCents;
  final String? employeePartnerId;

  const AppointmentServiceOrderLine({
    this.id,
    this.productId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    this.discountCents = 0,
    this.taxCents = 0,
    this.subtotalCents = 0,
    this.totalCents = 0,
    this.employeePartnerId,
  });

  AppointmentServiceOrderLine copyWith({
    String? id,
    String? productId,
    String? description,
    double? quantity,
    int? unitPriceCents,
    int? discountCents,
    int? taxCents,
    int? subtotalCents,
    int? totalCents,
    String? employeePartnerId,
  }) {
    return AppointmentServiceOrderLine(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unitPriceCents: unitPriceCents ?? this.unitPriceCents,
      discountCents: discountCents ?? this.discountCents,
      taxCents: taxCents ?? this.taxCents,
      subtotalCents: subtotalCents ?? this.subtotalCents,
      totalCents: totalCents ?? this.totalCents,
      employeePartnerId: employeePartnerId ?? this.employeePartnerId,
    );
  }

  factory AppointmentServiceOrderLine.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) =>
        value is num ? value.round() : int.tryParse('${value ?? 0}') ?? 0;
    double quantity(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('${value ?? 1}') ?? 1;
    return AppointmentServiceOrderLine(
      id: json['id']?.toString(),
      productId: json['productId']?.toString(),
      description: (json['description'] ?? '').toString(),
      quantity: quantity(json['quantity']),
      unitPriceCents: cents(json['unitPriceCents']),
      discountCents: cents(json['discountCents']),
      taxCents: cents(json['taxCents']),
      subtotalCents: cents(json['subtotalCents']),
      totalCents: cents(json['totalCents']),
      employeePartnerId: json['employeePartnerId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (productId != null && productId!.isNotEmpty) 'productId': productId,
        'description': description,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
        'discountCents': discountCents,
        'taxCents': taxCents,
        if (employeePartnerId != null && employeePartnerId!.isNotEmpty)
          'employeePartnerId': employeePartnerId,
      };
}

class AppointmentServiceOrder {
  final String id;
  final String serviceOrderNo;
  final String appointmentId;
  final String appointmentNo;
  final String customerPartnerId;
  final String customerName;
  final String? assignedEmployeePartnerId;
  final String assignedEmployeeName;
  final DateTime? serviceDate;
  final String status;
  final String location;
  final String notes;
  final int subtotalCents;
  final int discountCents;
  final int taxCents;
  final int totalCents;
  final String? invoiceId;
  final List<AppointmentServiceOrderLine> lines;

  const AppointmentServiceOrder({
    required this.id,
    required this.serviceOrderNo,
    required this.appointmentId,
    required this.appointmentNo,
    required this.customerPartnerId,
    required this.customerName,
    this.assignedEmployeePartnerId,
    required this.assignedEmployeeName,
    required this.serviceDate,
    required this.status,
    required this.location,
    required this.notes,
    required this.subtotalCents,
    required this.discountCents,
    required this.taxCents,
    required this.totalCents,
    this.invoiceId,
    required this.lines,
  });

  bool get isInvoiced => status.toUpperCase() == 'INVOICED' ||
      (invoiceId != null && invoiceId!.isNotEmpty);

  factory AppointmentServiceOrder.fromJson(Map<String, dynamic> json) {
    int cents(dynamic value) =>
        value is num ? value.round() : int.tryParse('${value ?? 0}') ?? 0;
    DateTime? date(dynamic value) {
      if (value == null || value.toString().isEmpty) return null;
      return DateTime.tryParse(value.toString());
    }

    final rawLines = json['lines'];
    return AppointmentServiceOrder(
      id: (json['id'] ?? '').toString(),
      serviceOrderNo: (json['serviceOrderNo'] ?? '').toString(),
      appointmentId: (json['appointmentId'] ?? '').toString(),
      appointmentNo: (json['appointmentNo'] ?? '').toString(),
      customerPartnerId: (json['customerPartnerId'] ?? '').toString(),
      customerName: (json['customerName'] ?? 'Customer').toString(),
      assignedEmployeePartnerId: json['assignedEmployeePartnerId']?.toString(),
      assignedEmployeeName:
          (json['assignedEmployeeName'] ?? 'Unassigned').toString(),
      serviceDate: date(json['serviceDate']),
      status: (json['status'] ?? 'DRAFT').toString(),
      location: (json['location'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      subtotalCents: cents(json['subtotalCents']),
      discountCents: cents(json['discountCents']),
      taxCents: cents(json['taxCents']),
      totalCents: cents(json['totalCents']),
      invoiceId: json['invoiceId']?.toString(),
      lines: rawLines is List
          ? rawLines
              .whereType<Map>()
              .map((line) => AppointmentServiceOrderLine.fromJson(
                    Map<String, dynamic>.from(line),
                  ))
              .toList()
          : <AppointmentServiceOrderLine>[],
    );
  }
}
