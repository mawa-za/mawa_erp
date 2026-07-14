import 'dart:convert';

import '../../../core/api_client.dart';
import '../models/product_maintenance.dart';

class ProductMaintenanceService {
  Future<List<ProductMaintenanceItem>> getProducts({String? type, String? query}) async {
    final params = <String, String>{};
    if (type != null && type.trim().isNotEmpty) params['type'] = type.trim();
    if (query != null && query.trim().isNotEmpty) params['query'] = query.trim();

    final response = await ApiClient().get('/product', queryParameters: params);
    if (response.statusCode != 200) {
      throw Exception('Failed to load products (${response.statusCode})');
    }
    final decoded = jsonDecode(response.body);
    final List<dynamic> data = decoded is List
        ? decoded
        : decoded is Map && decoded['content'] is List
            ? decoded['content'] as List
            : <dynamic>[];
    return data
        .whereType<Map>()
        .map((item) => ProductMaintenanceItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<ProductMaintenanceItem> createProduct({
    required String code,
    required String description,
    required String type,
    required String uom,
    required double price,
    String pricingType = 'SELLING-PRICE',
  }) async {
    final response = await ApiClient().post('/product', body: {
      'code': code.trim().toUpperCase(),
      'description': description.trim().toUpperCase(),
      'type': type.trim().toUpperCase(),
      'baseUnitOfMeasure': uom.trim().toUpperCase(),
      'price': price,
      'pricingType': pricingType.trim().isEmpty ? 'SELLING-PRICE' : pricingType.trim().toUpperCase(),
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessage(response.body, 'Failed to create product'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is String) {
      return ProductMaintenanceItem.fromJson(Map<String, dynamic>.from(jsonDecode(decoded)));
    }
    return ProductMaintenanceItem.fromJson(Map<String, dynamic>.from(decoded as Map));
  }

  Future<void> updateProduct({
    required String id,
    required String code,
    required String description,
    required String type,
    required String uom,
    required double price,
    String pricingType = 'SELLING-PRICE',
  }) async {
    final response = await ApiClient().put('/product/$id', body: {
      'id': id,
      'code': code.trim().toUpperCase(),
      'description': description.trim().toUpperCase(),
      'type': type.trim().toUpperCase(),
      'baseUnitOfMeasure': uom.trim().toUpperCase(),
      'price': price,
      'pricingType': pricingType.trim().isEmpty ? 'SELLING-PRICE' : pricingType.trim().toUpperCase(),
    });
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response.body, 'Failed to update product'));
    }
  }

  Future<void> deleteProduct(String id) async {
    final response = await ApiClient().delete('/product/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_errorMessage(response.body, 'Failed to delete product'));
    }
  }


  Future<void> replaceBarcodes(String productId, List<String> barcodes) async {
    final response = await ApiClient().put('/v2/products/$productId/barcodes', body: {
      'barcodes': barcodes,
      'barcodeType': 'EAN',
    });
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Failed to save product barcodes'));
    }
  }

  Future<Map<String, dynamic>> findByBarcode(String barcode) async {
    final response = await ApiClient().get('/v2/products/by-barcode/${Uri.encodeComponent(barcode.trim())}');
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body, 'Product not found for barcode'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  String _errorMessage(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return (decoded['message'] ?? decoded['error'] ?? fallback).toString();
      if (decoded is String && decoded.trim().isNotEmpty) return decoded;
    } catch (_) {}
    return body.trim().isEmpty ? fallback : body;
  }
}
