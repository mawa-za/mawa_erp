import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final http.Client _client = http.Client();
  Completer<bool>? _refreshCompleter;

  ApiClient._internal();

  Future<String?> _getApiHost() async {
    if (kIsWeb) return Config.apiHost;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_host') ?? Config.apiHost;
  }

  Future<String?> _getTenantId() async {
    if (kIsWeb) return Config.webTenant;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('tenant') ?? Config.webTenant;
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

    var response = await _client.post(
      url,
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.post(
          url,
          headers: await _getHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> put(String path, {dynamic body}) async {
    final host = await _getApiHost();
    final url = Uri.parse('https://$host$path');

    var response = await _client.put(
      url,
      headers: await _getHeaders(),
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.put(
          url,
          headers: await _getHeaders(),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> get(String path) async {
    final host = await _getApiHost();
    final url = Uri.parse('https://$host$path');

    var response = await _client.get(url, headers: await _getHeaders());

    if (response.statusCode == 401) {
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.get(url, headers: await _getHeaders());
      }
    }

    return response;
  }

  Future<http.Response> delete(String path) async {
    final host = await _getApiHost();
    final url = Uri.parse('https://$host$path');

    var response = await _client.delete(url, headers: await _getHeaders());

    if (response.statusCode == 401) {
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.delete(url, headers: await _getHeaders());
      }
    }

    return response;
  }

  Future<bool> _handleUnauthorized() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final success = await _refreshToken();
      _refreshCompleter!.complete(success);
      return success;
    } catch (e) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      final host = await _getApiHost();
      final tenantId = await _getTenantId();

      if (refreshToken == null) {
        return false;
      }

      final url = Uri.parse('https://$host/refresh-token');
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
  }
}
