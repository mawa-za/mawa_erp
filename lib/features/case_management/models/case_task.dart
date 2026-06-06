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

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) return DateTime.tryParse(date);
    if (date is List) {
      if (date.length >= 3) {
        try {
          return DateTime(
            (date[0] as num).toInt(),
            (date[1] as num).toInt(),
            (date[2] as num).toInt(),
            date.length >= 4 ? (date[3] as num).toInt() : 0,
            date.length >= 5 ? (date[4] as num).toInt() : 0,
            date.length >= 6 ? (date[5] as num).toInt() : 0,
          );
        } catch (e) {
          return null;
        }
      }
    }
    return null;
  }

  factory CaseTask.fromJson(Map<String, dynamic> json) {
    return CaseTask(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      assignedTo: json['assignedTo']?.toString(),
      priority: (json['priority'] ?? 'NORMAL').toString(),
      status: (json['status'] ?? 'TODO').toString(),
      dueDate: _parseDate(json['dueDate']),
      completedAt: _parseDate(json['completedAt']),
      completedBy: json['completedBy']?.toString(),
      billable: json['billable'] ?? true,
      estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: _parseDate(json['updatedAt']),
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
  final String status;
  final DateTime? dueDate;
  final bool billable;
  final int estimatedMinutes;

  CreateCaseTaskRequest({
    required this.title,
    this.description,
    this.assignedTo,
    this.priority = 'NORMAL',
    this.status = 'TODO',
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
      'status': status,
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
