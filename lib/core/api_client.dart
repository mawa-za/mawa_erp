import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
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

  bool _isSuccessfulRefreshResponse(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  Future<http.Response> _postRefreshRequest({
    required Uri url,
    required String refreshToken,
    required String tenantId,
  }) {
    // mawa_pay refreshes using the refresh token as the Bearer token.
    // Keep the token in the body/header too so older backend variants still work.
    return http.post(
      url,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $refreshToken',
        'Refresh-Token': refreshToken,
        'X-TenantID': tenantId,
        'X-Tenant-Id': tenantId,
      },
      body: jsonEncode({
        'refreshToken': refreshToken,
        'refresh_token': refreshToken,
        'refresh': refreshToken,
      }),
    );
  }

  Future<bool> _refreshToken({bool logoutOnUnauthorized = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = (prefs.getString('refreshToken') ?? '').trim();
      final host = await _getApiHost();
      final tenantId = (await _getTenantId() ?? '').trim();

      if (host == null || host.isEmpty) {
        debugPrint('ApiClient: API host not configured for token refresh');
        return false;
      }

      if (refreshToken.isEmpty) {
        debugPrint('ApiClient: No refresh token available');
        if (logoutOnUnauthorized) await logout(reason: 'missing_refresh_token');
        return false;
      }

      final refreshAttempts = <Uri>[
        // Match mawa_pay behaviour first.
        _buildUrl(host, '/refresh-token'),
        // Keep v2 fallback for deployments that expose only the versioned endpoint.
        _buildUrl(host, '/v2/refresh-token'),
      ];

      http.Response? lastResponse;
      for (final url in refreshAttempts) {
        debugPrint('ApiClient: Attempting refresh at $url');
        final response = await _postRefreshRequest(
          url: url,
          refreshToken: refreshToken,
          tenantId: tenantId,
        );
        lastResponse = response;
        debugPrint('ApiClient: Refresh response ${response.statusCode} from $url');

        if (_isSuccessfulRefreshResponse(response)) {
          await _storeTokensFromResponse(response.body);
          final newAccessToken = (prefs.getString('accessToken') ?? '').trim();
          final storedRefreshToken = (prefs.getString('refreshToken') ?? '').trim();
          if (newAccessToken.isNotEmpty) {
            if (storedRefreshToken.isEmpty) {
              await prefs.setString('refreshToken', refreshToken);
            }
            debugPrint('ApiClient: Token refreshed successfully');
            return true;
          }
          debugPrint('ApiClient: Refresh succeeded but no access token was returned');
        }
      }

      final status = lastResponse?.statusCode ?? 0;
      debugPrint('ApiClient: Refresh failed. Status: $status');
      if (logoutOnUnauthorized) await logout(reason: 'refresh_failed_$status');
      return false;
    } catch (e) {
      debugPrint('ApiClient: Exception during _refreshToken: $e');
      if (logoutOnUnauthorized) await logout(reason: 'refresh_exception');
      return false;
    }
  }


  Future<http.StreamedResponse> uploadMultipart(
    String path, {
    required String fieldName,
    required String filename,
    required Uint8List bytes,
    String? contentType,
    Map<String, String>? fields,
    bool includeRole = true,
  }) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) throw Exception('API Host not configured');
    final url = _buildUrl(host, path);
    final baseHeaders = await _getHeaders(includeRole: includeRole);
    baseHeaders.remove('Content-Type');
    final request = http.MultipartRequest('POST', url);
    request.headers.addAll(baseHeaders);
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(fieldName, bytes, filename: filename));
    return request.send();
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
