class ProductLookup {
  final String id;
  final String code;
  final String description;
  final int priceCents;

  const ProductLookup({
    required this.id,
    required this.code,
    required this.description,
    required this.priceCents,
  });

  factory ProductLookup.fromJson(Map<String, dynamic> json) {
    int parseCents(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int priceFromPricing(dynamic pricings) {
      if (pricings is List && pricings.isNotEmpty && pricings.first is Map) {
        final price = (pricings.first as Map)['value'];
        if (price is int) return price * 100;
        if (price is num) return (price * 100).round();
        final parsed = double.tryParse(price?.toString() ?? '');
        return parsed == null ? 0 : (parsed * 100).round();
      }
      return 0;
    }

    final amountCents = parseCents(json['priceCents'] ?? json['amountCents'] ?? json['unitPriceCents']);
    return ProductLookup(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      priceCents: amountCents > 0 ? amountCents : priceFromPricing(json['pricings']),
    );
  }
}
