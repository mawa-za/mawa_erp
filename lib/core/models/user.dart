import '../../features/partners/models/partner.dart';

class User {
  final String id;
  final String username;
  final String? displayName;
  final String? email;
  final String? cellphone;
  final String timeZone;
  final String type;
  final String status;
  final Partner? partner;
  final String? passwordStatus;
  final String? validFrom;
  final String? validTo;
  final String statusReason;
  final String accountType;
  final bool testUser;
  final bool protectedUser;
  final bool systemManaged;
  final String accessScope;
  final String environmentScope;
  final bool externalTransactionsBlocked;
  final DateTime? expiresAt;
  final String protectedReason;
  final bool mfaRequired;

  const User({
    required this.id,
    required this.username,
    this.displayName,
    this.email,
    this.cellphone,
    this.timeZone = 'Africa/Harare',
    required this.type,
    required this.status,
    this.partner,
    this.passwordStatus,
    this.validFrom,
    this.validTo,
    this.statusReason = '',
    this.accountType = 'STANDARD',
    this.testUser = false,
    this.protectedUser = false,
    this.systemManaged = false,
    this.accessScope = 'STANDARD',
    this.environmentScope = '',
    this.externalTransactionsBlocked = false,
    this.expiresAt,
    this.protectedReason = '',
    this.mfaRequired = false,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] ?? '').toString(),
        username: (json['username'] ?? '').toString(),
        displayName: json['displayName']?.toString(),
        email: json['email']?.toString(),
        cellphone: json['cellphone']?.toString(),
        timeZone: (json['timeZone'] ?? 'Africa/Harare').toString(),
        type: (json['type'] ?? json['userType'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        partner: json['partner'] != null && json['partner'] is Map
            ? Partner.fromJson(Map<String, dynamic>.from(json['partner']))
            : null,
        passwordStatus: json['passwordStatus']?.toString(),
        validFrom: json['validFrom']?.toString(),
        validTo: json['validTo']?.toString(),
        statusReason: (json['statusReason'] ?? '').toString(),
        accountType: (json['accountType'] ?? 'STANDARD').toString(),
        testUser: json['testUser'] == true,
        protectedUser: json['protectedUser'] == true,
        systemManaged: json['systemManaged'] == true,
        accessScope: (json['accessScope'] ?? 'STANDARD').toString(),
        environmentScope: (json['environmentScope'] ?? '').toString(),
        externalTransactionsBlocked:
            json['externalTransactionsBlocked'] == true,
        expiresAt: json['expiresAt'] == null
            ? null
            : DateTime.tryParse(json['expiresAt'].toString()),
        protectedReason: (json['protectedReason'] ?? '').toString(),
        mfaRequired: json['mfaRequired'] == true,
      );

  Map<String, dynamic> toEditJson() => {
        'cellphone': cellphone,
        'email': email,
        'timeZone': timeZone,
        'userType': type,
        'status': status,
        'statusReason': statusReason,
        'accountType': accountType,
        'testUser': testUser,
        'protectedUser': protectedUser,
        'systemManaged': systemManaged,
        'accessScope': accessScope,
        'environmentScope': environmentScope,
        'externalTransactionsBlocked': externalTransactionsBlocked,
        'expiresAt': expiresAt?.toIso8601String(),
        'protectedReason': protectedReason,
        'mfaRequired': mfaRequired,
      };
}
