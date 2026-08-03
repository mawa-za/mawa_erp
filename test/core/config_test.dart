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

  group('Config.resolveWebTenantReference', () {
    test('does not treat a shared environment host as a tenant', () {
      expect(
        Config.resolveWebTenantReference(
          'https://dev.app.mawa.co.za/#/login',
        ),
        isEmpty,
      );
    });

    test('uses an explicit tenant id from the URL', () {
      expect(
        Config.resolveWebTenantReference(
          'https://dev.app.mawa.co.za/?tenantId=ff8080818aa2c02c018aa2c3eb500003#/login',
        ),
        'ff8080818aa2c02c018aa2c3eb500003',
      );
    });

    test('uses an explicit tenant id from a Flutter hash route', () {
      expect(
        Config.resolveWebTenantReference(
          'https://dev.app.mawa.co.za/#/login?tenant=tenant-123',
        ),
        'tenant-123',
      );
    });

    test('uses a tenant host alias from an Admin handoff route', () {
      expect(
        Config.resolveWebTenantReference(
          'https://dev.app.mawa.co.za/#/admin-handoff?tenantHost=dev1.app.mawa.co.za',
        ),
        'dev1.app.mawa.co.za',
      );
    });

    test('keeps a tenant-specific hostname', () {
      expect(
        Config.resolveWebTenantReference(
          'https://phanka.dev.app.mawa.co.za/#/login',
        ),
        'phanka.dev.app.mawa.co.za',
      );
    });
  });
}
