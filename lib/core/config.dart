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

  static String get webTenant {
    if (!kIsWeb) return '';
    return normalizeTenantReference(Uri.base.toString());
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
}
