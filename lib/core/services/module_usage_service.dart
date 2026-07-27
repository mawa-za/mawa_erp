import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_client.dart';
import '../models/module_usage.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ModuleUsageService {
  static final ModuleUsageService _instance = ModuleUsageService._internal();
  factory ModuleUsageService() => _instance;
  ModuleUsageService._internal();

  final ApiClient _apiClient = ApiClient();

  Future<void> trackUsage({
    required String moduleCode,
    String? moduleName,
    String? modulePath,
    String? workcenterId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');

      final request = TrackModuleUsageRequest(
        userId: userId,
        moduleCode: moduleCode,
        moduleName: moduleName,
        modulePath: modulePath,
        workcenterId: workcenterId,
      );

      final response = await _apiClient.post(
        '/v2/module-usage/track',
        body: request.toJson(),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException('Failed to track module usage: ${response.body}');
      }
    } catch (e) {
      // We often don't want to crash the app if tracking fails
      debugPrint('Error tracking module usage: $e');
    }
  }

  Future<List<ModuleUsage>> getRecentlyUsed({int limit = 8}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      final queryParameters = {
        if (userId != null) 'userId': userId,
        'limit': limit.toString(),
      };

      final response = await _apiClient.get(
        '/v2/module-usage/recent',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ModuleUsage.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load recent modules: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ModuleUsage>> getFrequentlyUsed({int limit = 8}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      final queryParameters = {
        if (userId != null) 'userId': userId,
        'limit': limit.toString(),
      };

      final response = await _apiClient.get(
        '/v2/module-usage/frequent',
        queryParameters: queryParameters,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ModuleUsage.fromJson(json)).toList();
      } else {
        throw AppException('Failed to load frequent modules: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    if (userId == null || userId.isEmpty) return;

    final response = await _apiClient.delete(
      '/v2/module-usage/reset',
      queryParameters: {'userId': userId},
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw AppException('Failed to reset module usage: ${response.body}');
    }
  }
}
