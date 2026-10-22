import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/membership/models/membership_claim.dart';
import 'package:mawa_erp/features/membership/utils/membership_claim_eligibility.dart';

MembershipClaim _claim({
  required String membershipId,
  required String deceasedPartnerId,
  String status = 'SUBMITTED',
}) {
  return MembershipClaim.fromJson({
    'membershipId': membershipId,
    'deceasedPartnerId': deceasedPartnerId,
    'status': status,
  });
}

void main() {
  group('canProcessMembershipClaim', () {
    test('allows a globally deceased partner to claim on another membership', () {
      final claims = [
        _claim(membershipId: 'MEMBERSHIP-A', deceasedPartnerId: 'PARTNER-1'),
      ];

      expect(
        canProcessMembershipClaim(
          currentMembershipId: 'MEMBERSHIP-B',
          deceasedPartnerId: 'PARTNER-1',
          claims: claims,
        ),
        isTrue,
      );
    });

    test('blocks a second claim for the same partner on the current membership', () {
      final claims = [
        _claim(membershipId: 'MEMBERSHIP-B', deceasedPartnerId: 'PARTNER-1'),
      ];

      expect(
        canProcessMembershipClaim(
          currentMembershipId: 'MEMBERSHIP-B',
          deceasedPartnerId: 'PARTNER-1',
          claims: claims,
        ),
        isFalse,
      );
    });

    test('permits a new claim after the previous claim is cancelled', () {
      expect(
        canProcessMembershipClaim(
          currentMembershipId: 'MEMBERSHIP-B',
          deceasedPartnerId: 'PARTNER-1',
          claims: [_claim(membershipId: 'MEMBERSHIP-B', deceasedPartnerId: 'PARTNER-1', status: 'CANCELLED')],
          deceasedOnCurrentMembership: true,
        ),
        isTrue,
      );
    });

    test('blocks draft, rejected and submitted claims until cancellation', () {
      for (final status in ['DRAFT', 'REJECTED', 'SUBMITTED', 'PAID']) {
        expect(
          canProcessMembershipClaim(
            currentMembershipId: 'MEMBERSHIP-B',
            deceasedPartnerId: 'PARTNER-1',
            claims: [_claim(membershipId: 'MEMBERSHIP-B', deceasedPartnerId: 'PARTNER-1', status: status)],
          ),
          isFalse,
          reason: status,
        );
      }
    });

    test('blocks a dependent already deceased on the current membership', () {
      expect(
        canProcessMembershipClaim(
          currentMembershipId: 'MEMBERSHIP-B',
          deceasedPartnerId: 'PARTNER-1',
          claims: const [],
          deceasedOnCurrentMembership: true,
        ),
        isFalse,
      );
    });
  });
}
