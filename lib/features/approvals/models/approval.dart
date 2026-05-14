class ApprovalSubmission {
  final String approvalType;
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

  Map<String, dynamic> toJson() {
    return {
      'approvalType': approvalType,
      'referenceId': referenceId,
      'referenceNo': referenceNo,
      'title': title,
      'description': description,
      'requesterId': requesterId,
      'payloadJson': payloadJson,
    };
  }
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
  final String status;
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
    return Approval(
      id: json['id'] ?? '',
      approvalType: json['approvalType'] ?? '',
      referenceId: json['referenceId'] ?? '',
      referenceNo: json['referenceNo'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      requesterId: json['requesterId'] ?? '',
      workflowId: json['workflowId'],
      currentStepNo: json['currentStepNo'] ?? 0,
      status: json['status'] ?? 'PENDING',
      payloadJson: json['payloadJson'],
      finalActionBy: json['finalActionBy'],
      finalActionAt: json['finalActionAt'],
      createdAt: json['createdAt'] ?? '',
      createdBy: json['createdBy'],
      updatedAt: json['updatedAt'] ?? '',
      updatedBy: json['updatedBy'],
    );
  }
}
