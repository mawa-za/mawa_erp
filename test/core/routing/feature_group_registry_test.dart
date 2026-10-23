import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/routing/feature_group_registry.dart';

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

    test('tombstone installation requests belong to Tombstone Operations', () {
      expect(
        FeatureGroupRegistry.groupForWorkcenter('tombstone-installation-requests')?.id,
        'tombstone-operations',
      );
    });
  });
}
