class InitiateFuneralClaimsRequestDto {
  final List<String> membershipIds;
  final List<String>? sourceReferences;
  final String? claimType;
  final String? groceryCoverSelectionId;
  InitiateFuneralClaimsRequestDto({required this.membershipIds,this.sourceReferences,this.claimType,this.groceryCoverSelectionId});
  Map<String,dynamic> toJson()=>{'membershipIds':membershipIds,if(sourceReferences!=null)'sourceReferences':sourceReferences,if(claimType!=null)'claimType':claimType,if(groceryCoverSelectionId!=null)'groceryCoverSelectionId':groceryCoverSelectionId};
  factory InitiateFuneralClaimsRequestDto.fromJson(Map<String,dynamic> json)=>InitiateFuneralClaimsRequestDto(membershipIds:(json['membershipIds'] as List?)?.map((e)=>e.toString()).toList()??[],sourceReferences:(json['sourceReferences'] as List?)?.map((e)=>e.toString()).toList(),claimType:json['claimType']?.toString(),groceryCoverSelectionId:json['groceryCoverSelectionId']?.toString());
}
