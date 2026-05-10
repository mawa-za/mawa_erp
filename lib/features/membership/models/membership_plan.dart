class MembershipPlan {
  final String id;
  final String planCode;
  final String name;
  final String description;
  final int premiumCents;
  final String currency;
  final int maxDependents;
  final bool active;
  final String? createdAt;
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
    String? parseDateArray(dynamic date) {
      if (date == null) return null;
      if (date is List && date.length >= 3) {
        try {
          final year = date[0].toString();
          final month = date[1].toString().padLeft(2, '0');
          final day = date[2].toString().padLeft(2, '0');

          if (date.length >= 5) {
            final hour = date[3].toString().padLeft(2, '0');
            final minute = date[4].toString().padLeft(2, '0');
            return '$year-$month-$day $hour:$minute';
          }
          return '$year-$month-$day';
        } catch (e) {
          return date.toString();
        }
      }
      return date?.toString();
    }

    return MembershipPlan(
      id: (json['id'] ?? '').toString(),
      planCode: (json['planCode'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      premiumCents: json['premiumCents'] is int ? json['premiumCents'] : (int.tryParse(json['premiumCents']?.toString() ?? '0') ?? 0),
      currency: (json['currency'] ?? 'ZAR').toString(),
      maxDependents: json['maxDependents'] is int ? json['maxDependents'] : (int.tryParse(json['maxDependents']?.toString() ?? '0') ?? 0),
      active: json['active'] == true,
      createdAt: parseDateArray(json['createdAt']),
      oldId: json['oldId']?.toString(),
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
      'createdAt': createdAt,
      'oldId': oldId,
    };
  }
}
