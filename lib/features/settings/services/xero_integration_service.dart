import 'dart:convert';

import '../../../core/api_client.dart';

class XeroConnection {
  final String tenantId;
  final String? tenantName;
  final String? tenantType;

  XeroConnection({required this.tenantId, this.tenantName, this.tenantType});

  factory XeroConnection.fromJson(Map<String, dynamic> json) {
    return XeroConnection(
      tenantId: json['tenantId']?.toString() ?? '',
      tenantName: json['tenantName']?.toString(),
      tenantType: json['tenantType']?.toString(),
    );
  }
}

class XeroActivationResult {
  final bool invoiceIntegrationEnabled;
  final String? authenticationUrl;
  final String? clientIdSecret;
  final String? clientSecretSecret;
  final String? refreshTokenSecret;
  final String? tenantIdSecret;
  final String? redirectUrl;
  final String? selectedTenantId;
  final String? selectedTenantName;
  final bool organisationSelectionRequired;
  final String? message;

  XeroActivationResult({
    required this.invoiceIntegrationEnabled,
    this.authenticationUrl,
    this.clientIdSecret,
    this.clientSecretSecret,
    this.refreshTokenSecret,
    this.tenantIdSecret,
    this.redirectUrl,
    this.selectedTenantId,
    this.selectedTenantName,
    this.organisationSelectionRequired = false,
    this.message,
  });

  factory XeroActivationResult.fromJson(Map<String, dynamic> json) {
    return XeroActivationResult(
      invoiceIntegrationEnabled: json['invoiceIntegrationEnabled'] == true,
      authenticationUrl: json['authenticationUrl']?.toString(),
      clientIdSecret: json['clientIdSecret']?.toString(),
      clientSecretSecret: json['clientSecretSecret']?.toString(),
      refreshTokenSecret: json['refreshTokenSecret']?.toString(),
      tenantIdSecret: json['tenantIdSecret']?.toString(),
      redirectUrl: json['redirectUrl']?.toString(),
      selectedTenantId: json['selectedTenantId']?.toString(),
      selectedTenantName: json['selectedTenantName']?.toString(),
      organisationSelectionRequired: json['organisationSelectionRequired'] == true,
      message: json['message']?.toString(),
    );
  }
}

class XeroIntegrationService {
  static final XeroIntegrationService _instance = XeroIntegrationService._internal();
  factory XeroIntegrationService() => _instance;
  XeroIntegrationService._internal();

  Future<XeroActivationResult> activate({
    required String clientId,
    required String clientSecret,
    required String redirectUrl,
    bool invoiceIntegrationEnabled = true,
  }) async {
    final response = await ApiClient().post(
      '/v2/integrations/xero/activate',
      body: {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'redirectUrl': redirectUrl,
        'invoiceIntegrationEnabled': invoiceIntegrationEnabled,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to activate Xero integration: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<XeroConnection>> connections() async {
    final response = await ApiClient().get('/v2/integrations/xero/connections');

    if (response.statusCode != 200) {
      throw Exception('Failed to retrieve Xero organisations: ${response.body}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(XeroConnection.fromJson)
        .where((connection) => connection.tenantId.isNotEmpty)
        .toList();
  }

  Future<XeroActivationResult> selectTenant(String tenantId) async {
    final response = await ApiClient().post(
      '/v2/integrations/xero/select-tenant',
      body: {'tenantId': tenantId},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to select Xero organisation: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroActivationResult> deactivate() async {
    final response = await ApiClient().post('/v2/integrations/xero/deactivate');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to deactivate Xero integration: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
