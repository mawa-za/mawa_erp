class MembershipChange {
  final String id;
  final String membershipId;
  final String changeType;
  final String status;
  final String oldMemberId;
  final String oldMemberName;
  final String newMemberId;
  final String newMemberName;
  final String oldPlanId;
  final String oldPlanName;
  final String newPlanId;
  final String newPlanName;
  final int waitingPeriodMonths;
  final String? effectiveDate;
  final String reason;
  final String approvalRequestId;
  final String? requestedAt;
  final String requestedBy;
  final String? approvedAt;
  final String approvedBy;
  final String? appliedAt;
  final String appliedBy;

  const MembershipChange({
    required this.id,
    required this.membershipId,
    required this.changeType,
    required this.status,
    required this.oldMemberId,
    required this.oldMemberName,
    required this.newMemberId,
    required this.newMemberName,
    required this.oldPlanId,
    required this.oldPlanName,
    required this.newPlanId,
    required this.newPlanName,
    required this.waitingPeriodMonths,
    required this.effectiveDate,
    required this.reason,
    required this.approvalRequestId,
    required this.requestedAt,
    required this.requestedBy,
    required this.approvedAt,
    required this.approvedBy,
    required this.appliedAt,
    required this.appliedBy,
  });

  factory MembershipChange.fromJson(Map<String, dynamic> json) => MembershipChange(
    id: '${json['id'] ?? ''}',
    membershipId: '${json['membershipId'] ?? ''}',
    changeType: '${json['changeType'] ?? ''}',
    status: '${json['status'] ?? ''}',
    oldMemberId: '${json['oldMemberId'] ?? ''}',
    oldMemberName: '${json['oldMemberName'] ?? json['oldMemberId'] ?? ''}',
    newMemberId: '${json['newMemberId'] ?? ''}',
    newMemberName: '${json['newMemberName'] ?? json['newMemberId'] ?? ''}',
    oldPlanId: '${json['oldPlanId'] ?? ''}',
    oldPlanName: '${json['oldPlanName'] ?? json['oldPlanId'] ?? ''}',
    newPlanId: '${json['newPlanId'] ?? ''}',
    newPlanName: '${json['newPlanName'] ?? json['newPlanId'] ?? ''}',
    waitingPeriodMonths: _asInt(json['waitingPeriodMonths']),
    effectiveDate: _date(json['effectiveDate']),
    reason: '${json['reason'] ?? ''}',
    approvalRequestId: '${json['approvalRequestId'] ?? ''}',
    requestedAt: _date(json['requestedAt']),
    requestedBy: '${json['requestedBy'] ?? ''}',
    approvedAt: _date(json['approvedAt']),
    approvedBy: '${json['approvedBy'] ?? ''}',
    appliedAt: _date(json['appliedAt']),
    appliedBy: '${json['appliedBy'] ?? ''}',
  );

  bool get isOpen => status == 'PENDING_APPROVAL' || status == 'APPROVED_SCHEDULED';
  bool get isTransfer => changeType == 'TRANSFER';

  static int _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static String? _date(dynamic value) {
    if (value == null) return null;
    if (value is List && value.length >= 3) {
      final month = '${value[1]}'.padLeft(2, '0');
      final day = '${value[2]}'.padLeft(2, '0');
      return '${value[0]}-$month-$day';
    }
    return '$value';
  }
}

class MembershipChangeAudit {
  final String id;
  final String eventType;
  final String details;
  final String performedBy;
  final String? performedAt;
  final String oldValuesJson;
  final String newValuesJson;

  const MembershipChangeAudit({
    required this.id,
    required this.eventType,
    required this.details,
    required this.performedBy,
    required this.performedAt,
    required this.oldValuesJson,
    required this.newValuesJson,
  });

  factory MembershipChangeAudit.fromJson(Map<String, dynamic> json) => MembershipChangeAudit(
    id: '${json['id'] ?? ''}',
    eventType: '${json['eventType'] ?? ''}',
    details: '${json['details'] ?? ''}',
    performedBy: '${json['performedBy'] ?? ''}',
    performedAt: MembershipChange._date(json['performedAt']),
    oldValuesJson: '${json['oldValuesJson'] ?? ''}',
    newValuesJson: '${json['newValuesJson'] ?? ''}',
  );
}

class MembershipChangeConfiguration {
  final int planChangeWaitingPeriodMonths;
  const MembershipChangeConfiguration(this.planChangeWaitingPeriodMonths);
  factory MembershipChangeConfiguration.fromJson(Map<String, dynamic> json) =>
      MembershipChangeConfiguration(MembershipChange._asInt(json['planChangeWaitingPeriodMonths']));
}
