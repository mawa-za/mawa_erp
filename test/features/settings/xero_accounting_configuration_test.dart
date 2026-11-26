import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/settings/services/xero_integration_service.dart';

Map<String, dynamic> response({Map<String, dynamic>? mapping}) => {
  'options': {
    'organisationId': 'org-a',
    'invoiceAccounts': [
      {'accountId': 'sales-a', 'code': '410', 'name': 'Service revenue', 'type': 'REVENUE'},
    ],
    'paymentAccounts': [
      {'accountId': 'bank-a', 'code': '1133640', 'name': 'Bank', 'type': 'BANK'},
    ],
    'taxRates': [
      {'taxType': 'OUTPUT', 'name': 'Sales VAT', 'displayRate': 15},
    ],
  },
  'mapping': mapping,
  'legacyInvoiceAccountCode': '200',
  'legacyPaymentAccountCode': '1133640',
  'mappingValid': false,
  'invoiceIntegrationEnabled': false,
};

void main() {
  test('only existing legacy account codes are suggested; no guessed account or tax', () {
    final config = XeroAccountingConfiguration.fromJson(response());
    expect(config.invoiceAccountId, isNull);
    expect(config.paymentAccountId, 'bank-a');
    expect(config.invoiceTaxType, isNull);
    expect(config.invoiceAccounts.single.label, contains('410'));
  });
  test('saved mapping from another organisation is never preselected', () {
    final config = XeroAccountingConfiguration.fromJson(response(mapping: {
      'organisationId': 'org-b', 'invoiceAccountId': 'sales-a',
      'paymentAccountId': 'bank-a', 'invoiceTaxType': 'OUTPUT',
    }));
    expect(config.invoiceAccountId, isNull);
    expect(config.paymentAccountId, isNull);
    expect(config.invoiceTaxType, isNull);
  });
  test('saved organisation-bound identifiers are selected only when present', () {
    final config = XeroAccountingConfiguration.fromJson(response(mapping: {
      'organisationId': 'org-a', 'invoiceAccountId': 'sales-a',
      'paymentAccountId': 'bank-a', 'invoiceTaxType': 'OUTPUT',
    }));
    expect(config.invoiceAccountId, 'sales-a');
    expect(config.paymentAccountId, 'bank-a');
    expect(config.invoiceTaxType, 'OUTPUT');
  });
}
