class MembershipPlan {
  final String id;
  final String planCode;
  final String name;
  final String description;
  final int premiumCents;
  final String currency;
  final int maxDependents;
  final bool active;
  final List<int>? createdAt;
  final String? oldId;

  MembershipPlan({
    required this.id,
    required this.planCode,
    required this.name,
    required this.description,
    required this.premiumCents,
    required this.currency,
    required this.maxDependents,
    required this.active,
    this.createdAt,
    this.oldId,
  });

  double get premium => premiumCents / 100.0;

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id'] ?? '',
      planCode: json['planCode'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      premiumCents: json['premiumCents'] ?? 0,
      currency: json['currency'] ?? 'ZAR',
      maxDependents: json['maxDependents'] ?? 0,
      active: json['active'] ?? false,
      createdAt: json['createdAt'] != null ? List<int>.from(json['createdAt']) : null,
      oldId: json['oldId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planCode': planCode,
      'name': name,
      'description': description,
      'premiumCents': premiumCents,
      'currency': currency,
      'maxDependents': maxDependents,
      'active': active,
      if (createdAt != null) 'createdAt': createdAt,
      if (oldId != null) 'oldId': oldId,
    };
  }
}
