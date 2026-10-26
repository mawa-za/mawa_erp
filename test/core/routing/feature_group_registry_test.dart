import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/routing/feature_group_registry.dart';
import 'package:mawa_erp/core/routing/workcenter_route_registry.dart';

void main() {
  group('FeatureGroupRegistry canonical navigation', () {
    test('employment management belongs to People & Workplace', () {
      expect(
        FeatureGroupRegistry.canonicalOwnerForWorkcenter('employment-management'),
        'people-workplace',
      );
      expect(
        FeatureGroupRegistry.isStandaloneCard(
          'employment-management',
          'Employment Management',
        ),
        isFalse,
      );
    });

    test('leave management belongs to People & Workplace', () {
      expect(
        FeatureGroupRegistry.canonicalOwnerForWorkcenter('leave-management'),
        'people-workplace',
      );
      expect(
        FeatureGroupRegistry.isStandaloneCard('leave-management', 'Leave Management'),
        isFalse,
      );
    });

    test('asset register belongs to People & Workplace', () {
      expect(
        FeatureGroupRegistry.canonicalOwnerForWorkcenter('asset-register'),
        'people-workplace',
      );
      expect(
        FeatureGroupRegistry.isStandaloneCard('asset-register', 'Asset Management'),
        isFalse,
      );
    });

    test('ordinary employee workcenters remain grouped', () {
      expect(FeatureGroupRegistry.isStandaloneCard('employee', 'Employees'), isFalse);
    });

    test('Tombstone Operations remains a grouped home card', () {
      final group = FeatureGroupRegistry.groupById('tombstone-operations')!;
      expect(group.routePath, '/feature-groups/tombstone-operations');
      expect(group.childWorkcenterIds, hasLength(11));
      for (final id in group.childWorkcenterIds) {
        expect(FeatureGroupRegistry.isStandaloneCard(id), isFalse,
            reason: '$id should appear inside Tombstone Operations');
        expect(FeatureGroupRegistry.canonicalOwnerForWorkcenter(id),
            'tombstone-operations');
      }
      expect(FeatureGroupRegistry.isStandaloneCard('tombstone-management'), isFalse);
    });

    test('Tombstone Operations cards resolve to separate routes', () {
      final expected = <String, String>{
        'tombstone-installation-requests': '/tombstones/installation-requests',
        'tombstone-orders': '/tombstones/orders',
        'tombstone-laybys': '/tombstones/laybys',
        'tombstone-site-assessments': '/tombstones/site-assessments',
        'tombstone-design-approvals': '/tombstones/designs',
        'tombstone-production-jobs': '/tombstones/production',
        'tombstone-installation-planning': '/tombstones/installations',
        'tombstone-installation-calendar': '/tombstones/calendar',
        'tombstone-installation-teams': '/tombstones/teams',
        'tombstone-rework-jobs': '/tombstones/rework',
        'tombstone-reports': '/tombstones/reports',
      };
      for (final entry in expected.entries) {
        expect(WorkcenterRouteRegistry.getRoutePath(entry.key), entry.value);
      }
    });

    test('tombstone installation requests belong to Tombstone Operations', () {
      expect(
        FeatureGroupRegistry.groupForWorkcenter('tombstone-installation-requests')?.id,
        'tombstone-operations',
      );
    });
  });
}
