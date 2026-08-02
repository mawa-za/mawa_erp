class LeaveRequest {
  final String id;
  final String requestNumber;
  final String leaveTypeId;
  final String leaveTypeCode;
  final String leaveTypeName;
  final String employeeId;
  final String employeeName;
  final String employmentId;
  final String employeeNumber;
  final String leaveProfileName;
  final String workingCalendarName;
  final String assignmentSource;
  final String startDate;
  final String endDate;
  final double amount;
  final String unit;
  final double availableBalance;
  final double projectedBalance;
  final String reason;
  final List<String> attachmentObjectIds;
  final bool supportingDocumentRequired;
  final String? approvalRequestId;
  final String status;
  final String? statusReason;
  final String? submittedAt;
  final String? createdAt;
  final List<Map<String, dynamic>> history;

  const LeaveRequest({
    required this.id,
    required this.requestNumber,
    required this.leaveTypeId,
    required this.leaveTypeCode,
    required this.leaveTypeName,
    required this.employeeId,
    required this.employeeName,
    required this.employmentId,
    required this.employeeNumber,
    required this.leaveProfileName,
    required this.workingCalendarName,
    required this.assignmentSource,
    required this.startDate,
    required this.endDate,
    required this.amount,
    required this.unit,
    required this.availableBalance,
    required this.projectedBalance,
    required this.reason,
    required this.attachmentObjectIds,
    required this.supportingDocumentRequired,
    this.approvalRequestId,
    required this.status,
    this.statusReason,
    this.submittedAt,
    this.createdAt,
    required this.history,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    final employee = _map(json['employee']);
    final leaveType = _map(json['leaveType']);
    return LeaveRequest(
      id: _text(json['id']),
      requestNumber: _text(json['requestNumber'], fallback: _text(json['id'])),
      leaveTypeId: _text(leaveType['id'] ?? json['leaveTypeId']),
      leaveTypeCode: _text(leaveType['code'] ?? json['leaveTypeCode'] ?? _fieldCode(json['type'])),
      leaveTypeName: _text(leaveType['name'] ?? json['leaveTypeName'] ?? _fieldLabel(json['type'])),
      employeeId: _text(employee['id'] ?? json['employeeId']),
      employeeName: _partnerName(employee),
      employmentId: _text(json['employmentId']),
      employeeNumber: _text(json['employeeNumber']),
      leaveProfileName: _text(json['leaveProfileName']),
      workingCalendarName: _text(json['workingCalendarName']),
      assignmentSource: _text(json['assignmentSource']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      amount: _number(json['days'] ?? json['requestedAmount']),
      unit: _text(json['unit'], fallback: _text(leaveType['unit'], fallback: 'DAYS')),
      availableBalance: _number(json['availableBalance']),
      projectedBalance: _number(json['projectedBalance']),
      reason: _text(json['requestReason'] ?? json['reason']),
      attachmentObjectIds: (json['attachmentObjectIds'] is List)
          ? (json['attachmentObjectIds'] as List).map((value) => value.toString()).toList()
          : const [],
      supportingDocumentRequired: json['supportingDocumentRequired'] == true,
      approvalRequestId: json['approvalRequestId']?.toString(),
      status: _fieldCode(json['status'], fallback: 'PENDING'),
      statusReason: json['statusReason']?.toString(),
      submittedAt: json['submittedAt']?.toString(),
      createdAt: json['createdAt']?.toString(),
      history: (json['statusHistory'] is List)
          ? (json['statusHistory'] as List).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : const [],
    );
  }
}

class LeaveRequestPreview {
  final String employmentId;
  final String employeeNumber;
  final String leaveTypeId;
  final String leaveTypeName;
  final String unit;
  final String leaveProfileName;
  final String assignmentSource;
  final String workingCalendarName;
  final double requestedAmount;
  final double availableBalance;
  final double projectedBalance;
  final bool supportingDocumentRequired;
  final bool allowed;
  final String message;

  const LeaveRequestPreview({
    required this.employmentId,
    required this.employeeNumber,
    required this.leaveTypeId,
    required this.leaveTypeName,
    required this.unit,
    required this.leaveProfileName,
    required this.assignmentSource,
    required this.workingCalendarName,
    required this.requestedAmount,
    required this.availableBalance,
    required this.projectedBalance,
    required this.supportingDocumentRequired,
    required this.allowed,
    required this.message,
  });

  factory LeaveRequestPreview.fromJson(Map<String, dynamic> json) => LeaveRequestPreview(
        employmentId: _text(json['employmentId']),
        employeeNumber: _text(json['employeeNumber']),
        leaveTypeId: _text(json['leaveTypeId']),
        leaveTypeName: _text(json['leaveTypeName']),
        unit: _text(json['unit'], fallback: 'DAYS'),
        leaveProfileName: _text(json['leaveProfileName']),
        assignmentSource: _text(json['assignmentSource']),
        workingCalendarName: _text(json['workingCalendarName']),
        requestedAmount: _number(json['requestedAmount']),
        availableBalance: _number(json['availableBalance']),
        projectedBalance: _number(json['projectedBalance']),
        supportingDocumentRequired: json['supportingDocumentRequired'] == true,
        allowed: json['allowed'] == true,
        message: _text(json['message']),
      );
}

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

String _fieldCode(dynamic value, {String fallback = ''}) {
  final map = _map(value);
  return _text(map['code'] ?? value, fallback: fallback);
}

String _fieldLabel(dynamic value) {
  final map = _map(value);
  return _text(map['description'] ?? map['code'] ?? value);
}

String _partnerName(Map<String, dynamic> partner) {
  final values = [partner['name2'], partner['name3'], partner['name1'], partner['name4']]
      .map((value) => _text(value))
      .where((value) => value.isNotEmpty)
      .toList();
  return values.isEmpty ? _text(partner['number'], fallback: 'Unknown employee') : values.join(' ');
}

String _date(dynamic value) {
  if (value == null) return '';
  if (value is List && value.length >= 3) {
    return '${value[0].toString().padLeft(4, '0')}-${value[1].toString().padLeft(2, '0')}-${value[2].toString().padLeft(2, '0')}';
  }
  final text = value.toString();
  return text.length >= 10 ? text.substring(0, 10) : text;
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
