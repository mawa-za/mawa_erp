import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/routing/feature_group_registry.dart';

void main() {
  group('FeatureGroupRegistry standalone cards', () {
    test('employment management remains a standalone card', () {
      expect(
        FeatureGroupRegistry.isStandaloneCard(
          'employment-management',
          'Employment Management',
        ),
        isTrue,
      );
    });

    test('leave management remains a standalone card', () {
      expect(
        FeatureGroupRegistry.isStandaloneCard(
          'leave-management',
          'Leave Management',
        ),
        isTrue,
      );
    });

    test('asset register is presented as Asset Management standalone', () {
      expect(
        FeatureGroupRegistry.isStandaloneCard(
          'asset-register',
          'Asset Management',
        ),
        isTrue,
      );
    });

    test('ordinary partner workcenters remain grouped', () {
      expect(
        FeatureGroupRegistry.isStandaloneCard('employee', 'Employees'),
        isFalse,
      );
    });
  });
}
