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

    // Browser builds must not downgrade API calls to HTTP.
    // Keep localhost on HTTP for local development, and use HTTPS everywhere else.
    final String lowerHost = host.toLowerCase();
    final bool useHttp = lowerHost.startsWith('localhost') ||
        lowerHost.startsWith('127.0.0.1') ||
        lowerHost.startsWith('10.0.2.2');

    if (!useHttp) {
      return Uri.https(
        host,
        finalPath,
        combinedParams.isEmpty ? null : combinedParams,
      );
    } else {
      return Uri.http(
        host,
        finalPath,
        combinedParams.isEmpty ? null : combinedParams,
      );
    }
  }



  String? _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return <String, dynamic>{};
  }

  Future<void> _storeTokensFromResponse(String body) async {
    final prefs = await SharedPreferences.getInstance();
    final data = _decodeJsonObject(body);
    final tokenContainer = data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : data;

    final newAccessToken = _readString(tokenContainer, const [
      'accessToken',
      'access_token',
      'token',
      'jwt',
    ]);
    final newRefreshToken = _readString(tokenContainer, const [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);

    if (newAccessToken != null) {
      await prefs.setString('accessToken', newAccessToken);
    }
    if (newRefreshToken != null) {
      await prefs.setString('refreshToken', newRefreshToken);
    }
  }

  Future<http.Response> post(String path, {dynamic body, Map<String, dynamic>? queryParameters, bool includeRole = true, bool logoutOnUnauthorized = true}) async {
    try {
      final host = await _getApiHost();
      if (host == null || host.isEmpty) throw Exception('API Host not configured');
      final url = _buildUrl(host, path, queryParameters);
      final headers = await _getHeaders(includeRole: includeRole);

      debugPrint('ApiClient POST: $url');
      debugPrint('Headers: ${jsonEncode(headers)}');
      if (body != null) debugPrint('Payload: ${jsonEncode(body)}');

      var response = await _client.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      );

      debugPrint('Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 401) {
        debugPrint('401 Unauthorized for POST $url');
        final success = await _handleUnauthorized(logoutOnUnauthorized: logoutOnUnauthorized);
        if (success) {
          final retryHeaders = await _getHeaders(includeRole: includeRole);
          response = await _client.post(
            url,
            headers: retryHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
        }
      }

      return response;
    } catch (e) {
      debugPrint('ApiClient POST Exception: $e');
      rethrow;
    }
  }

  Future<http.Response> put(String path, {dynamic body, Map<String, dynamic>? queryParameters, bool includeRole = true, bool logoutOnUnauthorized = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    debugPrint('ApiClient PUT: $url');

    var response = await _client.put(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for PUT $url');
      final success = await _handleUnauthorized(logoutOnUnauthorized: logoutOnUnauthorized);
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

  Future<http.Response> patch(String path, {dynamic body, Map<String, dynamic>? queryParameters, bool includeRole = true, bool logoutOnUnauthorized = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    debugPrint('ApiClient PATCH: $url');

    var response = await _client.patch(
      url,
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for PATCH $url');
      final success = await _handleUnauthorized(logoutOnUnauthorized: logoutOnUnauthorized);
      if (success) {
        response = await _client.patch(
          url,
          headers: await _getHeaders(includeRole: includeRole),
          body: body != null ? jsonEncode(body) : null,
        );
      }
    }

    return response;
  }

  Future<http.Response> get(String path, {Map<String, dynamic>? queryParameters, bool includeRole = true, bool logoutOnUnauthorized = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    debugPrint('ApiClient GET: $url');

    var response = await _client.get(url, headers: headers);

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for GET $url. Body: ${response.body}');
      final success = await _handleUnauthorized(logoutOnUnauthorized: logoutOnUnauthorized);
      if (success) {
        final retryHeaders = await _getHeaders(includeRole: includeRole);
        response = await _client.get(url, headers: retryHeaders);
      }
    }

    return response;
  }

  Future<http.Response> delete(String path, {Map<String, dynamic>? queryParameters, bool includeRole = true, bool logoutOnUnauthorized = true}) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path, queryParameters);
    final headers = await _getHeaders(includeRole: includeRole);

    debugPrint('ApiClient DELETE: $url');

    var response = await _client.delete(url, headers: headers);

    if (response.statusCode == 401) {
      debugPrint('401 Unauthorized for DELETE $url');
      final success = await _handleUnauthorized(logoutOnUnauthorized: logoutOnUnauthorized);
      if (success) {
        response = await _client.delete(url, headers: await _getHeaders(includeRole: includeRole));
      }
    }

    return response;
  }

  Future<bool> _handleUnauthorized({bool logoutOnUnauthorized = true}) async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();
    try {
      final success = await _refreshToken(logoutOnUnauthorized: logoutOnUnauthorized);
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

  Future<bool> _refreshToken({bool logoutOnUnauthorized = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refreshToken');
      final host = await _getApiHost();
      final tenantId = await _getTenantId();

      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('ApiClient: No refresh token available');
        if (logoutOnUnauthorized) await logout(reason: 'missing_refresh_token');
        return false;
      }

      // Trying v2 endpoint as authenticate is versioned
      final url = _buildUrl(host ?? '', '/v2/refresh-token');
      debugPrint('ApiClient: Attempting refresh at $url');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-TenantID': tenantId ?? '',
          'X-Tenant-Id': tenantId ?? '',
          'Refresh-Token': refreshToken,
        },
        body: jsonEncode({
          'refreshToken': refreshToken,
          'refresh_token': refreshToken,
        }),
      );

      debugPrint('ApiClient: Refresh response ${response.statusCode}');

      if (response.statusCode == 200) {
        await _storeTokensFromResponse(response.body);
        final newAccessToken = prefs.getString('accessToken');
        if (newAccessToken != null && newAccessToken.isNotEmpty) {
          debugPrint('ApiClient: Token refreshed successfully');
          return true;
        }
      } 
      
      // If v2 refresh fails, fallback to root endpoint for older deployments.
      if (response.statusCode != 200) {
        debugPrint('ApiClient: /v2/refresh-token failed (${response.statusCode}), falling back to /refresh-token');
        final fallbackUrl = _buildUrl(host ?? '', '/refresh-token');
        final fallbackResponse = await http.post(
          fallbackUrl,
          headers: {
            'Content-Type': 'application/json',
            'X-TenantID': tenantId ?? '',
            'X-Tenant-Id': tenantId ?? '',
            'Refresh-Token': refreshToken,
          },
          body: jsonEncode({
            'refreshToken': refreshToken,
            'refresh_token': refreshToken,
          }),
        );
        
        if (fallbackResponse.statusCode == 200) {
          await _storeTokensFromResponse(fallbackResponse.body);
          final newAccessToken = prefs.getString('accessToken');
          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            debugPrint('ApiClient: Token refreshed via fallback successfully');
            return true;
          }
        }
        debugPrint('ApiClient: Fallback refresh also failed: ${fallbackResponse.statusCode}');
      }
      
      debugPrint('ApiClient: Refresh failed. Status: ${response.statusCode}');
      if (logoutOnUnauthorized) await logout(reason: 'refresh_failed_${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('ApiClient: Exception during _refreshToken: $e');
      return false;
    }
  }

  Future<void> logout({String reason = 'manual_or_unauthorized'}) async {
    final prefs = await SharedPreferences.getInstance();
    debugPrint('ApiClient: Performing logout, clearing tokens. Reason: $reason');
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('selectedRole');
    await prefs.remove('selectedRoleDescription');
    _logoutController.add(true);
  }
}
