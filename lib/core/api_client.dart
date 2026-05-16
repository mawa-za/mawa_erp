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

  // Stream to notify UI of logout events
  final _logoutController = StreamController<bool>.broadcast();
  Stream<bool> get logoutStream => _logoutController.stream;

  ApiClient._internal();

  Future<String?> _getApiHost() async {
    if (kIsWeb) return Config.apiHost;
    final prefs = await SharedPreferences.getInstance();
    final storedHost = prefs.getString('api_host');
    if (storedHost != null && storedHost.isNotEmpty) return storedHost;
    return Config.apiHost.isNotEmpty ? Config.apiHost : 'dev.api.app.mawa.co.za';
  }

  Future<String?> _getTenantId() async {
    if (kIsWeb) return Config.webTenant;
    final prefs = await SharedPreferences.getInstance();
    final tenant = prefs.getString('tenant');
    if (tenant != null && tenant.isNotEmpty) return tenant;
    return Config.webTenant.isNotEmpty ? Config.webTenant : null;
  }

  Future<Map<String, String>> _getHeaders({bool includeRole = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final tenantId = await _getTenantId();
    final role = prefs.getString('selectedRole');
    final userId = prefs.getString('userId');
    
    final headers = {
      'Content-Type': 'application/json',
      'X-TenantID': tenantId ?? '',
      'X-Tenant-Id': tenantId ?? '',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('ApiClient: Warning - No accessToken found');
    }

    if (includeRole && role != null && role.isNotEmpty) {
      headers['X-Role'] = role;
    }

    if (userId != null && userId.isNotEmpty) {
      headers['X-UserID'] = userId;
      headers['X-User-Id'] = userId;
    }
    
    return headers;
  }

  Uri _buildUrl(String host, String path, [Map<String, dynamic>? queryParameters]) {
    final Uri tempUri = Uri.parse(path);
    final Map<String, String> combinedParams = Map<String, String>.from(tempUri.queryParameters);
    
    if (queryParameters != null) {
      queryParameters.forEach((key, value) {
        if (value != null) {
          combinedParams[key] = value.toString();
        }
      });
    }
    
    final String cleanPath = tempUri.path;
    final String finalPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';

    return Uri.https(
      host,
      finalPath,
      combinedParams.isEmpty ? null : combinedParams,
    );
  }

  Future<http.Response> post(String path, {dynamic body, bool includeRole = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path);
    final headers = await _getHeaders(includeRole: includeRole);

    var response = await _client.post(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for POST $url');
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.post(
          url,
          headers: await _getHeaders(includeRole: includeRole),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> put(String path, {dynamic body, bool includeRole = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path);
    final headers = await _getHeaders(includeRole: includeRole);

    var response = await _client.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for PUT $url');
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.put(
          url,
          headers: await _getHeaders(includeRole: includeRole),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? queryParameters, bool includeRole = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    debugPrint('ApiClient GET: $url');

    var response = await _client.get(url, headers: headers);

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for GET $url. Body: ${response.body}');
      final success = await _handleUnauthorized();
      if (success) {
        final retryHeaders = await _getHeaders(includeRole: includeRole);
        response = await _client.get(url, headers: retryHeaders);
      }
    }

    return response;
  }

  Future<http.Response> delete(String path, {Map<String, dynamic>? queryParameters, bool includeRole = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    var response = await _client.delete(url, headers: headers);

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for DELETE $url');
      final success = await _handleUnauthorized();
      if (success) {
        response = await _client.delete(url, headers: await _getHeaders(includeRole: includeRole));
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
      debugPrint('Error during token refresh: $e');
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

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('No refresh token available');
        await _handleLogout();
        return false;
      }

      debugPrint('Attempting to refresh token...');
      final url = Uri.parse('https://$host/v2/refresh-token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TenantID': tenantId ?? '',
          'X-Tenant-Id': tenantId ?? '',
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
        }),
      );

      debugPrint('Refresh token response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['accessToken'] ?? data['token'];
        final newRefreshToken = data['refreshToken'];

        if (newAccessToken != null) {
          await prefs.setString('accessToken', newAccessToken);
          if (newRefreshToken != null) {
            await prefs.setString('refreshToken', newRefreshToken);
          }
          debugPrint('Token refreshed successfully');
          return true;
        }
      } 
      
      debugPrint('Token refresh failed. Status: ${response.statusCode}, Body: ${response.body}');
      await _handleLogout();
      return false;
    } catch (e) {
      debugPrint('Exception during _refreshToken: $e');
      return false;
    }
  }

  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    _logoutController.add(true);
  }
}
