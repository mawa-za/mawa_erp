class Membership {
  final String transactionId;
  final String transactionType;
  final String transactionSubtype;
  final String transactionNumber;
  final String? identityType;
  final String? identityNumber;
  final String mainPartner;
  final String employeeResponsible;
  final String? recipient;
  final String createdBy;
  final String? changedBy;
  final String? product;
  final String creationDate;
  final String transactionStatus;
  final String? claimant;
  final String? dateEffective;
  final String? productId;

  Membership({
    required this.transactionId,
    required this.transactionType,
    required this.transactionSubtype,
    required this.transactionNumber,
    this.identityType,
    this.identityNumber,
    required this.mainPartner,
    required this.employeeResponsible,
    this.recipient,
    required this.createdBy,
    this.changedBy,
    this.product,
    required this.creationDate,
    required this.transactionStatus,
    this.claimant,
    this.dateEffective,
    this.productId,
  });

  factory Membership.fromJson(Map<String, dynamic> json) {
    return Membership(
      transactionId: (json['transactionId'] ?? '').toString(),
      transactionType: (json['transactionType'] ?? '').toString(),
      transactionSubtype: (json['transactionSubtype'] ?? '').toString(),
      transactionNumber: (json['transactionNumber'] ?? '').toString(),
      identityType: json['identityType']?.toString(),
      identityNumber: json['identityNumber']?.toString(),
      mainPartner: (json['mainPartner'] ?? '').toString().trim(),
      employeeResponsible: (json['employeeResponsible'] ?? '').toString().trim(),
      recipient: json['recipient']?.toString().trim(),
      createdBy: (json['createdBy'] ?? '').toString().trim(),
      changedBy: json['changedBy']?.toString().trim(),
      product: json['product']?.toString(),
      creationDate: (json['creationDate'] ?? '').toString(),
      transactionStatus: (json['transactionStatus'] ?? '').toString(),
      claimant: json['claimant']?.toString().trim(),
      dateEffective: json['dateEffective']?.toString(),
      productId: json['productId']?.toString(),
    );
  }
}
