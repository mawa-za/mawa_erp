class CaseParty {
  final String id;
  final String caseId;
  final String? partnerId;
  final String partyName;
  final String partyType;
  final String? idNumber;
  final String? email;
  final String? phoneNumber;
  final String? attorneyFirm;
  final String? attorneyName;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  CaseParty({
    required this.id,
    required this.caseId,
    this.partnerId,
    required this.partyName,
    required this.partyType,
    this.idNumber,
    this.email,
    this.phoneNumber,
    this.attorneyFirm,
    this.attorneyName,
    this.notes,
    this.createdAt,
    this.createdBy,
  });

  factory CaseParty.fromJson(Map<String, dynamic> json) {
    return CaseParty(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      partnerId: json['partnerId']?.toString(),
      partyName: (json['partyName'] ?? '').toString(),
      partyType: (json['partyType'] ?? 'OTHER').toString(),
      idNumber: json['idNumber']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      attorneyFirm: json['attorneyFirm']?.toString(),
      attorneyName: json['attorneyName']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'partnerId': partnerId,
      'partyName': partyName,
      'partyType': partyType,
      'idNumber': idNumber,
      'email': email,
      'phoneNumber': phoneNumber,
      'attorneyFirm': attorneyFirm,
      'attorneyName': attorneyName,
      'notes': notes,
    };
  }
}

class CreateCasePartyRequest {
  final String? partnerId;
  final String partyName;
  final String partyType;
  final String? idNumber;
  final String? email;
  final String? phoneNumber;
  final String? attorneyFirm;
  final String? attorneyName;
  final String? notes;

  CreateCasePartyRequest({
    this.partnerId,
    required this.partyName,
    required this.partyType,
    this.idNumber,
    this.email,
    this.phoneNumber,
    this.attorneyFirm,
    this.attorneyName,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'partnerId': partnerId,
      'partyName': partyName,
      'partyType': partyType,
      'idNumber': idNumber,
      'email': email,
      'phoneNumber': phoneNumber,
      'attorneyFirm': attorneyFirm,
      'attorneyName': attorneyName,
      'notes': notes,
    };
  }
}
