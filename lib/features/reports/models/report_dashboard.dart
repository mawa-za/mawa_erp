class MembershipSummary {
  final int total;
  final int active;
  final int suspended;
  final int lapsed;
  final int cancelled;
  final int deceased;
  final int other;

  const MembershipSummary({required this.total, required this.active, required this.suspended,
    required this.lapsed, required this.cancelled, required this.deceased, required this.other});

  factory MembershipSummary.fromJson(Map<String, dynamic> json) => MembershipSummary(
    total: _int(json['total']), active: _int(json['active']), suspended: _int(json['suspended']),
    lapsed: _int(json['lapsed']), cancelled: _int(json['cancelled']), deceased: _int(json['deceased']),
    other: _int(json['other']),
  );
}

class MembershipPlanCount {
  final String planId;
  final String planCode;
  final String planName;
  final bool activePlan;
  final int membershipCount;
  final int activeMembershipCount;

  const MembershipPlanCount({required this.planId, required this.planCode, required this.planName,
    required this.activePlan, required this.membershipCount, required this.activeMembershipCount});

  factory MembershipPlanCount.fromJson(Map<String, dynamic> json) => MembershipPlanCount(
    planId: '${json['planId'] ?? ''}', planCode: '${json['planCode'] ?? ''}',
    planName: '${json['planName'] ?? ''}', activePlan: json['activePlan'] == true,
    membershipCount: _int(json['membershipCount']), activeMembershipCount: _int(json['activeMembershipCount']),
  );
}

class PremiumPeriod {
  final String period;
  final String label;
  final int paidCount;
  final int unpaidCount;
  final int partiallyPaidCount;
  final int outstandingCount;
  final int excludedCount;
  final int paidAmountCents;
  final int outstandingAmountCents;

  const PremiumPeriod({required this.period, required this.label, required this.paidCount,
    required this.unpaidCount, required this.partiallyPaidCount, required this.outstandingCount,
    required this.excludedCount, required this.paidAmountCents, required this.outstandingAmountCents});

  factory PremiumPeriod.fromJson(Map<String, dynamic> json) => PremiumPeriod(
    period: '${json['period'] ?? ''}', label: '${json['label'] ?? ''}', paidCount: _int(json['paidCount']),
    unpaidCount: _int(json['unpaidCount']), partiallyPaidCount: _int(json['partiallyPaidCount']),
    outstandingCount: _int(json['outstandingCount']), excludedCount: _int(json['excludedCount']),
    paidAmountCents: _int(json['paidAmountCents']), outstandingAmountCents: _int(json['outstandingAmountCents']),
  );
}

class ClaimMonth {
  final String month;
  final String label;
  final int totalCount;
  final Map<String, int> byType;

  const ClaimMonth({required this.month, required this.label, required this.totalCount, required this.byType});

  factory ClaimMonth.fromJson(Map<String, dynamic> json) {
    final raw = json['byType'];
    final byType = <String, int>{};
    if (raw is Map) {
      raw.forEach((key, value) => byType['$key'] = _int(value));
    }
    return ClaimMonth(month: '${json['month'] ?? ''}', label: '${json['label'] ?? ''}',
      totalCount: _int(json['totalCount']), byType: byType);
  }
}

class ReportDashboard {
  final String tenantId;
  final DateTime generatedAt;
  final String currency;
  final int premiumPeriods;
  final int claimMonths;
  final MembershipSummary membershipSummary;
  final List<MembershipPlanCount> membershipsByPlan;
  final List<PremiumPeriod> premiumsByPeriod;
  final List<ClaimMonth> claimsByMonth;

  const ReportDashboard({required this.tenantId, required this.generatedAt, required this.currency,
    required this.premiumPeriods, required this.claimMonths, required this.membershipSummary,
    required this.membershipsByPlan, required this.premiumsByPeriod, required this.claimsByMonth});

  factory ReportDashboard.fromJson(Map<String, dynamic> json) => ReportDashboard(
    tenantId: '${json['tenantId'] ?? ''}',
    generatedAt: DateTime.tryParse('${json['generatedAt'] ?? ''}') ?? DateTime.now(),
    currency: '${json['currency'] ?? 'ZAR'}', premiumPeriods: _int(json['premiumPeriods']),
    claimMonths: _int(json['claimMonths']),
    membershipSummary: MembershipSummary.fromJson(Map<String, dynamic>.from(json['membershipSummary'] as Map? ?? {})),
    membershipsByPlan: (json['membershipsByPlan'] as List? ?? const [])
      .map((e) => MembershipPlanCount.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    premiumsByPeriod: (json['premiumsByPeriod'] as List? ?? const [])
      .map((e) => PremiumPeriod.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    claimsByMonth: (json['claimsByMonth'] as List? ?? const [])
      .map((e) => ClaimMonth.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );
}

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
