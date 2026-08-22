import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/cashup/models/cashup.dart';

void main() {
  Cashup cashupWithSource(String source) => Cashup(
        id: 'cashup-1',
        cashupNo: 1001,
        deviceId: 'device-1',
        userId: 'cashier-1',
        cashierName: 'Cashier',
        cashupDate: '2026-08-22',
        totalCents: 10000,
        receiptCount: 1,
        status: 'OPEN',
        source: source,
        receiptBookNo: '',
        receiptFromNo: '',
        receiptToNo: '',
        manualAmountCents: 0,
        receiptTotalCents: 10000,
        varianceCents: 0,
        employeeResponsibleId: '',
        employeeResponsibleName: '',
        areaCode: '',
        areaName: '',
        depositTotalCents: 0,
        depositCount: 0,
        approvalRequestId: null,
        payments: const [],
        deposits: const [],
      );

  test('normal ERP cashups including Card require deposits', () {
    final cashup = cashupWithSource('ERP_ONLINE');

    expect(cashup.isIndividualEftCashup, isFalse);
    expect(cashup.depositRequired, isTrue);
  });

  test('ERP and MawaPay EFT cashups are deposit exempt', () {
    for (final source in ['ERP_ONLINE_EFT', 'MAWA_PAY_EFT']) {
      final cashup = cashupWithSource(source);
      expect(cashup.isIndividualEftCashup, isTrue);
      expect(cashup.depositRequired, isFalse);
    }
  });
}
