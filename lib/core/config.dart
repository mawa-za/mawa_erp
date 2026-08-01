import 'package:flutter/foundation.dart';

class Config {
  static const String env = String.fromEnvironment('env', defaultValue: 'dev');

  static String get apiHost {
    if (kIsWeb) {
      switch (env) {
        case 'prod':
          return 'api.app.mawa.co.za';
        case 'beta':
          return 'beta.api.app.mawa.co.za';
        case 'alpha':
          return 'alpha.api.app.mawa.co.za';
        case 'dev':
        default:
          return 'dev.api.app.mawa.co.za';
      }
    }
    return '';
  }

  static String get reportingApiHost {
    switch (env) {
      case 'prod':
        return 'reports.api.app.mawa.co.za';
      case 'beta':
        return 'beta.reports.api.app.mawa.co.za';
      case 'alpha':
        return 'alpha.reports.api.app.mawa.co.za';
      case 'prep':
        return 'prep.reports.api.app.mawa.co.za';
      case 'dev':
      default:
        return 'dev.reports.api.app.mawa.co.za';
    }
  }

  static String reportingHostFromApiHost(String apiHost) {
    final host = apiHost.trim().toLowerCase();
    if (host.isEmpty) return reportingApiHost;
    if (host == 'api.app.mawa.co.za') return 'reports.api.app.mawa.co.za';
    if (host.endsWith('.api.app.mawa.co.za')) {
      return host.replaceFirst('.api.app.mawa.co.za', '.reports.api.app.mawa.co.za');
    }
    if (host.startsWith('localhost') || host.startsWith('127.0.0.1') || host.startsWith('10.0.2.2')) {
      return host;
    }
    return reportingApiHost;
  }

  static String get webTenant {
    if (!kIsWeb) return '';
    return resolveWebTenantReference(Uri.base.toString());
  }

  /// Resolves the tenant from an explicit query parameter first, then from a
  /// tenant-specific hostname. Shared environment hosts (for example
  /// dev.app.mawa.co.za) deliberately return an empty value because they do
  /// not identify one tenant in a multi-tenant environment.
  @visibleForTesting
  static String resolveWebTenantReference(String value) {
    final candidate = value.trim();
    if (candidate.isEmpty) return '';

    final uri = Uri.tryParse(candidate.contains('://') ? candidate : 'https://$candidate');
    if (uri != null) {
      final explicitTenant = _firstNonBlank([
        uri.queryParameters['tenantId'],
        uri.queryParameters['tenant_id'],
        uri.queryParameters['tenant'],
        ..._fragmentTenantValues(uri.fragment),
      ]);
      if (explicitTenant.isNotEmpty) return explicitTenant;
    }

    final host = normalizeTenantReference(candidate);
    return isSharedApplicationHost(host) ? '' : host;
  }

  @visibleForTesting
  static bool isSharedApplicationHost(String value) {
    final host = normalizeTenantReference(value);
    return const {
      'app.mawa.co.za',
      'dev.app.mawa.co.za',
      'prep.app.mawa.co.za',
      'alpha.app.mawa.co.za',
      'beta.app.mawa.co.za',
      'localhost',
      '127.0.0.1',
    }.contains(host);
  }

  /// Converts the browser URL (including Flutter hash routes) into the
  /// canonical hostname expected by the backend's X-TenantID header.
  ///
  /// Example:
  /// https://dev.app.mawa.co.za/#/login -> dev.app.mawa.co.za
  @visibleForTesting
  static String normalizeTenantReference(String value) {
    var candidate = value.trim();
    if (candidate.isEmpty) return '';

    final commaIndex = candidate.indexOf(',');
    if (commaIndex >= 0) {
      candidate = candidate.substring(0, commaIndex).trim();
    }

    final hasScheme = candidate.contains('://');
    final uri = Uri.tryParse(hasScheme ? candidate : 'https://$candidate');
    final host = uri?.host.trim().toLowerCase() ?? '';

    if (host.isNotEmpty) {
      return host.endsWith('.') ? host.substring(0, host.length - 1) : host;
    }

    // Defensive fallback for malformed but recoverable tenant references.
    return candidate
        .replaceFirst(RegExp(r'^https?://', caseSensitive: false), '')
        .split(RegExp(r'[/#?]'))
        .first
        .split(':')
        .first
        .trim()
        .toLowerCase();
  }

  static List<String?> _fragmentTenantValues(String fragment) {
    final queryIndex = fragment.indexOf('?');
    if (queryIndex < 0 || queryIndex == fragment.length - 1) {
      return const [];
    }
    try {
      final parameters = Uri.splitQueryString(fragment.substring(queryIndex + 1));
      return [
        parameters['tenantId'],
        parameters['tenant_id'],
        parameters['tenant'],
      ];
    } catch (_) {
      return const [];
    }
  }

  static String _firstNonBlank(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }
}
