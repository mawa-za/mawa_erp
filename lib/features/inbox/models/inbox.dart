import '../../approvals/models/approval.dart';

class InboxCounts {
  final int unreadCount;
  final int pendingApprovalCount;

  const InboxCounts({
    required this.unreadCount,
    required this.pendingApprovalCount,
  });

  const InboxCounts.empty()
      : unreadCount = 0,
        pendingApprovalCount = 0;

  factory InboxCounts.fromJson(Map<String, dynamic> json) => InboxCounts(
        unreadCount: _toInt(json['unreadCount']),
        pendingApprovalCount: _toInt(json['pendingApprovalCount']),
      );
}

class InboxNotification {
  final String id;
  final String notificationType;
  final String title;
  final String message;
  final String? approvalRequestId;
  final int? approvalStepNo;
  final String? approvalType;
  final String? approvalStatus;
  final String? referenceId;
  final String? referenceNo;
  final String? actionBy;
  final String? actionByDisplayName;
  final String? route;
  final DateTime? readAt;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const InboxNotification({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.message,
    this.approvalRequestId,
    this.approvalStepNo,
    this.approvalType,
    this.approvalStatus,
    this.referenceId,
    this.referenceNo,
    this.actionBy,
    this.actionByDisplayName,
    this.route,
    this.readAt,
    this.resolvedAt,
    this.createdAt,
  });

  bool get isApprovalRequired => notificationType == 'APPROVAL_REQUIRED';
  bool get isUnread => readAt == null && !(isApprovalRequired && resolvedAt != null);

  factory InboxNotification.fromJson(Map<String, dynamic> json) => InboxNotification(
        id: '${json['id'] ?? ''}',
        notificationType: '${json['notificationType'] ?? ''}',
        title: '${json['title'] ?? ''}',
        message: '${json['message'] ?? ''}',
        approvalRequestId: json['approvalRequestId']?.toString(),
        approvalStepNo: json['approvalStepNo'] == null ? null : _toInt(json['approvalStepNo']),
        approvalType: json['approvalType']?.toString(),
        approvalStatus: json['approvalStatus']?.toString(),
        referenceId: json['referenceId']?.toString(),
        referenceNo: json['referenceNo']?.toString(),
        actionBy: json['actionBy']?.toString(),
        actionByDisplayName: json['actionByDisplayName']?.toString(),
        route: json['route']?.toString(),
        readAt: _toDate(json['readAt']),
        resolvedAt: _toDate(json['resolvedAt']),
        createdAt: _toDate(json['createdAt']),
      );
}

class UserInbox {
  final String userId;
  final int unreadCount;
  final int pendingApprovalCount;
  final List<Approval> pendingApprovals;
  final List<InboxNotification> notifications;

  const UserInbox({
    required this.userId,
    required this.unreadCount,
    required this.pendingApprovalCount,
    required this.pendingApprovals,
    required this.notifications,
  });

  factory UserInbox.fromJson(Map<String, dynamic> json) => UserInbox(
        userId: '${json['userId'] ?? ''}',
        unreadCount: _toInt(json['unreadCount']),
        pendingApprovalCount: _toInt(json['pendingApprovalCount']),
        pendingApprovals: ((json['pendingApprovals'] as List?) ?? const [])
            .map((item) => Approval.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        notifications: ((json['notifications'] as List?) ?? const [])
            .map((item) => InboxNotification.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime? _toDate(dynamic value) {
  if (value == null) return null;
  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}
