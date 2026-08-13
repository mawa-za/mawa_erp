class ApprovalWorkflowStepApprover {
  final String? id;
  final String approverType; // USER, ROLE, GROUP, MANAGER
  final String approverValue;
  final String? approverName;
  final bool active;

  ApprovalWorkflowStepApprover({
    this.id,
    required this.approverType,
    required this.approverValue,
    this.approverName,
    this.active = true,
  });

  factory ApprovalWorkflowStepApprover.fromJson(Map<String, dynamic> json) {
    return ApprovalWorkflowStepApprover(
      id: json['id']?.toString(),
      approverType: json['approverType']?.toString() ?? '',
      approverValue: json['approverValue']?.toString() ?? '',
      approverName: json['approverName']?.toString(),
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'approverType': approverType,
      'approverValue': approverValue,
      if (approverName != null) 'approverName': approverName,
      'active': active,
    };
  }
}

class ApprovalStep {
  final String? id;
  final int stepNo;
  final String stepName;
  final String approvalMode; // ANY_ONE, ALL
  final int requiredApprovals;
  final bool active;
  final List<ApprovalWorkflowStepApprover> approvers;

  ApprovalStep({
    this.id,
    required this.stepNo,
    required this.stepName,
    this.approvalMode = 'ANY_ONE',
    required this.requiredApprovals,
    this.active = true,
    required this.approvers,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> json) {
    return ApprovalStep(
      id: json['id']?.toString(),
      stepNo: json['stepNo'] ?? 0,
      stepName: json['stepName']?.toString() ?? '',
      approvalMode: json['approvalMode']?.toString() ?? 'ANY_ONE',
      requiredApprovals: json['requiredApprovals'] ?? 0,
      active: json['active'] == true,
      approvers: (json['approvers'] as List? ?? [])
          .map((a) => ApprovalWorkflowStepApprover.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'stepNo': stepNo,
      'stepName': stepName,
      'approvalMode': approvalMode,
      'requiredApprovals': requiredApprovals,
      'active': active,
      'approvers': approvers.map((a) => a.toJson()).toList(),
    };
  }
}

class ApprovalWorkflow {
  final String? id;
  final String approvalType;
  final String name;
  final String description;
  final double? minAmount;
  final double? maxAmount;
  final bool active;
  final bool autoApprove;
  final List<ApprovalStep> steps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ApprovalWorkflow({
    this.id,
    required this.approvalType,
    required this.name,
    required this.description,
    this.minAmount,
    this.maxAmount,
    this.active = true,
    this.autoApprove = false,
    required this.steps,
    this.createdAt,
    this.updatedAt,
  });

  factory ApprovalWorkflow.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic raw) {
      if (raw == null) return null;
      if (raw is String) return DateTime.tryParse(raw);
      if (raw is List) {
        if (raw.length < 3) return null;
        try {
          return DateTime(
            raw[0] as int,
            raw[1] as int,
            raw[2] as int,
            raw.length > 3 ? raw[3] as int : 0,
            raw.length > 4 ? raw[4] as int : 0,
            raw.length > 5 ? raw[5] as int : 0,
          );
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return ApprovalWorkflow(
      id: json['id']?.toString(),
      approvalType: json['approvalType']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      minAmount: (json['minAmount'] as num?)?.toDouble(),
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      active: json['active'] == true,
      autoApprove: json['autoApprove'] == true,
      steps: (json['steps'] as List? ?? [])
          .map((step) => ApprovalStep.fromJson(Map<String, dynamic>.from(step)))
          .toList(),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseDateTime(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'approvalType': approvalType,
      'name': name,
      'description': description,
      if (minAmount != null) 'minAmount': minAmount,
      if (maxAmount != null) 'maxAmount': maxAmount,
      'active': active,
      'autoApprove': autoApprove,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
  }
}
