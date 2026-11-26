import 'dart:convert';

import '../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class XeroIntegrationException implements Exception {
  final String message;
  final bool reauthorisationRequired;

  const XeroIntegrationException(
    this.message, {
    this.reauthorisationRequired = false,
  });

  @override
  String toString() => message;
}

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
  final bool? invoiceIntegrationRequested;
  final String? integrationStatus;
  final String? authenticationUrl;
  final String? clientIdSecret;
  final String? clientSecretSecret;
  final String? refreshTokenSecret;
  final String? tenantIdSecret;
  final String? accessTokenSecret;
  final String? redirectUrl;
  final String? paymentAccountCode;
  final String? selectedTenantId;
  final String? selectedTenantName;
  final bool organisationSelectionRequired;
  final String? message;

  XeroActivationResult({
    required this.invoiceIntegrationEnabled,
    this.invoiceIntegrationRequested,
    this.integrationStatus,
    this.authenticationUrl,
    this.clientIdSecret,
    this.clientSecretSecret,
    this.refreshTokenSecret,
    this.tenantIdSecret,
    this.accessTokenSecret,
    this.redirectUrl,
    this.paymentAccountCode,
    this.selectedTenantId,
    this.selectedTenantName,
    this.organisationSelectionRequired = false,
    this.message,
  });

  factory XeroActivationResult.fromJson(Map<String, dynamic> json) {
    return XeroActivationResult(
      invoiceIntegrationEnabled: json['invoiceIntegrationEnabled'] == true,
      invoiceIntegrationRequested: json['invoiceIntegrationRequested'] is bool
          ? json['invoiceIntegrationRequested'] as bool
          : null,
      integrationStatus: json['integrationStatus']?.toString(),
      authenticationUrl: json['authenticationUrl']?.toString(),
      clientIdSecret: json['clientIdSecret']?.toString(),
      clientSecretSecret: json['clientSecretSecret']?.toString(),
      refreshTokenSecret: json['refreshTokenSecret']?.toString(),
      tenantIdSecret: json['tenantIdSecret']?.toString(),
      accessTokenSecret: json['accessTokenSecret']?.toString(),
      redirectUrl: json['redirectUrl']?.toString(),
      paymentAccountCode: json['paymentAccountCode']?.toString(),
      selectedTenantId: json['selectedTenantId']?.toString(),
      selectedTenantName: json['selectedTenantName']?.toString(),
      organisationSelectionRequired: json['organisationSelectionRequired'] == true,
      message: json['message']?.toString(),
    );
  }
}

/// Only identifiers and display values from the selected organisation are exposed.
class XeroAccountingOption {
  final String id;
  final String code;
  final String label;
  const XeroAccountingOption({required this.id, required this.code, required this.label});

  factory XeroAccountingOption.account(Map<String, dynamic> json) {
    final code = json['code']?.toString() ?? '';
    return XeroAccountingOption(
      id: json['accountId']?.toString() ?? '',
      code: code,
      label: '$code — ${json['name'] ?? code} (${json['type'] ?? ''})',
    );
  }

  factory XeroAccountingOption.tax(Map<String, dynamic> json) {
    final type = json['taxType']?.toString() ?? '';
    return XeroAccountingOption(
      id: type,
      code: type,
      label: '${json['name'] ?? type} — ${json['displayRate'] ?? 0}% ($type)',
    );
  }
}

class XeroAccountingConfiguration {
  final String organisationId;
  final List<XeroAccountingOption> invoiceAccounts;
  final List<XeroAccountingOption> paymentAccounts;
  final List<XeroAccountingOption> taxRates;
  final Map<String, dynamic>? mapping;
  final String? legacyInvoiceAccountCode;
  final String? legacyPaymentAccountCode;
  final String? legacyInvoiceTaxType;
  final bool mappingValid;
  final bool invoiceIntegrationEnabled;

  const XeroAccountingConfiguration({
    required this.organisationId,
    required this.invoiceAccounts,
    required this.paymentAccounts,
    required this.taxRates,
    this.mapping,
    this.legacyInvoiceAccountCode,
    this.legacyPaymentAccountCode,
    this.legacyInvoiceTaxType,
    required this.mappingValid,
    required this.invoiceIntegrationEnabled,
  });

  factory XeroAccountingConfiguration.fromJson(Map<String, dynamic> json) {
    final options = Map<String, dynamic>.from(json['options'] as Map);
    List<XeroAccountingOption> readOptions(String key, bool tax) {
      return (options[key] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) => tax ? XeroAccountingOption.tax(row) : XeroAccountingOption.account(row))
          .where((row) => row.id.isNotEmpty)
          .toList(growable: false);
    }
    return XeroAccountingConfiguration(
      organisationId: options['organisationId']?.toString() ?? '',
      invoiceAccounts: readOptions('invoiceAccounts', false),
      paymentAccounts: readOptions('paymentAccounts', false),
      taxRates: readOptions('taxRates', true),
      mapping: json['mapping'] is Map ? Map<String, dynamic>.from(json['mapping'] as Map) : null,
      legacyInvoiceAccountCode: json['legacyInvoiceAccountCode']?.toString(),
      legacyPaymentAccountCode: json['legacyPaymentAccountCode']?.toString(),
      legacyInvoiceTaxType: json['legacyInvoiceTaxType']?.toString(),
      mappingValid: json['mappingValid'] == true,
      invoiceIntegrationEnabled: json['invoiceIntegrationEnabled'] == true,
    );
  }

  // Retain only real options. Do not suggest a code from a previously connected organisation.
  String? initialChoice(List<XeroAccountingOption> options, String mappingKey, String? legacyCode) {
    if (mapping != null) {
      if (mapping!['organisationId']?.toString() != organisationId) return null;
      final id = mapping![mappingKey]?.toString();
      return options.any((option) => option.id == id) ? id : null;
    }
    final matches = options.where((option) => option.code == legacyCode).toList();
    return matches.length == 1 ? matches.first.id : null;
  }

  String? get invoiceAccountId => initialChoice(invoiceAccounts, 'invoiceAccountId', legacyInvoiceAccountCode);
  String? get paymentAccountId => initialChoice(paymentAccounts, 'paymentAccountId', legacyPaymentAccountCode);
  String? get invoiceTaxType => initialChoice(taxRates, 'invoiceTaxType', legacyInvoiceTaxType);
}

class XeroIntegrationService {
  static final XeroIntegrationService _instance = XeroIntegrationService._internal();
  factory XeroIntegrationService() => _instance;
  XeroIntegrationService._internal();

  Future<XeroActivationResult> secretNames() async {
    final response = await ApiClient().get('/v2/integrations/xero/secret-names');
    if (response.statusCode != 200) {
      throw AppException('Failed to retrieve Xero secret names: ${response.body}');
    }
    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroActivationResult> activate({
    required String clientId,
    required String clientSecret,
    required String redirectUrl,
    String paymentAccountCode = "",
    bool invoiceIntegrationEnabled = false,
  }) async {
    final response = await ApiClient().post(
      '/v2/integrations/xero/activate',
      body: {
        'clientId': clientId,
        'clientSecret': clientSecret,
        'redirectUrl': redirectUrl,
        'paymentAccountCode': paymentAccountCode,
        'invoiceIntegrationEnabled': invoiceIntegrationEnabled,
      },
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to activate Xero integration: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroAccountingConfiguration> accountingConfiguration() async {
    final response = await ApiClient().get('/v2/integrations/xero/accounting-configuration');
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to load Xero accounts and tax rates.'));
    }
    return XeroAccountingConfiguration.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroAccountingConfiguration> saveAccountingConfiguration({
    required String organisationId,
    required String invoiceAccountId,
    required String paymentAccountId,
    required String invoiceTaxType,
  }) async {
    final response = await ApiClient().post('/v2/integrations/xero/accounting-configuration', body: {
      'organisationId': organisationId,
      'invoiceAccountId': invoiceAccountId,
      'paymentAccountId': paymentAccountId,
      'invoiceTaxType': invoiceTaxType,
    });
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to save Xero accounting configuration.'));
    }
    return XeroAccountingConfiguration.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<XeroConnection>> connections() async {
    final response = await ApiClient().get('/v2/integrations/xero/connections');

    if (response.statusCode != 200) {
      throw XeroIntegrationException(
        _errorMessage(
          response.body,
          fallback: 'Unable to retrieve Xero organisations. Reconnect Xero and try again.',
        ),
        reauthorisationRequired: _reauthorisationRequired(
          response.statusCode,
          response.body,
        ),
      );
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
      throw AppException('Failed to select Xero organisation: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroActivationResult> deactivate() async {
    final response = await ApiClient().post('/v2/integrations/xero/deactivate');

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw AppException('Failed to deactivate Xero integration: ${response.body}');
    }

    return XeroActivationResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<XeroActivationResult> updateInvoiceIntegration(bool enabled) async {
    final response = await ApiClient().post(
      '/v2/integrations/xero/invoice-integration',
      body: {'enabled': enabled},
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw XeroIntegrationException(_errorMessage(response.body, fallback: 'Unable to update invoice integration.'));
    }

    return XeroActivationResult.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
  Future<bool> canCheckReconciliation() async {
    final response = await ApiClient().get('/v2/integrations/xero/reconciliation/capability');
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to check Xero reconciliation permission'));
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['canCheck'] == true;
  }

  Future<List<Map<String, dynamic>>> pendingReconciliation() async {
    final response = await ApiClient().get('/v2/integrations/xero/reconciliation/pending');
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to load Xero reconciliation items'));
    }
    return (jsonDecode(response.body) as List)
        .map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  Future<Map<String, dynamic>> checkReconciliation(String type, String id) async {
    if (!{'INVOICE', 'PAYMENT', 'CREDIT_NOTE', 'CREDIT_NOTE_ALLOCATION'}.contains(type) || id.isEmpty) {
      throw const XeroIntegrationException('Unsupported reconciliation request');
    }
    final response = await ApiClient().post(
      '/v2/integrations/xero/reconciliation/$type/$id/check', body: {},
    );
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Xero reconciliation check failed'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<Map<String, dynamic>> reconciliationReleaseReadiness(String type, String id) async {
    if (!{'INVOICE', 'PAYMENT', 'CREDIT_NOTE', 'CREDIT_NOTE_ALLOCATION'}.contains(type) || id.isEmpty) {
      throw const XeroIntegrationException('Unsupported reconciliation request');
    }
    final response = await ApiClient().get(
      '/v2/integrations/xero/reconciliation/$type/$id/release-readiness',
    );
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to load Xero release blockers'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<List<Map<String, dynamic>>> reconciliationAuditHistory(String type, String id) async {
    if (!{'INVOICE', 'PAYMENT', 'CREDIT_NOTE', 'CREDIT_NOTE_ALLOCATION'}.contains(type) || id.isEmpty) {
      throw const XeroIntegrationException('Unsupported reconciliation request');
    }
    final response = await ApiClient().get(
      '/v2/integrations/xero/reconciliation/$type/$id/audit',
    );
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to load Xero reconciliation audit history'));
    }
    return (jsonDecode(response.body) as List)
        .map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }

  /// Read-only invoice ledger evidence. Never releases a quarantined transaction.
  Future<Map<String, dynamic>> invoiceLedgerSnapshot(String invoiceId) async {
    if (invoiceId.isEmpty) {
      throw const XeroIntegrationException('Invoice ID is required');
    }
    final response = await ApiClient().get(
      '/v2/integrations/xero/reconciliation/invoice/${Uri.encodeComponent(invoiceId)}/ledger-snapshot',
    );
    if (response.statusCode != 200) {
      throw XeroIntegrationException(_errorMessage(response.body,
          fallback: 'Unable to load Xero invoice ledger evidence'));
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  bool _reauthorisationRequired(int statusCode, String body) {
    if (statusCode == 401) return true;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['reauthorisationRequired'] is bool) {
        return decoded['reauthorisationRequired'] == true;
      }
    } catch (_) {
      // Fall through to message-based detection for legacy responses.
    }
    final normalised = body.toLowerCase();
    return normalised.contains('invalid_grant') ||
        normalised.contains('refresh token') ||
        normalised.contains('reconnect xero') ||
        normalised.contains('authorisation has expired');
  }

  String _errorMessage(String body, {required String fallback}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return fallback;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Plain-text and HTML responses are handled below.
    }
    if (trimmed.startsWith('<')) return fallback;
    return trimmed;
  }

}
