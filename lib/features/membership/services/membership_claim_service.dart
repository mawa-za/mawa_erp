import '../models/membership_claim.dart';
import 'membership_service.dart';

class MembershipClaimService {
  static final MembershipClaimService _instance = MembershipClaimService._internal();
  factory MembershipClaimService() => _instance;
  MembershipClaimService._internal();

  final MembershipService _membershipService = MembershipService();

  Future<Map<String, dynamic>> createClaim(Map<String, dynamic> payload) =>
      _membershipService.createMembershipClaim(payload);

  Future<List<MembershipClaim>> getClaims({String? membershipId}) =>
      _membershipService.getMembershipClaims(membershipId: membershipId);

  Future<MembershipClaim> getClaimById(String id) => _membershipService.getMembershipClaimById(id);

  Future<MembershipClaim> getClaimByClaimNo(String claimNo) =>
      _membershipService.getMembershipClaimByClaimNo(claimNo);

  Future<List<MembershipClaim>> getClaimsByMembership(String membershipId) =>
      _membershipService.getClaimsByMembership(membershipId);

  Future<List<MembershipClaim>> getClaimsByType(String claimType) =>
      _membershipService.getClaimsByType(claimType);

  Future<List<MembershipClaim>> getClaimsByStatus(String status) =>
      _membershipService.getClaimsByStatus(status);

  Future<List<MembershipClaim>> getClaimsByDeceasedPartner(String deceasedPartnerId) =>
      _membershipService.getClaimsByDeceasedPartner(deceasedPartnerId);

  Future<void> updateClaim(String id, Map<String, dynamic> payload) =>
      _membershipService.updateMembershipClaim(id, payload);

  Future<void> submitClaim(String id) => _membershipService.submitMembershipClaim(id);

  Future<void> cancelClaim(String id) => _membershipService.cancelMembershipClaim(id);

  Future<void> attachClaims(String parentClaimId, List<String> claimIds) =>
      _membershipService.linkClaims(parentClaimId, claimIds);

  Future<void> detachClaim(String parentClaimId, String linkedClaimId) =>
      _membershipService.detachClaim(parentClaimId, linkedClaimId);
}
