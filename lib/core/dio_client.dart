import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late Dio dio;

  DioClient._internal() {
    dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        
        // Resolve host
        String host = Config.apiHost;
        if (!kIsWeb) {
          final storedHost = prefs.getString('api_host');
          if (storedHost != null && storedHost.isNotEmpty) host = storedHost;
          if (host.isEmpty) host = 'dev.api.app.mawa.co.za';
        }
        
        options.baseUrl = 'https://$host';

        // Headers
        final token = prefs.getString('accessToken');
        final tenantId = kIsWeb ? Config.webTenant : (prefs.getString('tenant') ?? '');
        final role = prefs.getString('selectedRole');
        final userId = prefs.getString('userId');

        options.headers['Content-Type'] = 'application/json';
        options.headers['X-TenantID'] = tenantId;
        options.headers['X-Tenant-Id'] = tenantId;

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        if (role != null && role.isNotEmpty) {
          options.headers['X-Role'] = role;
        }

        if (userId != null && userId.isNotEmpty) {
          options.headers['X-UserID'] = userId;
          options.headers['X-User-Id'] = userId;
        }

        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token refresh logic could be implemented here similar to ApiClient
          debugPrint('DioClient: 401 Unauthorized');
        }
        return handler.next(e);
      },
    ));

    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }
}
