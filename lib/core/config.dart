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
    if (kIsWeb) {
      final host = Uri.base.host;
      if (host.contains('localhost')) {
        return 'dev.app.mawa.co.za';
      }
      final parts = host.split('.');
      if (parts.isNotEmpty) {
        return parts[0];
      }
    }
    return '';
  }
}
