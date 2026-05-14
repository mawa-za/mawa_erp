class ApprovalStep {
  final int stepNo;
  final String stepName;
  final String approverType;
  final String approverValue;
  final int requiredApprovals;

  ApprovalStep({
    required this.stepNo,
    required this.stepName,
    required this.approverType,
    required this.approverValue,
    required this.requiredApprovals,
  });

  factory ApprovalStep.fromJson(Map<String, dynamic> json) {
    return ApprovalStep(
      stepNo: json['stepNo'] ?? 0,
      stepName: json['stepName'] ?? '',
      approverType: json['approverType'] ?? '',
      approverValue: json['approverValue'] ?? '',
      requiredApprovals: json['requiredApprovals'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stepNo': stepNo,
      'stepName': stepName,
      'approverType': approverType,
      'approverValue': approverValue,
      'requiredApprovals': requiredApprovals,
    };
  }
}

class ApprovalWorkflow {
  final String? id;
  final String approvalType;
  final String name;
  final String description;
  final List<ApprovalStep> steps;
  final bool? active;
  final String? createdAt;
  final String? createdBy;
  final String? updatedAt;
  final String? updatedBy;

  ApprovalWorkflow({
    this.id,
    required this.approvalType,
    required this.name,
    required this.description,
    required this.steps,
    this.active,
    this.createdAt,
    this.createdBy,
    this.updatedAt,
    this.updatedBy,
  });

  factory ApprovalWorkflow.fromJson(Map<String, dynamic> json) {
    return ApprovalWorkflow(
      id: json['id'],
      approvalType: json['approvalType'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      steps: (json['steps'] as List? ?? [])
          .map((step) => ApprovalStep.fromJson(step))
          .toList(),
      active: json['active'],
      createdAt: json['createdAt'],
      createdBy: json['createdBy'],
      updatedAt: json['updatedAt'],
      updatedBy: json['updatedBy'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'approvalType': approvalType,
      'name': name,
      'description': description,
      'steps': steps.map((step) => step.toJson()).toList(),
    };
    if (id != null) data['id'] = id;
    return data;
  }
}
