import '../../../core/utils/app_date_utils.dart';

class ApprovalSubmission {
  final String approvalType; // Enum: CLAIM, PAYMENT, LEAVE, etc.
  final String referenceId;
  final String referenceNo;
  final String title;
  final String description;
  final String requesterId;
  final String? payloadJson;

  ApprovalSubmission({
    required this.approvalType,
    required this.referenceId,
    required this.referenceNo,
    required this.title,
    required this.description,
    required this.requesterId,
    this.payloadJson,
  });

  Map<String, dynamic> toJson() => {
    'approvalType': approvalType,
    'referenceId': referenceId,
    'referenceNo': referenceNo,
    'title': title,
    'description': description,
    'requesterId': requesterId,
    if (payloadJson != null) 'payloadJson': payloadJson,
  };
}

class Approval {
  final String id;
  final String approvalType;
  final String referenceId;
  final String referenceNo;
  final String title;
  final String description;
  final String requesterId;
  final String? workflowId;
  final int currentStepNo;
  final String status; // PENDING, IN_PROGRESS, APPROVED, REJECTED, CANCELLED
  final String? payloadJson;
  final String? finalActionBy;
  final String? finalActionAt;
  final String createdAt;
  final String? createdBy;
  final String updatedAt;
  final String? updatedBy;

  Approval({
    required this.id,
    required this.approvalType,
    required this.referenceId,
    required this.referenceNo,
    required this.title,
    required this.description,
    required this.requesterId,
    this.workflowId,
    required this.currentStepNo,
    required this.status,
    this.payloadJson,
    this.finalActionBy,
    this.finalActionAt,
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.updatedBy,
  });

  factory Approval.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return Approval(
      id: (json['id'] ?? '').toString(),
      approvalType: (json['approvalType'] ?? '').toString(),
      referenceId: (json['referenceId'] ?? '').toString(),
      referenceNo: (json['referenceNo'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      requesterId: (json['requesterId'] ?? '').toString(),
      workflowId: json['workflowId']?.toString(),
      currentStepNo: toInt(json['currentStepNo']),
      status: (json['status'] ?? 'PENDING').toString(),
      payloadJson: json['payloadJson']?.toString(),
      finalActionBy: json['finalActionBy']?.toString(),
      finalActionAt: json['finalActionAt'] == null ? null : AppDateUtils.normalizeDateTime(json['finalActionAt']),
      createdAt: AppDateUtils.normalizeDateTime(json['createdAt']),
      createdBy: json['createdBy']?.toString(),
      updatedAt: AppDateUtils.normalizeDateTime(json['updatedAt']),
      updatedBy: json['updatedBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'approvalType': approvalType,
    'referenceId': referenceId,
    'referenceNo': referenceNo,
    'title': title,
    'description': description,
    'requesterId': requesterId,
    'workflowId': workflowId,
    'currentStepNo': currentStepNo,
    'status': status,
    'payloadJson': payloadJson,
    'finalActionBy': finalActionBy,
    'finalActionAt': finalActionAt,
    'createdAt': createdAt,
    'createdBy': createdBy,
    'updatedAt': updatedAt,
    'updatedBy': updatedBy,
  };
}

class ApprovalAction {
  final String id;
  final String approvalRequestId;
  final int stepNo;
  final String action; // SUBMITTED, APPROVED, REJECTED, CANCELLED, COMMENTED
  final String actionBy;
  final String actionAt;
  final String? comments;

  ApprovalAction({
    required this.id,
    required this.approvalRequestId,
    required this.stepNo,
    required this.action,
    required this.actionBy,
    required this.actionAt,
    this.comments,
  });

  factory ApprovalAction.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return ApprovalAction(
      id: (json['id'] ?? '').toString(),
      approvalRequestId: (json['approvalRequestId'] ?? '').toString(),
      stepNo: toInt(json['stepNo']),
      action: (json['action'] ?? '').toString(),
      actionBy: (json['actionBy'] ?? '').toString(),
      actionAt: AppDateUtils.normalizeDateTime(json['actionAt']),
      comments: json['comments']?.toString(),
    );
  }
}
