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
  final List<MembershipPlanClaimPayout>? claimPayouts;
  final List<MembershipPlanPremiumRule>? premiumRules;

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
    this.claimPayouts,
    this.premiumRules,
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
      claimPayouts: json['claimPayouts'] != null
          ? (json['claimPayouts'] as List).map((i) => MembershipPlanClaimPayout.fromJson(i)).toList()
          : null,
      premiumRules: json['premiumRules'] != null
          ? (json['premiumRules'] as List).map((i) => MembershipPlanPremiumRule.fromJson(i)).toList()
          : null,
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
      if (claimPayouts != null) 'claimPayouts': claimPayouts!.map((e) => e.toJson()).toList(),
      if (premiumRules != null) 'premiumRules': premiumRules!.map((e) => e.toJson()).toList(),
    };
  }

  MembershipPlan copyWith({
    String? id,
    String? planCode,
    String? name,
    String? description,
    int? premiumCents,
    String? currency,
    int? maxDependents,
    bool? active,
    String? createdAt,
    String? oldId,
    List<MembershipPlanClaimPayout>? claimPayouts,
    List<MembershipPlanPremiumRule>? premiumRules,
  }) {
    return MembershipPlan(
      id: id ?? this.id,
      planCode: planCode ?? this.planCode,
      name: name ?? this.name,
      description: description ?? this.description,
      premiumCents: premiumCents ?? this.premiumCents,
      currency: currency ?? this.currency,
      maxDependents: maxDependents ?? this.maxDependents,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
      oldId: oldId ?? this.oldId,
      claimPayouts: claimPayouts ?? this.claimPayouts,
      premiumRules: premiumRules ?? this.premiumRules,
    );
  }
}

enum DependentType { ANY, MAIN_MEMBER, SPOUSE, CHILD, PARENT, EXTENDED_FAMILY, OTHER }

enum ClaimType { CASH, TOMBSTONE, FUNERAL, COMBINATION }

class MembershipPlanClaimPayout {
  final String? id;
  final String? planId;
  final String? planCode;
  final String? planName;
  final ClaimType claimType;
  final DependentType dependentType;
  final int payoutAmountCents;
  final bool active;

  MembershipPlanClaimPayout({
    this.id,
    this.planId,
    this.planCode,
    this.planName,
    required this.claimType,
    required this.dependentType,
    required this.payoutAmountCents,
    required this.active,
  });

  double get payoutAmount => payoutAmountCents / 100.0;

  factory MembershipPlanClaimPayout.fromJson(Map<String, dynamic> json) {
    String? pId = json['planId']?.toString();
    if (pId == null && json['plan'] is Map) {
      pId = json['plan']['id']?.toString();
    }

    return MembershipPlanClaimPayout(
      id: json['id']?.toString(),
      planId: pId,
      planCode: json['planCode']?.toString(),
      planName: json['planName']?.toString(),
      claimType: ClaimType.values.firstWhere((e) => e.name == json['claimType'], orElse: () => ClaimType.CASH),
      dependentType: DependentType.values.firstWhere((e) => e.name == json['dependentType'], orElse: () => DependentType.ANY),
      payoutAmountCents: json['payoutAmountCents'] is int ? json['payoutAmountCents'] : (int.tryParse(json['payoutAmountCents']?.toString() ?? '0') ?? 0),
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (planId != null) 'planId': planId,
      'claimType': claimType.name,
      'dependentType': dependentType.name,
      'payoutAmountCents': payoutAmountCents,
      'active': active,
    };
  }
}

class MembershipPlanPremiumRule {
  final String? id;
  final String? planId;
  final String? planName;
  final DependentType dependentType;
  final int minAge;
  final int maxAge;
  final int additionalPremiumCents;
  final bool active;

  MembershipPlanPremiumRule({
    this.id,
    this.planId,
    this.planName,
    required this.dependentType,
    required this.minAge,
    required this.maxAge,
    required this.additionalPremiumCents,
    required this.active,
  });

  double get additionalPremium => additionalPremiumCents / 100.0;

  factory MembershipPlanPremiumRule.fromJson(Map<String, dynamic> json) {
    String? pId = json['planId']?.toString();
    if (pId == null && json['plan'] is Map) {
      pId = json['plan']['id']?.toString();
    }

    return MembershipPlanPremiumRule(
      id: json['id']?.toString(),
      planId: pId,
      planName: json['planName']?.toString(),
      dependentType: DependentType.values.firstWhere((e) => e.name == json['dependentType'], orElse: () => DependentType.ANY),
      minAge: json['minAge'] is int ? json['minAge'] : (int.tryParse(json['minAge']?.toString() ?? '0') ?? 0),
      maxAge: json['maxAge'] is int ? json['maxAge'] : (int.tryParse(json['maxAge']?.toString() ?? '0') ?? 0),
      additionalPremiumCents: json['additionalPremiumCents'] is int ? json['additionalPremiumCents'] : (int.tryParse(json['additionalPremiumCents']?.toString() ?? '0') ?? 0),
      active: json['active'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (planId != null) 'planId': planId,
      'dependentType': dependentType.name,
      'minAge': minAge,
      'maxAge': maxAge,
      'additionalPremiumCents': additionalPremiumCents,
      'active': active,
    };
  }
}
