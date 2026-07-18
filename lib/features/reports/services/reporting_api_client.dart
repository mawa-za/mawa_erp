import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/config.dart';
import '../models/report_dashboard.dart';

class ReportingApiException implements Exception {
  final String message;
  final int? statusCode;
  const ReportingApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ReportingApiClient {
  static final ReportingApiClient _instance = ReportingApiClient._();
  factory ReportingApiClient() => _instance;
  ReportingApiClient._();

  final http.Client _client = http.Client();

  Future<ReportDashboard> dashboard({int periods = 6, int months = 6}) async {
    final response = await _get('/v2/reports/dashboard', {'periods': periods, 'months': months});
    if (response.statusCode != 200) {
      throw ReportingApiException(_message(response), statusCode: response.statusCode);
    }
    return ReportDashboard.fromJson(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  Future<http.Response> _get(String path, Map<String, dynamic> query) async {
    await ApiClient().ensureFreshAccessToken();
    var response = await _execute(path, query);
    if (response.statusCode == 401 && await ApiClient().ensureFreshAccessToken(force: true)) {
      response = await _execute(path, query);
    }
    return response;
  }

  Future<http.Response> _execute(String path, Map<String, dynamic> query) async {
    final prefs = await SharedPreferences.getInstance();
    final host = await _host(prefs);
    final token = (prefs.getString('accessToken') ?? '').trim();
    final role = (prefs.getString('selectedRole') ?? '').trim();
    final tenant = kIsWeb ? Config.webTenant : (prefs.getString('tenant') ?? '').trim();
    if (host.isEmpty) throw const ReportingApiException('Reporting API host is not configured');
    if (token.isEmpty || role.isEmpty) throw const ReportingApiException('Your reporting session is incomplete. Sign in again.');

    final useHttp = host.startsWith('localhost') || host.startsWith('127.0.0.1') || host.startsWith('10.0.2.2');
    final params = query.map((key, value) => MapEntry(key, '$value'));
    final uri = useHttp ? Uri.http(host, path, params) : Uri.https(host, path, params);
    return _client.get(uri, headers: {
      'Accept': 'application/json', 'Authorization': 'Bearer $token', 'X-Role': role,
      'X-TenantID': tenant, 'X-Tenant-Id': tenant,
      if ((prefs.getString('userId') ?? '').isNotEmpty) 'X-UserID': prefs.getString('userId')!,
    }).timeout(const Duration(seconds: 45));
  }

  Future<String> _host(SharedPreferences prefs) async {
    if (kIsWeb) return Config.reportingApiHost;
    final configured = (prefs.getString('reporting_api_host') ?? '').trim();
    if (configured.isNotEmpty) return configured;
    final apiHost = (prefs.getString('api_host') ?? '').trim();
    return Config.reportingHostFromApiHost(apiHost);
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['message'] != null) return '${body['message']}';
    } catch (_) {}
    return 'Unable to load reports (HTTP ${response.statusCode})';
  }
}
