class ManualReceiptBook {
  final String id;
  final String receiptBookNo;
  final String description;
  final String? receiptFromNo;
  final String? receiptToNo;
  final String? assignedEmployeeId;
  final String? assignedEmployeeName;
  final String? assignedAreaCode;
  final String? assignedAreaName;
  final String status;
  final bool active;
  final String? effectiveFrom;
  final String? effectiveTo;
  final String? notes;

  const ManualReceiptBook({
    required this.id,
    required this.receiptBookNo,
    required this.description,
    this.receiptFromNo,
    this.receiptToNo,
    this.assignedEmployeeId,
    this.assignedEmployeeName,
    this.assignedAreaCode,
    this.assignedAreaName,
    required this.status,
    required this.active,
    this.effectiveFrom,
    this.effectiveTo,
    this.notes,
  });

  factory ManualReceiptBook.fromJson(Map<String, dynamic> json) {
    String? nullable(dynamic value) {
      final text = value?.toString().trim();
      return text == null || text.isEmpty ? null : text;
    }

    return ManualReceiptBook(
      id: (json['id'] ?? '').toString(),
      receiptBookNo: (json['receiptBookNo'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      receiptFromNo: nullable(json['receiptFromNo']),
      receiptToNo: nullable(json['receiptToNo']),
      assignedEmployeeId: nullable(json['assignedEmployeeId']),
      assignedEmployeeName: nullable(json['assignedEmployeeName']),
      assignedAreaCode: nullable(json['assignedAreaCode']),
      assignedAreaName: nullable(json['assignedAreaName']),
      status: (json['status'] ?? 'ACTIVE').toString(),
      active: json['active'] != false,
      effectiveFrom: nullable(json['effectiveFrom']),
      effectiveTo: nullable(json['effectiveTo']),
      notes: nullable(json['notes']),
    );
  }

  String get rangeLabel {
    if (receiptFromNo == null || receiptToNo == null) return 'No receipt number range configured';
    return '$receiptFromNo – $receiptToNo';
  }
}
