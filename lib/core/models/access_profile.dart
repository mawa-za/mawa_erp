class AccessProfile {
  final String userId;
  final String username;
  final String displayName;
  final String accountType;
  final bool testUser;
  final bool protectedUser;
  final bool systemManaged;
  final String accessScope;
  final String environmentScope;
  final bool externalTransactionsBlocked;
  final DateTime? expiresAt;
  final bool mfaRequired;
  final bool platformSession;
  final String platformUserId;
  final String handoffId;
  final String accessReason;
  final String ticketReference;
  final String tenantId;
  final List<String> roles;
  final bool allWorkcentres;

  const AccessProfile({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.accountType,
    required this.testUser,
    required this.protectedUser,
    required this.systemManaged,
    required this.accessScope,
    required this.environmentScope,
    required this.externalTransactionsBlocked,
    this.expiresAt,
    required this.mfaRequired,
    required this.platformSession,
    required this.platformUserId,
    required this.handoffId,
    required this.accessReason,
    required this.ticketReference,
    required this.tenantId,
    required this.roles,
    required this.allWorkcentres,
  });

  factory AccessProfile.fromJson(Map<String, dynamic> json) => AccessProfile(
        userId: (json['userId'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: (json['displayName'] ?? json['username'] ?? '').toString(),
        accountType: (json['accountType'] ?? 'STANDARD').toString(),
        testUser: json['testUser'] == true,
        protectedUser: json['protectedUser'] == true,
        systemManaged: json['systemManaged'] == true,
        accessScope: (json['accessScope'] ?? 'STANDARD').toString(),
        environmentScope: (json['environmentScope'] ?? '').toString(),
        externalTransactionsBlocked: json['externalTransactionsBlocked'] == true,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.tryParse(json['expiresAt'].toString()),
        mfaRequired: json['mfaRequired'] == true,
        platformSession: json['platformSession'] == true,
        platformUserId: (json['platformUserId'] ?? '').toString(),
        handoffId: (json['handoffId'] ?? '').toString(),
        accessReason: (json['accessReason'] ?? '').toString(),
        ticketReference: (json['ticketReference'] ?? '').toString(),
        tenantId: (json['tenantId'] ?? '').toString(),
        roles: (json['roles'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        allWorkcentres: json['allWorkcentres'] == true,
      );
}
