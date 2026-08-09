import 'dart:convert';

import '../../../core/api_client.dart';
import '../models/manual_receipt_book.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ManualReceiptBookService {
  final ApiClient _api = ApiClient();

  Future<List<ManualReceiptBook>> list({bool activeOnly = false}) async {
    final response = await _api.get(
      '/v2/manual-receipt-books',
      queryParameters: {'activeOnly': activeOnly},
    );
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Failed to load manual receipt books'));
    }
    final decoded = jsonDecode(response.body);
    final values = decoded is List ? decoded : const <dynamic>[];
    return values
        .whereType<Map>()
        .map((row) => ManualReceiptBook.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<ManualReceiptBook> create(Map<String, dynamic> payload) async {
    final response = await _api.post('/v2/manual-receipt-books', body: payload);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException(_message(response.body, 'Failed to create manual receipt book'));
    }
    return ManualReceiptBook.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<ManualReceiptBook> update(String id, Map<String, dynamic> payload) async {
    final response = await _api.put('/v2/manual-receipt-books/$id', body: payload);
    if (response.statusCode != 200) {
      throw AppException(_message(response.body, 'Failed to update manual receipt book'));
    }
    return ManualReceiptBook.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<void> deactivate(String id) async {
    final response = await _api.delete('/v2/manual-receipt-books/$id');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException(_message(response.body, 'Failed to close manual receipt book'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return (decoded['message'] ?? decoded['error'] ?? fallback).toString();
    } catch (_) {}
    return fallback;
  }
}
