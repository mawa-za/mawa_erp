class InitiateFuneralClaimsRequestDto {
  /// Stable selection ids returned by GET /v2/funeral/check-membership/{identityNumber}.
  ///
  /// Backend expects `memberships`; older Flutter builds used `membershipIds` and
  /// `sourceReferences`, so we still send those aliases for compatibility.
  final List<String> memberships;
  final List<String>? sourceReferences;
  final String claimType;

  InitiateFuneralClaimsRequestDto({
    required List<String> membershipIds,
    String? claimType,
    this.sourceReferences,
  })  : memberships = membershipIds,
        claimType = (claimType == null || claimType.trim().isEmpty)
            ? (membershipIds.length > 1 ? 'COMBINATION' : 'FUNERAL')
            : claimType.trim().toUpperCase();

  Map<String, dynamic> toJson() {
    return {
      'memberships': memberships,
      'membershipIds': memberships,
      'claimType': claimType,
      if (sourceReferences != null && sourceReferences!.isNotEmpty) 'sourceReferences': sourceReferences,
    };
  }

  factory InitiateFuneralClaimsRequestDto.fromJson(Map<String, dynamic> json) {
    final membershipValues = json['memberships'] ?? json['membershipIds'];
    final memberships = (membershipValues as List?)?.map((e) => e.toString()).toList() ?? [];
    return InitiateFuneralClaimsRequestDto(
      membershipIds: memberships,
      claimType: json['claimType']?.toString(),
      sourceReferences: (json['sourceReferences'] as List?)?.map((e) => e.toString()).toList(),
    );
  }
}
