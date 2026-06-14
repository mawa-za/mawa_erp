enum CommunicationType { newsletter, notice, announcement, campaign }
enum CommunicationStatus { draft, scheduled, sent, cancelled }

class Communication {
  final String id;
  final String title;
  final String content;
  final CommunicationType type;
  final CommunicationStatus status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final List<String> targetRoles;
  final int reachCount;
  final String? createdBy;
  final DateTime? createdAt;

  Communication({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    required this.status,
    this.scheduledAt,
    this.sentAt,
    this.targetRoles = const [],
    this.reachCount = 0,
    this.createdBy,
    this.createdAt,
  });

  factory Communication.fromJson(Map<String, dynamic> json) {
    return Communication(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      type: CommunicationType.values.firstWhere(
        (e) => e.name == (json['type']?.toString().toLowerCase()),
        orElse: () => CommunicationType.announcement,
      ),
      status: CommunicationStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString().toLowerCase()),
        orElse: () => CommunicationStatus.draft,
      ),
      scheduledAt: json['scheduledAt'] != null ? DateTime.parse(json['scheduledAt']) : null,
      sentAt: json['sentAt'] != null ? DateTime.parse(json['sentAt']) : null,
      targetRoles: List<String>.from(json['targetRoles'] ?? []),
      reachCount: json['reachCount'] ?? 0,
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'scheduledAt': scheduledAt?.toIso8601String(),
      'sentAt': sentAt?.toIso8601String(),
      'targetRoles': targetRoles,
      'reachCount': reachCount,
    };
  }
}
