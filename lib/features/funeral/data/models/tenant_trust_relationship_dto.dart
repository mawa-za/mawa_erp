class TenantTrustRelationshipDto {
  final String? id;
  final String? requesterTenantId;
  final String? requesterTenantName;
  final String? providerTenantId;
  final String? providerTenantName;
  final String status;
  final bool membershipLookupAllowed;
  final bool claimCreationAllowed;
  final bool claimStatusReadAllowed;
  final bool settlementAllowed;

  const TenantTrustRelationshipDto({this.id, this.requesterTenantId, this.requesterTenantName, this.providerTenantId, this.providerTenantName, this.status='PENDING', this.membershipLookupAllowed=true, this.claimCreationAllowed=true, this.claimStatusReadAllowed=true, this.settlementAllowed=false});
  factory TenantTrustRelationshipDto.fromJson(Map<String,dynamic> j)=>TenantTrustRelationshipDto(id:j['id']?.toString(), requesterTenantId:j['requesterTenantId']?.toString(), requesterTenantName:j['requesterTenantName']?.toString(), providerTenantId:j['providerTenantId']?.toString(), providerTenantName:j['providerTenantName']?.toString(), status:j['status']?.toString()??'PENDING', membershipLookupAllowed:j['membershipLookupAllowed']!=false, claimCreationAllowed:j['claimCreationAllowed']!=false, claimStatusReadAllowed:j['claimStatusReadAllowed']!=false, settlementAllowed:j['settlementAllowed']==true);
  Map<String,dynamic> toJson()=>{'providerTenantId':providerTenantId,'membershipLookupAllowed':membershipLookupAllowed,'claimCreationAllowed':claimCreationAllowed,'claimStatusReadAllowed':claimStatusReadAllowed,'settlementAllowed':settlementAllowed};
}
