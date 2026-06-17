class InitiateClaimsRequestDto {
  final List<String> membershipIds;
  final List<String>? sourceReferences;

  InitiateClaimsRequestDto({
    required this.membershipIds,
    this.sourceReferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'membershipIds': membershipIds,
      if (sourceReferences != null) 'sourceReferences': sourceReferences,
    };
  }

  factory InitiateClaimsRequestDto.fromJson(Map<String, dynamic> json) {
    return InitiateClaimsRequestDto(
      membershipIds: (json['membershipIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sourceReferences: (json['sourceReferences'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
