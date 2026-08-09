import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/config.dart';

void main() {
  test('derives reporting host from transactional API host', () {
    expect(
      Config.reportingHostFromApiHost('dev.api.app.mawa.co.za'),
      'dev.reports.api.app.mawa.co.za',
    );
    expect(
      Config.reportingHostFromApiHost('api.app.mawa.co.za'),
      'reports.api.app.mawa.co.za',
    );
  });
}
