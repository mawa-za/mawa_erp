import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/reports/models/report_dashboard.dart';

void main() {
  test('parses reporting dashboard payload', () {
    final dashboard = ReportDashboard.fromJson({
      'tenantId': 'mawa',
      'generatedAt': '2026-07-18T10:00:00Z',
      'currency': 'ZAR',
      'premiumPeriods': 6,
      'claimMonths': 6,
      'membershipSummary': {'total': 10, 'active': 8, 'suspended': 1, 'lapsed': 1},
      'membershipsByPlan': [
        {'planId': 'p1', 'planCode': 'FAMILY', 'planName': 'Family', 'activePlan': true, 'membershipCount': 10, 'activeMembershipCount': 8},
      ],
      'premiumsByPeriod': [
        {'period': '202607', 'label': 'Jul 2026', 'paidCount': 7, 'unpaidCount': 2, 'partiallyPaidCount': 1, 'outstandingCount': 3},
      ],
      'claimsByMonth': [
        {'month': '202607', 'label': 'Jul 2026', 'totalCount': 2, 'byType': {'FUNERAL': 1, 'GROCERY': 1}},
      ],
    });

    expect(dashboard.membershipSummary.total, 10);
    expect(dashboard.membershipsByPlan.single.planCode, 'FAMILY');
    expect(dashboard.premiumsByPeriod.single.outstandingCount, 3);
    expect(dashboard.claimsByMonth.single.byType['GROCERY'], 1);
  });
}
