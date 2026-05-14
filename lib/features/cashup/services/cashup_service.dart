import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../models/cashup.dart';

class CashupService {
  static final CashupService _instance = CashupService._internal();
  factory CashupService() => _instance;
  CashupService._internal();

  Future<List<Cashup>> getCashups({
    String? userId,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {};
      
      if (userId != null && userId.isNotEmpty) {
        queryParams['userId'] = userId;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      debugPrint('Fetching cashups with params: $queryParams');

      // Updated to use /v2/cashup/all and explicitly excluded the role header
      final response = await ApiClient().get(
        '/v2/cashup/all', 
        queryParameters: queryParams, 
        includeRole: false,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Cashup.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load cashups: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error in getCashups: $e');
      rethrow;
    }
  }

  Future<Cashup> getCashupById(String id) async {
    try {
      // Explicitly excluded the role header for detail view as well
      final response = await ApiClient().get('/v2/cashup/$id', includeRole: false);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return Cashup.fromJson(Map<String, dynamic>.from(data));
      } else {
        throw Exception('Failed to load cashup details: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
