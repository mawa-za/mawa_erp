import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  final http.Client _client = http.Client();
  Completer<bool>? _refreshCompleter;
  Timer? _tokenKeepAliveTimer;

  final _logoutController = StreamController<bool>.broadcast();
  Stream<bool> get logoutStream => _logoutController.stream;

  ApiClient._internal();

  Future<String?> _getApiHost() async {
    if (kIsWeb) return Config.apiHost;
    final prefs = await SharedPreferences.getInstance();
    final storedHost = prefs.getString('api_host');
    if (storedHost != null && storedHost.isNotEmpty) return storedHost;
    return Config.apiHost.isNotEmpty
        ? Config.apiHost
        : 'dev.api.app.mawa.co.za';
  }

  Future<String?> _getTenantId() async {
    final prefs = await SharedPreferences.getInstance();
    final tenant = prefs.getString('tenant')?.trim();
    if (tenant != null && tenant.isNotEmpty) return tenant;
    return Config.webTenant.isNotEmpty ? Config.webTenant : null;
  }

  Uri _buildUrl(
    String host,
    String path, [
    Map<String, dynamic>? queryParameters,
  ]) {
    final tempUri = Uri.parse(path);
    final combinedParams = Map<String, String>.from(tempUri.queryParameters);

    queryParameters?.forEach((key, value) {
      if (value != null) combinedParams[key] = value.toString();
    });

    final cleanPath = tempUri.path;
    final finalPath = cleanPath.startsWith('/') ? cleanPath : '/$cleanPath';
    final lowerHost = host.toLowerCase();
    final useHttp = lowerHost.startsWith('localhost') ||
        lowerHost.startsWith('127.0.0.1') ||
        lowerHost.startsWith('10.0.2.2');

    return useHttp
        ? Uri.http(
            host,
            finalPath,
            combinedParams.isEmpty ? null : combinedParams,
          )
        : Uri.https(
            host,
            finalPath,
            combinedParams.isEmpty ? null : combinedParams,
          );
  }

  DateTime? _tokenExpiry(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map || payload['exp'] is! num) return null;
      return DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
        isUtc: true,
      );
    } catch (_) {
      return null;
    }
  }

  bool _tokenExpiresSoon(
    String token, {
    Duration margin = const Duration(minutes: 3),
  }) {
    final expiry = _tokenExpiry(token);
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now().toUtc().add(margin));
  }

  bool _tokenExpired(String token) {
    final expiry = _tokenExpiry(token);
    if (expiry == null) return false;
    return !expiry.isAfter(DateTime.now().toUtc());
  }

  /// Keeps a logged-in browser/mobile session alive even when the user is
  /// reading a screen and no API request is being made. The timer only calls
  /// the refresh endpoint when the access token is close to expiry.
  void startTokenKeepAlive() {
    if (_tokenKeepAliveTimer != null) return;
    unawaited(ensureFreshAccessToken());
    _tokenKeepAliveTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => unawaited(ensureFreshAccessToken()),
    );
  }

  void stopTokenKeepAlive() {
    _tokenKeepAliveTimer?.cancel();
    _tokenKeepAliveTimer = null;
  }

  Future<bool> ensureFreshAccessToken({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final accessToken = (prefs.getString('accessToken') ?? '').trim();
    final refreshToken = (prefs.getString('refreshToken') ?? '').trim();

    if (accessToken.isEmpty) return false;
    if (!force && !_tokenExpiresSoon(accessToken)) return true;

    if (refreshToken.isEmpty) {
      if (_tokenExpired(accessToken)) {
        await logout(sessionExpired: true);
      }
      return false;
    }

    return _handleRefresh();
  }

  Future<Map<String, String>> _getHeaders({
    bool includeRole = true,
    bool refreshIfNeeded = true,
    String accept = 'application/json',
  }) async {
    if (refreshIfNeeded) {
      await ensureFreshAccessToken();
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final tenantId = await _getTenantId();
    final role = prefs.getString('selectedRole');
    final userId = prefs.getString('userId');

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': accept,
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

  Future<http.Response> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool includeRole = true,
  }) =>
      _send(
        'POST',
        path,
        body: body,
        queryParameters: queryParameters,
        includeRole: includeRole,
      );

  /// Sends a request without an existing ERP session. Used by short-lived
  /// admin handoff exchange so a stale user token cannot interfere with it.
  Future<http.Response> postPublic(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    String? tenantOverride,
  }) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) {
      throw AppException('API Host not configured');
    }
    final override = tenantOverride?.trim() ?? '';
    final tenantId = override.isNotEmpty
        ? override
        : (await _getTenantId() ?? '').trim();
    return _execute(
      'POST',
      _buildUrl(host, path, queryParameters),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-TenantID': tenantId,
        'X-Tenant-Id': tenantId,
      },
      body: body,
    );
  }

  Future<http.Response> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool includeRole = true,
  }) =>
      _send(
        'PUT',
        path,
        body: body,
        queryParameters: queryParameters,
        includeRole: includeRole,
      );

  Future<http.Response> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    bool includeRole = true,
  }) =>
      _send(
        'PATCH',
        path,
        body: body,
        queryParameters: queryParameters,
        includeRole: includeRole,
      );

  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool includeRole = true,
    String accept = 'application/json',
  }) =>
      _send(
        'GET',
        path,
        queryParameters: queryParameters,
        includeRole: includeRole,
        accept: accept,
      );

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool includeRole = true,
  }) =>
      _send(
        'DELETE',
        path,
        queryParameters: queryParameters,
        includeRole: includeRole,
      );

  Future<http.Response> _send(
    String method,
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    required bool includeRole,
    String accept = 'application/json',
  }) async {
    final host = await _getApiHost();
    if (host == null || host.isEmpty) {
      throw AppException('API Host not configured');
    }

    final url = _buildUrl(host, path, queryParameters);
    var response = await _execute(
      method,
      url,
      headers: await _getHeaders(
        includeRole: includeRole,
        accept: accept,
      ),
      body: body,
    );

    if (response.statusCode == 401) {
      final refreshed = await ensureFreshAccessToken(force: true);
      if (refreshed) {
        response = await _execute(
          method,
          url,
          headers: await _getHeaders(
            includeRole: includeRole,
            refreshIfNeeded: false,
            accept: accept,
          ),
          body: body,
        );
      }
    }

    if (kDebugMode) {
      debugPrint('ApiClient $method $url -> ${response.statusCode}');
    }
    return response;
  }

  Future<http.Response> _execute(
    String method,
    Uri url, {
    required Map<String, String> headers,
    dynamic body,
  }) async {
    final encodedBody = body == null ? null : jsonEncode(body);
    try {
      late final Future<http.Response> request;
      switch (method) {
        case 'GET':
          request = _client.get(url, headers: headers);
          break;
        case 'POST':
          request = _client.post(url, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          request = _client.put(url, headers: headers, body: encodedBody);
          break;
        case 'PATCH':
          request = _client.patch(url, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          request = _client.delete(url, headers: headers);
          break;
        default:
          throw UnsupportedError('Unsupported HTTP method: $method');
      }
      return await request.timeout(const Duration(seconds: 45));
    } on TimeoutException catch (error) {
      throw AppException(
        error,
        fallback: 'The request took too long. Check your connection and try again.',
      );
    } on AppException {
      rethrow;
    } catch (error) {
      throw AppException(error);
    }
  }

  Future<bool> _handleRefresh() async {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<bool>();
    _refreshCompleter = completer;
    try {
      final success = await _refreshToken();
      completer.complete(success);
      return success;
    } catch (error) {
      debugPrint('ApiClient: token refresh error: $error');
      completer.complete(false);
      return false;
    } finally {
      if (identical(_refreshCompleter, completer)) {
        _refreshCompleter = null;
      }
    }
  }

  Future<http.Response> _postRefresh(
    Uri url,
    String refreshToken,
    String tenantId,
  ) {
    return http
        .post(
          url,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $refreshToken',
            'X-TenantID': tenantId,
            'X-Tenant-Id': tenantId,
          },
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(const Duration(seconds: 45));
  }

  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = (prefs.getString('refreshToken') ?? '').trim();
      final host = await _getApiHost();
      final tenantId = (await _getTenantId() ?? '').trim();

      if (refreshToken.isEmpty || host == null || host.isEmpty) {
        return false;
      }

      var response = await _postRefresh(
        _buildUrl(host, '/v2/refresh-token'),
        refreshToken,
        tenantId,
      );
      if (response.statusCode == 404) {
        response = await _postRefresh(
          _buildUrl(host, '/refresh-token'),
          refreshToken,
          tenantId,
        );
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map) {
          final access = (decoded['accessToken'] ?? decoded['token'] ?? '')
              .toString()
              .trim();
          final rotatedRefresh = (decoded['refreshToken'] ?? '')
              .toString()
              .trim();
          if (access.isNotEmpty) {
            await prefs.setString('accessToken', access);
            await prefs.setString(
              'refreshToken',
              rotatedRefresh.isNotEmpty ? rotatedRefresh : refreshToken,
            );
            return true;
          }
        }
      }

      final status = response.statusCode;
      if (status == 400 || status == 401 || status == 403) {
        await logout(sessionExpired: true);
      }
      debugPrint('ApiClient: token refresh rejected with HTTP $status');
      return false;
    } on TimeoutException catch (error) {
      debugPrint('ApiClient: token refresh timed out: $error');
      return false;
    } catch (error) {
      // Network/server errors must not clear a refresh token that may still be
      // valid. The keep-alive timer or next API call will retry.
      debugPrint('ApiClient: temporary token refresh failure: $error');
      return false;
    }
  }

  Future<void> logout({bool sessionExpired = false}) async {
    stopTokenKeepAlive();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    await prefs.remove('selectedRole');
    await prefs.remove('selectedRoleDescription');
    await prefs.remove('adminHandoffSession');
    for (final key in const [
      'accountType',
      'testUser',
      'protectedUser',
      'systemManaged',
      'accessScope',
      'environmentScope',
      'externalTransactionsBlocked',
      'accessExpiresAt',
      'mfaRequired',
      'platformSession',
      'platformUserId',
      'handoffId',
      'accessReason',
      'ticketReference',
      'accessTenantId',
      'allWorkcentres',
    ]) {
      await prefs.remove(key);
    }
    _logoutController.add(sessionExpired);
  }
}
