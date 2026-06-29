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
        return _decodeCashupList(response.body);
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
        return _decodeCashupList(response.body);
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

  Future<Cashup> submitCashupAndReturn(Map<String, dynamic> request) async {
    try {
      final response = await ApiClient().post('/v2/cashup', body: request);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic decoded = response.body.isEmpty ? request : jsonDecode(response.body);
        if (decoded is Map) {
          return Cashup.fromJson(Map<String, dynamic>.from(decoded));
        }
        return Cashup.fromJson(request);
      }
      throw Exception(_extractErrorMessage(response.body, 'Failed to submit cashup: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  Future<Cashup> createCashup(Map<String, dynamic> request) {
    return submitCashupAndReturn(request);
  }

  Future<List<Cashup>> searchCashups({
    String? userId,
    String? fromDate,
    String? toDate,
    String? deviceId,
  }) {
    if (deviceId != null && deviceId.isNotEmpty) {
      return getCashupsByDevice(deviceId);
    }
    return getCashups(userId: userId, fromDate: fromDate, toDate: toDate);
  }

  List<Cashup> _decodeCashupList(String body) {
    final dynamic decoded = body.isEmpty ? [] : jsonDecode(body);
    final List<dynamic> data;
    if (decoded is List) {
      data = decoded;
    } else if (decoded is Map && decoded['content'] is List) {
      data = decoded['content'] as List;
    } else if (decoded is Map && decoded['data'] is List) {
      data = decoded['data'] as List;
    } else {
      data = [];
    }
    return data
        .where((json) => json is Map)
        .map((json) => Cashup.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  String _extractErrorMessage(String body, String fallback) {
    try {
      if (body.isEmpty) return fallback;
      final dynamic error = jsonDecode(body);
      if (error is Map) {
        return (error['message'] ?? error['error'] ?? fallback).toString();
      }
    } catch (_) {}
    return fallback;
  }

}
