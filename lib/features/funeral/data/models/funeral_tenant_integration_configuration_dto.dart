class FuneralTenantIntegrationConfigurationDto {
  final String membershipSourceMode;
  final String? externalTenantId;
  final String? externalTenantName;
  final String? externalTenantPartnerId;
  final bool membershipLookupEnabled;
  final bool claimCreationEnabled;
  final bool claimStatusSyncEnabled;
  final bool active;

  const FuneralTenantIntegrationConfigurationDto({
    this.membershipSourceMode = 'LOCAL_ONLY',
    this.externalTenantId,
    this.externalTenantName,
    this.externalTenantPartnerId,
    this.membershipLookupEnabled = true,
    this.claimCreationEnabled = true,
    this.claimStatusSyncEnabled = true,
    this.active = true,
  });

  bool get usesExternalTenant =>
      membershipSourceMode == 'EXTERNAL_ONLY' ||
      membershipSourceMode == 'LOCAL_AND_EXTERNAL';

  Map<String, dynamic> toJson() => {
        'membershipSourceMode': membershipSourceMode,
        'externalTenantId': externalTenantId,
        'externalTenantName': externalTenantName,
        'externalTenantPartnerId': externalTenantPartnerId,
        'membershipLookupEnabled': membershipLookupEnabled,
        'claimCreationEnabled': claimCreationEnabled,
        'claimStatusSyncEnabled': claimStatusSyncEnabled,
        'active': active,
      };

  factory FuneralTenantIntegrationConfigurationDto.fromJson(
    Map<String, dynamic> json,
  ) {
    return FuneralTenantIntegrationConfigurationDto(
      membershipSourceMode:
          json['membershipSourceMode']?.toString() ?? 'LOCAL_ONLY',
      externalTenantId: json['externalTenantId']?.toString(),
      externalTenantName: json['externalTenantName']?.toString(),
      externalTenantPartnerId:
          json['externalTenantPartnerId']?.toString(),
      membershipLookupEnabled:
          json['membershipLookupEnabled'] as bool? ?? true,
      claimCreationEnabled: json['claimCreationEnabled'] as bool? ?? true,
      claimStatusSyncEnabled:
          json['claimStatusSyncEnabled'] as bool? ?? true,
      active: json['active'] as bool? ?? true,
    );
  }
}
