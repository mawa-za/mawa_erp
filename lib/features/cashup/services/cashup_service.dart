import 'dart:convert';
import 'package:flutter/foundation.dart';
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
      String path = '/v2/cashup/all';
      
      if (userId != null && userId.isNotEmpty && fromDate != null && toDate != null) {
        path = '/v2/cashup';
        queryParams['userId'] = userId;
        queryParams['fromDate'] = fromDate;
        queryParams['toDate'] = toDate;
      }

      final response = await ApiClient().get(
        path, 
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
      rethrow;
    }
  }

  Future<Cashup> getCashupById(String id) async {
    try {
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

  Future<void> submitCashup(Map<String, dynamic> request) async {
    try {
      final response = await ApiClient().post('/v2/cashup', body: request);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to submit cashup: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approveCashup(String id) async {
    try {
      final response = await ApiClient().post('/v2/cashup/$id/approve');
      if (response.statusCode != 200) {
        throw Exception('Failed to approve cashup: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectCashup(String id, Map<String, dynamic> reason) async {
    try {
      final response = await ApiClient().post('/v2/cashup/$id/reject', body: reason);
      if (response.statusCode != 200) {
        throw Exception('Failed to reject cashup: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Cashup>> getCashupsByDevice(String deviceId) async {
    try {
      final response = await ApiClient().get('/v2/cashup/device/$deviceId', includeRole: false);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Cashup.fromJson(Map<String, dynamic>.from(json))).toList();
      } else {
        throw Exception('Failed to load device cashups: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Cashup?> getActiveCashup(String deviceId, String userId) async {
    try {
      final response = await ApiClient().get(
        '/v2/cashup/active',
        queryParameters: {'deviceId': deviceId, 'userId': userId},
        includeRole: false,
      );
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        return Cashup.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
