class InitiateFuneralClaimsRequestDto {
  final List<String> membershipIds;
  final List<String>? sourceReferences;

  InitiateFuneralClaimsRequestDto({
    required this.membershipIds,
    this.sourceReferences,
  });

  Map<String, dynamic> toJson() {
    return {
      'membershipIds': membershipIds,
      if (sourceReferences != null) 'sourceReferences': sourceReferences,
    };
  }

  factory InitiateFuneralClaimsRequestDto.fromJson(Map<String, dynamic> json) {
    return InitiateFuneralClaimsRequestDto(
      membershipIds: (json['membershipIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      sourceReferences: (json['sourceReferences'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
