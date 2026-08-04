import '../../../core/models/field_option.dart';

class ProductTypeDefinition {
  final String code;
  final String name;
  final String description;
  final bool stockControlled;
  final bool canBeReceived;
  final bool canBePutAway;
  final bool consumedOnIssue;
  final bool returnable;
  final bool assetTracked;
  final bool bundle;
  final bool specialisedWorkflow;
  final bool defaultAvailableForSale;

  const ProductTypeDefinition({
    required this.code,
    required this.name,
    required this.description,
    required this.stockControlled,
    required this.canBeReceived,
    required this.canBePutAway,
    required this.consumedOnIssue,
    required this.returnable,
    required this.assetTracked,
    required this.bundle,
    required this.specialisedWorkflow,
    required this.defaultAvailableForSale,
  });

  factory ProductTypeDefinition.fromJson(Map<String, dynamic> json) {
    return ProductTypeDefinition(
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['description'] ?? json['code'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      stockControlled: _bool(json['stockControlled']),
      canBeReceived: _bool(json['canBeReceived']),
      canBePutAway: _bool(json['canBePutAway']),
      consumedOnIssue: _bool(json['consumedOnIssue']),
      returnable: _bool(json['returnable']),
      assetTracked: _bool(json['assetTracked']),
      bundle: _bool(json['bundle']),
      specialisedWorkflow: _bool(json['specialisedWorkflow']),
      defaultAvailableForSale: _bool(json['defaultAvailableForSale']),
    );
  }

  static bool _bool(dynamic value) => value == true || value?.toString().toLowerCase() == 'true' || value == 1;
}

class ProductCategoryDefinition {
  final String id;
  final String code;
  final String name;
  final String description;
  final String? parentId;
  final String? parentCode;
  final String? parentName;
  final String? productType;
  final String fullPath;
  final bool active;
  final int sortOrder;

  const ProductCategoryDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    this.parentId,
    this.parentCode,
    this.parentName,
    this.productType,
    required this.fullPath,
    required this.active,
    required this.sortOrder,
  });

  factory ProductCategoryDefinition.fromJson(Map<String, dynamic> json) {
    return ProductCategoryDefinition(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      name: (json['name'] ?? json['description'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      parentId: _nullable(json['parentId']),
      parentCode: _nullable(json['parentCode']),
      parentName: _nullable(json['parentName']),
      productType: _nullable(json['productType']),
      fullPath: (json['fullPath'] ?? json['name'] ?? '').toString(),
      active: ProductTypeDefinition._bool(json['active']),
      sortOrder: int.tryParse((json['sortOrder'] ?? '0').toString()) ?? 0,
    );
  }

  bool supportsType(String typeCode) => productType == null || productType!.isEmpty || productType == typeCode;

  static String? _nullable(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }
}

class ProductMaintenanceItem {
  final String id;
  final String code;
  final String description;
  final FieldOption? type;
  final ProductTypeDefinition? typeBehaviour;
  final ProductCategoryDefinition? primaryCategory;
  final bool availableForSale;
  final FieldOption? baseUnitOfMeasure;
  final double price;
  final String pricingType;
  final DateTime? validFrom;
  final DateTime? validTo;
  final List<ProductPrice> pricings;
  final List<String> barcodes;
  final bool managedByFuneralPackage;
  final String? funeralPackageId;

  const ProductMaintenanceItem({
    required this.id,
    required this.code,
    required this.description,
    this.type,
    this.typeBehaviour,
    this.primaryCategory,
    required this.availableForSale,
    this.baseUnitOfMeasure,
    required this.price,
    required this.pricingType,
    this.validFrom,
    this.validTo,
    this.pricings = const [],
    this.barcodes = const [],
    this.managedByFuneralPackage = false,
    this.funeralPackageId,
  });

  factory ProductMaintenanceItem.fromJson(Map<String, dynamic> json) {
    final pricings = _parsePricings(json['pricings']);
    final preferredPrice = _preferredPrice(pricings);
    return ProductMaintenanceItem(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      type: _fieldOption(json['type'], fallbackField: 'PRODUCT-TYPE'),
      typeBehaviour: json['typeBehaviour'] is Map
          ? ProductTypeDefinition.fromJson(Map<String, dynamic>.from(json['typeBehaviour'] as Map))
          : null,
      primaryCategory: json['primaryCategory'] is Map
          ? ProductCategoryDefinition.fromJson(Map<String, dynamic>.from(json['primaryCategory'] as Map))
          : null,
      availableForSale: ProductTypeDefinition._bool(json['availableForSale']),
      baseUnitOfMeasure: _fieldOption(json['baseUnitOfMeasure'] ?? json['uom'], fallbackField: 'UOM'),
      price: preferredPrice?.value ?? _parseDouble(json['price'] ?? json['value'] ?? json['amount']),
      pricingType: preferredPrice?.pricingCode ?? 'SELLING-PRICE',
      validFrom: _parseDate(json['validFrom'] ?? json['valid_from']),
      validTo: _parseDate(json['validTo'] ?? json['valid_to']),
      pricings: pricings,
      barcodes: (json['barcodes'] as List? ?? const <dynamic>[])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(),
      managedByFuneralPackage: ProductTypeDefinition._bool(json['managedByFuneralPackage']),
      funeralPackageId: ProductCategoryDefinition._nullable(json['funeralPackageId']),
    );
  }

  bool get isActive {
    final expiry = validTo;
    if (expiry == null) return true;
    return !expiry.isBefore(DateTime.now());
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
      if (price.pricingCode.toUpperCase().replaceAll('_', '-') == 'SELLING-PRICE') return price;
    }
    return prices.first;
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
      code = (pricing['code'] ?? '').toString().trim().toUpperCase().replaceAll('_', '-');
      description = (pricing['description'] ?? code).toString();
    } else {
      code = (pricing ?? json['pricingType'] ?? '').toString().trim().toUpperCase().replaceAll('_', '-');
      description = code;
    }
    return ProductPrice(
      pricingCode: code,
      pricingDescription: description.isEmpty ? code : description,
      value: ProductMaintenanceItem._parseDouble(json['value']),
    );
  }
}


class ProductAssetLink {
  final String assetId;
  final String assetNo;
  final String assetName;
  final int capacity;
  final int reservedQuantity;
  final int availableCapacity;
  final bool active;
  final bool available;
  final String status;
  final String condition;
  final String? notes;

  const ProductAssetLink({
    required this.assetId,
    required this.assetNo,
    required this.assetName,
    required this.capacity,
    required this.reservedQuantity,
    required this.availableCapacity,
    required this.active,
    required this.available,
    required this.status,
    required this.condition,
    this.notes,
  });

  factory ProductAssetLink.fromJson(Map<String, dynamic> json) => ProductAssetLink(
        assetId: (json['asset_id'] ?? json['assetId'] ?? '').toString(),
        assetNo: (json['asset_no'] ?? json['assetNo'] ?? '').toString(),
        assetName: (json['name'] ?? json['asset_name'] ?? json['assetName'] ?? '').toString(),
        capacity: int.tryParse((json['capacity'] ?? '1').toString()) ?? 1,
        reservedQuantity: int.tryParse((json['reserved_quantity'] ?? '0').toString()) ?? 0,
        availableCapacity: int.tryParse((json['available_capacity'] ?? '0').toString()) ?? 0,
        active: ProductTypeDefinition._bool(json['active']),
        available: ProductTypeDefinition._bool(json['available']),
        status: (json['status'] ?? '').toString(),
        condition: (json['condition_status'] ?? json['condition'] ?? '').toString(),
        notes: ProductCategoryDefinition._nullable(json['link_notes'] ?? json['notes']),
      );

  Map<String, dynamic> toRequest() => {
        'assetId': assetId,
        'capacity': capacity,
        'notes': notes,
      };
}
