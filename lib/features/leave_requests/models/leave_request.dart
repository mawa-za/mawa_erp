class LeaveRequest {
  final String id;
  final String type;
  final String employeeId;
  final String? employeeName;
  final String? approverId;
  final String? approverName;
  final String startDate;
  final String endDate;
  final double days;
  final String status;
  final String? createdAt;

  LeaveRequest({
    required this.id,
    required this.type,
    required this.employeeId,
    this.employeeName,
    this.approverId,
    this.approverName,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    final employee = _asMap(json['employee']);
    final approver = _asMap(json['approver']);

    return LeaveRequest(
      id: (json['id'] ?? '').toString(),
      type: _fieldOptionLabel(json['type']),
      employeeId: (employee?['id'] ?? json['employeeId'] ?? json['employee'] ?? '').toString(),
      employeeName: _partnerName(employee) ?? json['employeeName']?.toString(),
      approverId: (approver?['id'] ?? json['approverId'] ?? (json['approver'] is String ? json['approver'] : null))?.toString(),
      approverName: _partnerName(approver) ?? json['approverName']?.toString(),
      startDate: _dateValue(json['startDate']),
      endDate: _dateValue(json['endDate']),
      days: _numberValue(json['days']),
      status: _fieldOptionCode(json['status'], fallback: 'PENDING'),
      createdAt: json['createdAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'employee': employeeId,
      'approver': approverId,
      'startDate': startDate,
      'endDate': endDate,
      'days': days,
      'status': status,
    };
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

String _fieldOptionLabel(dynamic value) {
  final map = _asMap(value);
  if (map != null) {
    return (map['description'] ?? map['code'] ?? '').toString();
  }
  return (value ?? '').toString();
}

String _fieldOptionCode(dynamic value, {required String fallback}) {
  final map = _asMap(value);
  if (map != null) {
    return (map['code'] ?? map['description'] ?? fallback).toString();
  }
  final parsed = (value ?? fallback).toString();
  return parsed.isEmpty ? fallback : parsed;
}

String? _partnerName(Map<String, dynamic>? partner) {
  if (partner == null) return null;
  final names = [partner['name1'], partner['name2'], partner['name3'], partner['name4']]
      .where((value) => value != null && value.toString().trim().isNotEmpty)
      .map((value) => value.toString().trim())
      .toList();
  return names.isEmpty ? null : names.join(' ');
}

String _dateValue(dynamic value) {
  if (value == null) return '';
  if (value is List && value.length >= 3) {
    final year = value[0].toString().padLeft(4, '0');
    final month = value[1].toString().padLeft(2, '0');
    final day = value[2].toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
  final text = value.toString();
  return text.length >= 10 ? text.substring(0, 10) : text;
}

double _numberValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}
