class LeaveRequest {
  final String id;
  final String type;
  final String employeeId;
  final String? employeeName;
  final String? approverId;
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
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.createdAt,
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      employeeId: (json['employee'] ?? json['employeeId'] ?? '').toString(),
      employeeName: json['employeeName']?.toString(),
      approverId: json['approver']?.toString(),
      startDate: (json['startDate'] ?? '').toString(),
      endDate: (json['endDate'] ?? '').toString(),
      days: (json['days'] ?? 0.0).toDouble(),
      status: (json['status'] ?? 'PENDING').toString(),
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
