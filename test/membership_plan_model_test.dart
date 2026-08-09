import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/membership/models/membership_plan.dart';

void main() {
  group('Membership plan claim benefits', () {
    test('includes Grocery as a configurable benefit type', () {
      expect(ClaimType.values, contains(ClaimType.GROCERY));
    });

    test('deserialises a Grocery plan benefit without falling back to Cash', () {
      final payout = MembershipPlanClaimPayout.fromJson({
        'id': 'benefit-1',
        'planId': 'plan-1',
        'claimType': 'GROCERY',
        'dependentType': 'ANY',
        'payoutAmountCents': 50000,
        'active': true,
      });

      expect(payout.claimType, ClaimType.GROCERY);
      expect(payout.payoutAmountCents, 50000);
    });
  });
}
