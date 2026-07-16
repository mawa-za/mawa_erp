class TombstoneOrder {
  final String id;
  final String orderNo;
  final String customerPartnerId;
  final String? membershipId;
  final String? deceasedPartnerId;
  final String deceasedName;
  final String? funeralServiceId;
  final String? cemeteryName;
  final String? cemeteryArea;
  final String? graveNumber;
  final String fundingMethod;
  final String status;
  final String fundingStatus;
  final String productionStatus;
  final String installationStatus;
  final int subtotalCents;
  final int taxCents;
  final int discountCents;
  final int totalCents;
  final int confirmedFundingCents;
  final int balanceCents;
  final String? invoiceId;
  final String? notes;
  final String? expectedInstallationDate;
  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> fundingAllocations;
  final Map<String, dynamic>? laybyAgreement;
  final List<Map<String, dynamic>> laybyInstallments;
  final List<Map<String, dynamic>> assessments;
  final List<Map<String, dynamic>> amendments;
  final List<Map<String, dynamic>> designs;
  final List<Map<String, dynamic>> productionJobs;
  final List<Map<String, dynamic>> installations;
  final List<Map<String, dynamic>> statusHistory;

  const TombstoneOrder({
    required this.id,
    required this.orderNo,
    required this.customerPartnerId,
    required this.deceasedName,
    required this.fundingMethod,
    required this.status,
    required this.fundingStatus,
    required this.productionStatus,
    required this.installationStatus,
    required this.subtotalCents,
    required this.taxCents,
    required this.discountCents,
    required this.totalCents,
    required this.confirmedFundingCents,
    required this.balanceCents,
    this.membershipId,
    this.deceasedPartnerId,
    this.funeralServiceId,
    this.cemeteryName,
    this.cemeteryArea,
    this.graveNumber,
    this.invoiceId,
    this.notes,
    this.expectedInstallationDate,
    this.items = const [],
    this.fundingAllocations = const [],
    this.laybyAgreement,
    this.laybyInstallments = const [],
    this.assessments = const [],
    this.amendments = const [],
    this.designs = const [],
    this.productionJobs = const [],
    this.installations = const [],
    this.statusHistory = const [],
  });

  factory TombstoneOrder.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> list(String key) => (json[key] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    int cents(String key) => (json[key] as num?)?.toInt() ?? 0;
    final layby = json['laybyAgreement'];
    return TombstoneOrder(
      id: json['id']?.toString() ?? '',
      orderNo: json['orderNo']?.toString() ?? '',
      customerPartnerId: json['customerPartnerId']?.toString() ?? '',
      membershipId: json['membershipId']?.toString(),
      deceasedPartnerId: json['deceasedPartnerId']?.toString(),
      deceasedName: json['deceasedName']?.toString() ?? '',
      funeralServiceId: json['funeralServiceId']?.toString(),
      cemeteryName: json['cemeteryName']?.toString(),
      cemeteryArea: json['cemeteryArea']?.toString(),
      graveNumber: json['graveNumber']?.toString(),
      fundingMethod: json['fundingMethod']?.toString() ?? 'CASH',
      status: json['status']?.toString() ?? 'DRAFT',
      fundingStatus: json['fundingStatus']?.toString() ?? 'UNFUNDED',
      productionStatus: json['productionStatus']?.toString() ?? 'NOT_STARTED',
      installationStatus: json['installationStatus']?.toString() ?? 'NOT_READY',
      subtotalCents: cents('subtotalCents'),
      taxCents: cents('taxCents'),
      discountCents: cents('discountCents'),
      totalCents: cents('totalCents'),
      confirmedFundingCents: cents('confirmedFundingCents'),
      balanceCents: cents('balanceCents'),
      invoiceId: json['invoiceId']?.toString(),
      notes: json['notes']?.toString(),
      expectedInstallationDate: json['expectedInstallationDate']?.toString(),
      items: list('items'),
      fundingAllocations: list('fundingAllocations'),
      laybyAgreement: layby is Map ? Map<String, dynamic>.from(layby) : null,
      laybyInstallments: list('laybyInstallments'),
      assessments: list('assessments'),
      amendments: list('amendments'),
      designs: list('designs'),
      productionJobs: list('productionJobs'),
      installations: list('installations'),
      statusHistory: list('statusHistory'),
    );
  }

  double get total => totalCents / 100;
  double get confirmedFunding => confirmedFundingCents / 100;
  double get balance => balanceCents / 100;
}

class TombstoneDashboard {
  final Map<String, dynamic> values;
  const TombstoneDashboard(this.values);
  int count(String key) => (values[key] as num?)?.toInt() ?? 0;
  double amount(String key) => ((values[key] as num?)?.toInt() ?? 0) / 100;
}
