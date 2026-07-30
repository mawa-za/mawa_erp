import 'dart:convert';

class FuneralPackageProductDto {
  final String productId; final String productCode; final String productDescription; final int quantity; final int unitPriceCents;
  const FuneralPackageProductDto({required this.productId,this.productCode="",this.productDescription="",required this.quantity,required this.unitPriceCents});
  int get lineTotalCents => quantity * unitPriceCents;
  Map<String,dynamic> toJson()=>{"productId":productId,"quantity":quantity,"unitPriceCents":unitPriceCents};
  factory FuneralPackageProductDto.fromJson(Map<String,dynamic> j)=>FuneralPackageProductDto(productId:(j["productId"]??"").toString(),productCode:(j["productCode"]??"").toString(),productDescription:(j["productDescription"]??"").toString(),quantity:_toInt(j["quantity"]),unitPriceCents:_toInt(j["unitPriceCents"]));
  static int _toInt(dynamic v)=>v is num?v.toInt():int.tryParse(v?.toString()??"")??0;
}

class FuneralPackageDto {
  final String id;
  final String name;
  final String pricingMode;
  final int basePriceCents;
  final List<String> inclusions;
  final String inclusionsJson;
  final bool active;
  final List<FuneralPackageProductDto> products;

  FuneralPackageDto({
    required this.id,
    required this.name,
    this.pricingMode = 'ITEM_TOTAL',
    required this.basePriceCents,
    required this.inclusions,
    this.inclusionsJson = '[]',
    this.active = true,
    this.products = const [],
  });

  Map<String, dynamic> toJson() {
    final encodedInclusions = inclusionsJson.isNotEmpty ? inclusionsJson : jsonEncode(inclusions);
    return {
      if (id.isNotEmpty) 'id': id,
      'name': name,
      'pricingMode': pricingMode,
      'basePriceCents': basePriceCents,
      'inclusions': inclusions,
      'inclusionsJson': encodedInclusions,
      'active': active,
      'products': products.map((e)=>e.toJson()).toList(),
    };
  }

  factory FuneralPackageDto.fromJson(Map<String, dynamic> json) {
    final rawInclusions = json['inclusions'];
    final rawInclusionsJson = json['inclusionsJson']?.toString() ?? '';
    final parsedInclusions = _parseInclusions(rawInclusions, rawInclusionsJson);

    return FuneralPackageDto(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      pricingMode: json['pricingMode']?.toString().toUpperCase() ?? 'ITEM_TOTAL',
      basePriceCents: _parseInt(json['basePriceCents']),
      inclusions: parsedInclusions,
      inclusionsJson: rawInclusionsJson.isNotEmpty ? rawInclusionsJson : jsonEncode(parsedInclusions),
      active: json['active'] is bool ? json['active'] as bool : json['active']?.toString().toLowerCase() != 'false',
      products: (json['products'] is List ? json['products'] as List : const []).whereType<Map>().map((e)=>FuneralPackageProductDto.fromJson(Map<String,dynamic>.from(e))).toList(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
