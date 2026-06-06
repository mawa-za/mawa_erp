import 'package:intl/intl.dart';

class CaseTask {
  final String id;
  final String caseId;
  final String title;
  final String? description;
  final String? assignedTo;
  final String priority;
  final String status;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? completedBy;
  final bool billable;
  final int estimatedMinutes;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? updatedAt;
  final String? updatedBy;

  CaseTask({
    required this.id,
    required this.caseId,
    required this.title,
    this.description,
    this.assignedTo,
    required this.priority,
    required this.status,
    this.dueDate,
    this.completedAt,
    this.completedBy,
    this.billable = true,
    this.estimatedMinutes = 0,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory CaseTask.fromJson(Map<String, dynamic> json) {
    return CaseTask(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      status: (json['status'] ?? 'TODO').toString(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate']) : null,
      completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      completedBy: json['completedBy']?.toString(),
      billable: json['billable'] ?? true,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'priority': priority,
      'status': status,
      'dueDate': dueDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'completedBy': completedBy,
      'billable': billable,
      'estimatedMinutes': estimatedMinutes,
    };
  }
}

class CreateCaseTaskRequest {
  final String title;
  final String? description;
  final String? assignedTo;
  final String priority;
  final DateTime? dueDate;
  final bool billable;
  final int estimatedMinutes;

  CreateCaseTaskRequest({
    required this.title,
    this.description,
    this.assignedTo,
    this.priority = 'NORMAL',
    this.dueDate,
    this.billable = true,
    this.estimatedMinutes = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'priority': priority,
      'dueDate': dueDate != null ? DateFormat('yyyy-MM-dd').format(dueDate!) : null,
      'billable': billable,
      'estimatedMinutes': estimatedMinutes,
    };
  }
}

class UpdateCaseTaskStatusRequest {
  final String status;
  final String? completedBy;

  UpdateCaseTaskStatusRequest({required this.status, this.completedBy});

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'completedBy': completedBy,
    };
  }
}
