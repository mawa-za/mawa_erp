import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/routing/feature_group_registry.dart';

void main() {
  group('central approval workspace', () {
    test('all approval types resolve to the Approvals group', () {
      expect(FeatureGroupRegistry.approvalGroup('CLAIM'), 'approvals');
      expect(
        FeatureGroupRegistry.approvalGroup('SUPPLIER_BANKING_DETAILS'),
        'approvals',
      );
      expect(FeatureGroupRegistry.approvalGroup('LEAVE'), 'approvals');
      expect(FeatureGroupRegistry.approvalGroup('CUSTOM_TYPE'), 'approvals');
    });

    test('Approvals owns the generic approval workcenter', () {
      final approvals = FeatureGroupRegistry.groupById('approvals');
      final workManagement = FeatureGroupRegistry.groupById('work-management');

      expect(approvals, isNotNull);
      expect(approvals!.matches('approvals'), isTrue);
      expect(workManagement, isNotNull);
      expect(workManagement!.matches('approvals'), isFalse);
    });
  });
}
