import 'dart:convert';

class FuneralPackageProductDto {
  final String productId;
  final String code;
  final String description;
  final int amountCents;

  const FuneralPackageProductDto({
    required this.productId,
    required this.code,
    required this.description,
    required this.amountCents,
  });

  factory FuneralPackageProductDto.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return FuneralPackageProductDto(
      productId: (json['productId'] ?? json['id'] ?? '').toString(),
      code: (json['code'] ?? json['productCode'] ?? '').toString(),
      description: (json['description'] ?? json['name'] ?? '').toString(),
      amountCents: parseInt(json['amountCents'] ?? json['priceCents'] ?? json['unitPriceCents']),
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'code': code,
        'description': description,
        'amountCents': amountCents,
      };
}

class FuneralPackageDto {
  final String id;
  final String name;
  final int basePriceCents;
  final List<String> inclusions;
  final List<FuneralPackageProductDto> products;
  final String inclusionsJson;
  final bool active;

  FuneralPackageDto({
    required this.id,
    required this.name,
    required this.basePriceCents,
    required this.inclusions,
    this.products = const [],
    this.inclusionsJson = '[]',
    this.active = true,
  });

  Map<String, dynamic> toJson() {
    final encodedInclusions = products.isNotEmpty
        ? jsonEncode({'products': products.map((e) => e.toJson()).toList()})
        : inclusionsJson.isNotEmpty
            ? inclusionsJson
            : jsonEncode(inclusions);
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'basePriceCents': basePriceCents,
      'inclusions': products.isNotEmpty ? products.map((e) => e.description).toList() : inclusions,
      'inclusionsJson': encodedInclusions,
      'active': active,
    };
  }

  factory FuneralPackageDto.fromJson(Map<String, dynamic> json) {
    final rawInclusions = json['inclusions'];
    final rawInclusionsJson = json['inclusionsJson']?.toString() ?? '';
    final parsedProducts = _parseProducts(rawInclusionsJson, json['products']);
    final parsedInclusions = parsedProducts.isNotEmpty
        ? parsedProducts.map((p) => p.description).where((e) => e.trim().isNotEmpty).toList()
        : _parseInclusions(rawInclusions, rawInclusionsJson);

    return FuneralPackageDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      basePriceCents: _parseInt(json['basePriceCents']),
      inclusions: parsedInclusions,
      products: parsedProducts,
      inclusionsJson: rawInclusionsJson.isNotEmpty ? rawInclusionsJson : jsonEncode(parsedInclusions),
      active: json['active'] is bool ? json['active'] as bool : json['active']?.toString().toLowerCase() != 'false',
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<FuneralPackageProductDto> _parseProducts(String rawInclusionsJson, dynamic rawProducts) {
    if (rawProducts is List) {
      return rawProducts
          .whereType<Map>()
          .map((e) => FuneralPackageProductDto.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.description.trim().isNotEmpty)
          .toList();
    }

    if (rawInclusionsJson.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(rawInclusionsJson);
      if (decoded is Map && decoded['products'] is List) {
        return (decoded['products'] as List)
            .whereType<Map>()
            .map((e) => FuneralPackageProductDto.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.description.trim().isNotEmpty)
            .toList();
      }
      if (decoded is List && decoded.whereType<Map>().isNotEmpty) {
        return decoded
            .whereType<Map>()
            .map((e) => FuneralPackageProductDto.fromJson(Map<String, dynamic>.from(e)))
            .where((p) => p.description.trim().isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static List<String> _parseInclusions(dynamic rawInclusions, String rawInclusionsJson) {
    if (rawInclusions is List) {
      return rawInclusions.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }

    if (rawInclusionsJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawInclusionsJson);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
        }
        if (decoded is Map) {
          final items = decoded['items'] ?? decoded['inclusions'];
          if (items is List) {
            return items.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          }
        }
      } catch (_) {
        return rawInclusionsJson
            .split(RegExp(r'[\n,;]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    return [];
  }
}

