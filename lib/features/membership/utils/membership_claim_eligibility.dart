import '../models/membership_claim.dart';

/// Returns whether a claim can be started for [deceasedPartnerId] on the
/// currently viewed membership.
///
/// A partner can legitimately be DECEASED globally after a claim was created
/// on another membership. Claim eligibility must therefore be scoped to the
/// current membership, not to the partner's global status.
bool canProcessMembershipClaim({
  required String currentMembershipId,
  required String deceasedPartnerId,
  required Iterable<MembershipClaim> claims,
  bool deceasedOnCurrentMembership = false,
}) {
  if (deceasedOnCurrentMembership) {
    return false;
  }

  return !claims.any(
    (claim) =>
        claim.membershipId == currentMembershipId &&
        claim.deceasedPartnerId == deceasedPartnerId,
  );
}
