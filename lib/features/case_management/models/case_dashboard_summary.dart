class CaseDashboardSummary {
  final int totalOpenCases;
  final int totalInProgressCases;
  final int totalClosedCases;
  final int overdueTasks;
  final int upcomingEvents;
  final int unbilledAmountCents;
  final int totalBalanceCents;

  CaseDashboardSummary({
    this.totalOpenCases = 0,
    this.totalInProgressCases = 0,
    this.totalClosedCases = 0,
    this.overdueTasks = 0,
    this.upcomingEvents = 0,
    this.unbilledAmountCents = 0,
    this.totalBalanceCents = 0,
  });

  factory CaseDashboardSummary.fromJson(Map<String, dynamic> json) {
    return CaseDashboardSummary(
      totalOpenCases: (json['totalOpenCases'] as num?)?.toInt() ?? 0,
      totalInProgressCases: (json['totalInProgressCases'] as num?)?.toInt() ?? 0,
      totalClosedCases: (json['totalClosedCases'] as num?)?.toInt() ?? 0,
      overdueTasks: (json['overdueTasks'] as num?)?.toInt() ?? 0,
      upcomingEvents: (json['upcomingEvents'] as num?)?.toInt() ?? 0,
      unbilledAmountCents: (json['unbilledAmountCents'] as num?)?.toInt() ?? 0,
      totalBalanceCents: (json['totalBalanceCents'] as num?)?.toInt() ?? 0,
    );
  }
}
