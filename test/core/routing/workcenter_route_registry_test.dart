import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/routing/workcenter_route_registry.dart';

void main() {
  group('new management report routes', () {
    const expected = <String, String>{
      'management-new-memberships-per-month-report':
          '/reports?report=new-memberships-per-month',
      'management-approval-requests-per-month-report':
          '/reports?report=approval-requests-per-month',
      'management-funeral-services-per-month-report':
          '/reports?report=funeral-services-per-month',
      'management-group-societies-total-report':
          '/reports?report=group-societies-total',
      'management-group-society-balances-report':
          '/reports?report=group-society-balances',
      'management-consolidated-customer-balances-report':
          '/reports?report=consolidated-customer-balances',
    };

    for (final entry in expected.entries) {
      test('${entry.key} opens its selected report', () {
        expect(
          WorkcenterRouteRegistry.getRoutePath(entry.key),
          entry.value,
        );
      });
    }
  });
}
