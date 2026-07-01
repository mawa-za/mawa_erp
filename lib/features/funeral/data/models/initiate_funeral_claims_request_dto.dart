class InitiateFuneralClaimsRequestDto {
  /// Stable selection ids returned by GET /v2/funeral/check-membership/{identityNumber}.
  ///
  /// Backend expects `memberships`; older Flutter builds used `membershipIds` and
  /// `sourceReferences`, so we still send those aliases for compatibility.
  final List<String> memberships;
  final List<String>? sourceReferences;

  InitiateFuneralClaimsRequestDto({
    required List<String> membershipIds,
    this.sourceReferences,
  }) : memberships = membershipIds;

  Map<String, dynamic> toJson() {
    return {
      'memberships': memberships,
      'membershipIds': memberships,
      if (sourceReferences != null && sourceReferences!.isNotEmpty) 'sourceReferences': sourceReferences,
    };
  }

  factory InitiateFuneralClaimsRequestDto.fromJson(Map<String, dynamic> json) {
    final membershipValues = json['memberships'] ?? json['membershipIds'];
    return InitiateFuneralClaimsRequestDto(
      membershipIds: (membershipValues as List?)?.map((e) => e.toString()).toList() ?? [],
      sourceReferences: (json['sourceReferences'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
