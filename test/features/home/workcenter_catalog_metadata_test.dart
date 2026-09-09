import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/home/models/workcenter.dart';
import 'package:mawa_erp/features/approvals/models/approval.dart';

void main() {
  test('reads navigation and permission metadata from role workcenter response', () {
    final workcenter = Workcenter.fromJson({
      'position': 3,
      'workcenter': {
        'id': 'cashup',
        'description': 'Cashups',
        'routePath': '/cashups',
        'routeKey': 'cashup',
        'groupCode': 'finance-payments',
        'groupTitle': 'Finance & Payments',
        'sectionCode': 'BUSINESS_SERVICES',
        'sectionTitle': 'Business Services',
        'sectionDisplayOrder': 20,
        'groupDisplayOrder': 30,
        'displayOrder': 7,
        'permissionCode': 'cashup',
      },
    });

    expect(workcenter.routePath, '/cashups');
    expect(workcenter.groupCode, 'finance-payments');
    expect(workcenter.sectionCode, 'BUSINESS_SERVICES');
    expect(workcenter.groupDisplayOrder, 30);
    expect(workcenter.displayOrder, 7);
    expect(workcenter.permissionCode, 'cashup');
  });

  test('reads an assigned approval type used to generate an approval tile', () {
    final assignment = AssignedApprovalType.fromJson({
      'approvalType': 'MEMBERSHIP_TRANSFER',
      'label': 'MEMBERSHIP TRANSFER',
      'actionableCount': 2,
    });

    expect(assignment.approvalType, 'MEMBERSHIP_TRANSFER');
    expect(assignment.actionableCount, 2);
  });
}
