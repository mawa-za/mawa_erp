import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  Future<String?> _getApiHost() async {
    if (kIsWeb) return Config.apiHost;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_host');
  }

  Future<String?> _getTenantId() async {
    if (kIsWeb) return Config.webTenant;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tenant');
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final tenantId = await _getTenantId();
    
    final headers = {
      'Content-Type': 'application/json',
      'X-TenantID': tenantId ?? '',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }

  Future<http.Response> post(String path, {dynamic body}) async {
    final host = await _getApiHost();
    final url = Uri.parse('https://$host$path');
    final headers = await _getHeaders();

    var response = await http.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final success = await _refreshToken();
      if (success) {
        // Retry with new token
        final newHeaders = await _getHeaders();
        response = await http.post(
          url,
          headers: newHeaders,
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> get(String path) async {
    final host = await _getApiHost();
    final url = Uri.parse('https://$host$path');
    final headers = await _getHeaders();

    var response = await http.get(url, headers: headers);

    if (response.statusCode == 401) {
      final success = await _refreshToken();
      if (success) {
        final newHeaders = await _getHeaders();
        response = await http.get(url, headers: newHeaders);
      }
    }

    return response;
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      final host = await _getApiHost();
      final tenantId = await _getTenantId();

      if (refreshToken == null) return false;

      final url = Uri.parse('https://$host/v2/refresh-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TenantID': tenantId ?? '',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('accessToken', data['accessToken']);
        await prefs.setString('refreshToken', data['refreshToken']);
        return true;
      } else {
        // Refresh failed, maybe log out user
        await _handleLogout();
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    // Note: Navigation to login usually handled by UI observing state or on next restart
  }
}
