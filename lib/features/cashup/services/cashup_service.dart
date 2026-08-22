import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../core/api_client.dart';
import '../models/cashup.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CashupService {
  static final CashupService _instance = CashupService._internal();
  factory CashupService() => _instance;
  CashupService._internal();


  Future<CashupPage> getCashupPage({
    String status = 'ALL',
    String search = '',
    int page = 0,
    int size = 50,
  }) async {
    final response = await ApiClient().get(
      '/v2/cashup/page',
      queryParameters: {
        'status': status,
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page': page,
        'size': size,
      },
      includeRole: false,
    );
    if (response.statusCode != 200) {
      throw AppException(_extractErrorMessage(
        response.body,
        'Failed to load cashups: ${response.statusCode}',
      ));
    }

    final dynamic decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (decoded is! Map) {
      return const CashupPage(items: [], page: 0, last: true);
    }
    final content = decoded['content'] is List ? decoded['content'] as List : const [];
    final items = content
        .whereType<Map>()
        .map((item) => Cashup.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return CashupPage(
      items: items,
      page: _asInt(decoded['number']),
      last: decoded['last'] == true,
    );
  }

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
        throw AppException('Failed to load cashups: ${response.statusCode}');
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
        throw AppException('Failed to load cashup details: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> submitCashup(Map<String, dynamic> request) async {
    try {
      final response = await ApiClient().post('/v2/cashup', body: request);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to submit cashup: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> approveCashup(String id) async {
    try {
      final response = await ApiClient().post('/v2/cashup/$id/approve');
      if (response.statusCode != 200) {
        throw AppException('Failed to approve cashup: ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> rejectCashup(String id, Map<String, dynamic> reason) async {
    try {
      final response = await ApiClient().post('/v2/cashup/$id/reject', body: reason);
      if (response.statusCode != 200) {
        throw AppException('Failed to reject cashup: ${response.body}');
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
        throw AppException('Failed to load device cashups: ${response.statusCode}');
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
      throw AppException(_extractErrorMessage(response.body, 'Failed to submit cashup: ${response.statusCode}'));
    } catch (e) {
      rethrow;
    }
  }

  Future<Cashup> createCashup(Map<String, dynamic> request) {
    return submitCashupAndReturn(request);
  }

  Future<Cashup> createManualCashup(Map<String, dynamic> request) async {
    final response = await ApiClient().post('/v2/cashup/manual', body: request);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic decoded = response.body.isEmpty ? request : jsonDecode(response.body);
      if (decoded is Map) {
        return Cashup.fromJson(Map<String, dynamic>.from(decoded));
      }
    }
    throw AppException(_extractErrorMessage(
      response.body,
      'Failed to create manual cashup: ${response.statusCode}',
    ));
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


  Future<CashupDeposit> createDeposit(String cashupId, Map<String, dynamic> request) async {
    final response = await ApiClient().post('/v2/cashup/$cashupId/deposits', body: request);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic decoded = response.body.isEmpty ? request : jsonDecode(response.body);
      return CashupDeposit.fromJson(Map<String, dynamic>.from(decoded as Map));
    }
    throw AppException(_extractErrorMessage(response.body, 'Failed to create deposit: ${response.statusCode}'));
  }

  Future<List<CashupDeposit>> getDeposits(String cashupId) async {
    final response = await ApiClient().get('/v2/cashup/$cashupId/deposits', includeRole: false);
    if (response.statusCode == 200) {
      final dynamic decoded = response.body.isEmpty ? [] : jsonDecode(response.body);
      final List<dynamic> data = decoded is List ? decoded : [];
      return data
          .whereType<Map>()
          .map((json) => CashupDeposit.fromJson(Map<String, dynamic>.from(json)))
          .toList();
    }
    throw AppException(_extractErrorMessage(response.body, 'Failed to load deposits: ${response.statusCode}'));
  }

  Future<void> deleteDeposit(String cashupId, String depositId) async {
    final response = await ApiClient().delete('/v2/cashup/$cashupId/deposits/$depositId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException(_extractErrorMessage(response.body, 'Failed to delete deposit: ${response.statusCode}'));
    }
  }

  Future<void> submitForApproval(String cashupId, Map<String, dynamic> request) async {
    final response = await ApiClient().post('/v2/cashup/$cashupId/submit', body: request);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException(_extractErrorMessage(response.body, 'Failed to submit cashup for approval: ${response.statusCode}'));
    }
  }

  Future<void> closeCashup(String cashupId, {String? actionBy}) async {
    final response = await ApiClient().post(
      '/v2/cashup/$cashupId/close',
      body: {if (actionBy != null && actionBy.isNotEmpty) 'actionBy': actionBy},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(_extractErrorMessage(response.body, 'Failed to close cashup: ${response.statusCode}'));
    }
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

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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

class CashupPage {
  const CashupPage({
    required this.items,
    required this.page,
    required this.last,
  });

  final List<Cashup> items;
  final int page;
  final bool last;
}
