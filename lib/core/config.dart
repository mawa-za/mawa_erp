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
      final url = Uri.base.toString();
      if (url.contains('localhost') || url.contains('127.0.0.1')) {
        return 'localhost';
      }
      
      // Returns the whole URL excluding the protocol and trailing slash
      return url
          .replaceFirst(RegExp(r'^https?://'), '')
          .replaceFirst(RegExp(r'/$'), '');
    }
    return '';
  }
}
