import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/bank_transactions/bank_transaction_service.dart';

void main() {
  test('Deposit ID is optional during transition but supplied IDs are validated', () {
    expect(BankTransactionService.depositIdAccepted(null, isRequired: false), isTrue);
    expect(BankTransactionService.depositIdAccepted('', isRequired: false), isTrue);
    expect(BankTransactionService.depositIdAccepted('DEP-00000162', isRequired: false), isTrue);
    expect(BankTransactionService.depositIdAccepted('garbage', isRequired: false), isFalse);
    expect(BankTransactionService.depositIdAccepted('', isRequired: true), isFalse);
    expect(BankTransactionService.depositIdAccepted('dep-162', isRequired: true), isTrue);
  });
}
