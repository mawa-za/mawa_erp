import '../models/membership_claim.dart';

/// A new claim is blocked only when an earlier claim has actually been approved
/// for the same deceased person on the current membership. The approval timestamp
/// remains populated when a claim later moves into payment processing/paid status.
/// Draft, submitted, rejected and cancelled attempts may be resubmitted.
bool canProcessMembershipClaim({
  required String currentMembershipId,
  required String deceasedPartnerId,
  required Iterable<MembershipClaim> claims,
  bool deceasedOnCurrentMembership = false,
}) {
  const approvedOrLaterStatuses = {
    'APPROVED',
    'PAYMENT_PENDING',
    'PAYMENT_PROCESSING',
    'PAYMENT_FAILED',
    'PAID',
  };
  return !claims.any((claim) {
    if (claim.membershipId != currentMembershipId ||
        claim.deceasedPartnerId != deceasedPartnerId) {
      return false;
    }
    final hasApprovalTimestamp =
        claim.approvedAt != null && claim.approvedAt!.trim().isNotEmpty;
    return hasApprovalTimestamp ||
        approvedOrLaterStatuses.contains(claim.status.trim().toUpperCase());
  });
}
