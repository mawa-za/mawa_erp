import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/settings/models/role_permission.dart';

void main() {
  test('business action permission metadata is separate from workcentre routing', () {
    final permission = RolePermission.fromJson({
      'code': 'premium-payment-cancel',
      'description': 'Cancel premium payments',
      'details': 'Request payment cancellation',
      'groupTitle': 'Memberships / Premiums & Payments',
      'displayOrder': 30,
      'sensitive': true,
    });
    expect(permission.code, 'premium-payment-cancel');
    expect(permission.groupTitle, 'Memberships / Premiums & Payments');
    expect(permission.sensitive, isTrue);
  });
}
