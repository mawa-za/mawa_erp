import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/bank_transactions/bank_history_test_reset_service.dart';

void main() {
  test('reset confirmation must include the exact tenant ID', () {
    expect(BankHistoryTestResetService.confirmationFor('qa-bank-tenant'),
      'RESET BANK HISTORY: qa-bank-tenant');
    expect(BankHistoryTestResetService.confirmationFor('other-tenant'),
      isNot('RESET BANK HISTORY: qa-bank-tenant'));
  });

  test('reset is never confirmed from an absent or blocked preview', () {
    expect(BankHistoryTestResetService.canConfirm(null), isFalse);
    expect(BankHistoryTestResetService.canConfirm({
      'tenantId': 'qa-bank-tenant', 'canReset': false,
      'blockedReason': 'Financial links exist',
    }), isFalse);
    expect(BankHistoryTestResetService.canConfirm({
      'tenantId': 'qa-bank-tenant', 'canReset': true,
    }), isTrue);
  });
}
