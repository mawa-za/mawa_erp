import '../../../core/models/field_option.dart';

class ProductMaintenanceItem {
  final String id;
  final String code;
  final String description;
  final FieldOption? type;
  final FieldOption? baseUnitOfMeasure;
  final double price;
  final String pricingType;
  final DateTime? validFrom;
  final DateTime? validTo;
  final List<ProductPrice> pricings;

  const ProductMaintenanceItem({
    required this.id,
    required this.code,
    required this.description,
    this.type,
    this.baseUnitOfMeasure,
    required this.price,
    required this.pricingType,
    this.validFrom,
    this.validTo,
    this.pricings = const [],
  });

  factory ProductMaintenanceItem.fromJson(Map<String, dynamic> json) {
    final pricings = _parsePricings(json['pricings']);
    final preferredPrice = _preferredPrice(pricings);
    return ProductMaintenanceItem(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      type: _fieldOption(json['type'], fallbackField: 'PRODUCT-TYPE'),
      baseUnitOfMeasure: _fieldOption(json['baseUnitOfMeasure'] ?? json['uom'], fallbackField: 'UOM'),
      price: preferredPrice?.value ?? _parseDouble(json['price'] ?? json['value'] ?? json['amount']),
      pricingType: preferredPrice?.pricingCode ?? 'SELLING-PRICE',
      validFrom: _parseDate(json['validFrom'] ?? json['valid_from']),
      validTo: _parseDate(json['validTo'] ?? json['valid_to']),
      pricings: pricings,
    );
  }

  static FieldOption? _fieldOption(dynamic value, {required String fallbackField}) {
    if (value == null) return null;
    if (value is Map) return FieldOption.fromJson(Map<String, dynamic>.from(value));
    final code = value.toString();
    if (code.trim().isEmpty) return null;
    return FieldOption(
      field: fallbackField,
      code: code,
      type: '',
      description: code,
      validFrom: '',
      validTo: '',
    );
  }

  static List<ProductPrice> _parsePricings(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => ProductPrice.fromJson(Map<String, dynamic>.from(item)))
        .where((price) => price.pricingCode.isNotEmpty)
        .toList();
  }

  static ProductPrice? _preferredPrice(List<ProductPrice> prices) {
    if (prices.isEmpty) return null;
    for (final price in prices) {
      if (price.pricingCode.toUpperCase() == 'SELLING-PRICE') return price;
    }
    return prices.first;
  }


  bool get isActive {
    final expiry = validTo;
    if (expiry == null) return true;
    return !expiry.isBefore(DateTime.now());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final raw = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(raw < 100000000000 ? raw * 1000 : raw);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static double _parseDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}

class ProductPrice {
  final String pricingCode;
  final String pricingDescription;
  final double value;

  const ProductPrice({
    required this.pricingCode,
    required this.pricingDescription,
    required this.value,
  });

  factory ProductPrice.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'];
    String code = '';
    String description = '';
    if (pricing is Map) {
      code = (pricing['code'] ?? '').toString();
      description = (pricing['description'] ?? code).toString();
    } else {
      code = (pricing ?? json['pricingType'] ?? '').toString();
      description = code;
    }
    return ProductPrice(
      pricingCode: code,
      pricingDescription: description.isEmpty ? code : description,
      value: ProductMaintenanceItem._parseDouble(json['value']),
    );
  }
}
