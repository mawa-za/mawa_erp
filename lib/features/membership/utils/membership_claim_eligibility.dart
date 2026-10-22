import '../models/membership_claim.dart';

/// A deceased partner is claimable again on the SAME membership only after
/// all earlier claims for that membership and deceased partner were cancelled.
/// Never use the partner's global status to decide eligibility.
bool canProcessMembershipClaim({
  required String currentMembershipId,
  required String deceasedPartnerId,
  required Iterable<MembershipClaim> claims,
  bool deceasedOnCurrentMembership = false,
}) {
  final previousClaims = claims.where((claim) =>
      claim.membershipId == currentMembershipId &&
      claim.deceasedPartnerId == deceasedPartnerId);
  if (previousClaims.any((claim) => claim.status.trim().toUpperCase() != 'CANCELLED')) {
    return false;
  }
  if (deceasedOnCurrentMembership && previousClaims.isEmpty) {
    return false;
  }
  return true;
}
