import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/config.dart';

void main() {
  group('Config.normalizeTenantReference', () {
    test('extracts host from Flutter web hash route', () {
      expect(
        Config.normalizeTenantReference(
          'https://dev.app.mawa.co.za/#/login',
        ),
        'dev.app.mawa.co.za',
      );
    });

    test('normalizes a host and hash route without a scheme', () {
      expect(
        Config.normalizeTenantReference('dev.app.mawa.co.za/#/login'),
        'dev.app.mawa.co.za',
      );
    });

    test('removes port and normalizes case', () {
      expect(
        Config.normalizeTenantReference('HTTPS://DEV.APP.MAWA.CO.ZA:443'),
        'dev.app.mawa.co.za',
      );
    });
  });
}
