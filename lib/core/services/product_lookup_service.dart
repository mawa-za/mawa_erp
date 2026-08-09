import 'dart:convert';

import '../api_client.dart';
import '../models/product_lookup.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ProductLookupService {
  static final ProductLookupService _instance = ProductLookupService._internal();
  factory ProductLookupService() => _instance;
  ProductLookupService._internal();

  final Map<String, List<ProductLookup>> _cache = {};

  Future<List<ProductLookup>> getProducts({String? type, bool forceRefresh = false, bool strictType = false}) async {
    final key = '${(type ?? 'ALL').toUpperCase()}:${strictType ? 'STRICT' : 'FALLBACK'}';
    if (!forceRefresh && _cache.containsKey(key)) return _cache[key]!;

    Future<List<ProductLookup>> fetch(String path) async {
      final response = await ApiClient().get(path);
      if (response.statusCode != 200) {
        throw AppException('Failed to load products (${response.statusCode})');
      }
      final dynamic decoded = jsonDecode(response.body);
      final List<dynamic> data = decoded is List
          ? decoded
          : decoded is Map && decoded['content'] is List
              ? decoded['content'] as List
              : <dynamic>[];
      return data
          .whereType<Map>()
          .map((item) => ProductLookup.fromJson(Map<String, dynamic>.from(item)))
          .where((p) => p.id.isNotEmpty || p.code.isNotEmpty)
          .toList();
    }

    List<ProductLookup> products = [];
    if (type != null && type.trim().isNotEmpty) {
      try {
        products = await fetch('/product?type=${Uri.encodeComponent(type.trim())}');
      } catch (_) {
        products = [];
      }
    }
    if (products.isEmpty && !strictType) {
      products = await fetch('/product');
    }
    _cache[key] = products;
    return products;
  }

  void clearCache({String? type}) {
    if (type == null || type.trim().isEmpty) {
      _cache.clear();
      return;
    }
    _cache.remove(type.trim().toUpperCase());
  }
}
