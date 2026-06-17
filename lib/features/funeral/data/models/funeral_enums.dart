enum PickupStatus {
  PENDING,
  ASSIGNED,
  COMPLETED,
  CANCELLED;

  static PickupStatus parse(String? value) {
    if (value == null) return PickupStatus.PENDING;
    return PickupStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => PickupStatus.PENDING,
    );
  }
}

enum MortuaryStatus {
  IN_STORAGE,
  RELEASED,
  CANCELLED;

  static MortuaryStatus parse(String? value) {
    if (value == null) return MortuaryStatus.IN_STORAGE;
    return MortuaryStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => MortuaryStatus.IN_STORAGE,
    );
  }
}

enum CoverSource {
  LOCAL_TENANT,
  EXTERNAL_TENANT;

  static CoverSource parse(String? value) {
    if (value == null) return CoverSource.LOCAL_TENANT;
    return CoverSource.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => CoverSource.LOCAL_TENANT,
    );
  }
}

enum ClaimStatus {
  PENDING,
  APPROVED,
  PARTIALLY_APPROVED,
  REJECTED,
  CANCELLED;

  static ClaimStatus parse(String? value) {
    if (value == null) return ClaimStatus.PENDING;
    return ClaimStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => ClaimStatus.PENDING,
    );
  }
}

enum InvoiceEntityType {
  BURIAL_SOCIETY,
  FAMILY_REP;

  static InvoiceEntityType parse(String? value) {
    if (value == null) return InvoiceEntityType.FAMILY_REP;
    return InvoiceEntityType.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => InvoiceEntityType.FAMILY_REP,
    );
  }
}

enum PaymentMethod {
  CASH,
  EFT,
  CARD;

  static PaymentMethod parse(String? value) {
    if (value == null) return PaymentMethod.CASH;
    return PaymentMethod.values.firstWhere(
      (e) => e.name.toUpperCase() == value.toUpperCase(),
      orElse: () => PaymentMethod.CASH,
    );
  }
}
