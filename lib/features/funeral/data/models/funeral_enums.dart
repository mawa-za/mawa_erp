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
  IN_MORTUARY,
  CHECKED_OUT,
  RELEASED,
  CANCELLED;

  static MortuaryStatus parse(String? value) {
    if (value == null) return MortuaryStatus.IN_MORTUARY;
    final normalized = value.trim().toUpperCase();
    if (normalized == 'IN_STORAGE') return MortuaryStatus.IN_MORTUARY;
    if (normalized == 'RELEASED') return MortuaryStatus.CHECKED_OUT;
    return MortuaryStatus.values.firstWhere(
      (e) => e.name.toUpperCase() == normalized,
      orElse: () => MortuaryStatus.IN_MORTUARY,
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
  DRAFT,
  PENDING,
  SUBMITTED,
  IN_PROGRESS,
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
