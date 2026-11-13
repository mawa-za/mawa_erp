import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/bank_transactions/bank_transaction_service.dart';

void main() {
  Map<String, dynamic> row({required int cents, String? depositId,
      String? transactionId}) => {
    'depositId': depositId,
    if (transactionId != null) 'transactionId': transactionId,
    'date': '2026-11-12',
    'amountCents': cents,
    'availableCents': cents > 0 ? cents : 0,
    'reference': cents > 0 ? 'PREMIUM PAYMENT' : 'CLAIM PAYOUT',
    'accountNumber': '1234567890',
    'status': cents > 0 ? 'AVAILABLE' : 'DEBIT',
  };

  test('positive bank credits display stable Deposit ID', () {
    final bank = BankTransaction.fromJson(row(cents: 10000,
      depositId: 'DEP-00000123', transactionId: 'TXN-00000123'));
    expect(bank.isCredit, isTrue);
    expect(bank.depositId, 'DEP-00000123');
    expect(bank.displayId, 'DEP-00000123');
    expect(bank.transactionId, 'TXN-00000123');
  });

  test('outgoing debits show TXN- and never expose an allocatable Deposit ID', () {
    final bank = BankTransaction.fromJson(row(cents: -25000,
      depositId: null, transactionId: 'TXN-00000124'));
    expect(bank.isCredit, isFalse);
    expect(bank.depositId, isNull);
    expect(bank.displayId, 'TXN-00000124');
  });

  test('zero-value history row is not a deposit', () {
    final bank = BankTransaction.fromJson(row(cents: 0,
      transactionId: 'TXN-00000125'));
    expect(bank.isCredit, isFalse);
    expect(bank.depositId, isNull);
    expect(bank.displayId, 'TXN-00000125');
  });

  test('rolling deployment hides legacy DEP- label on debit rows', () {
    final bank = BankTransaction.fromJson(row(cents: -25000,
      depositId: 'DEP-00000124'));
    expect(bank.depositId, isNull);
    expect(bank.transactionId, 'TXN-00000124');
    expect(bank.displayId, 'TXN-00000124');
  });

  test('legacy credits retain their Deposit ID when transactionId is absent', () {
    final bank = BankTransaction.fromJson(row(cents: 10000,
      depositId: 'DEP-00000123'));
    expect(bank.depositId, 'DEP-00000123');
    expect(bank.transactionId, 'TXN-00000123');
    expect(bank.displayId, 'DEP-00000123');
  });

  test('debit transaction identifiers cannot pass deposit input validation', () {
    expect(BankTransactionService.depositIdAccepted('TXN-00000124', isRequired: true), isFalse);
    expect(BankTransactionService.depositIdAccepted('DEP-00000123', isRequired: true), isTrue);
    expect(BankTransactionService.depositIdAccepted('', isRequired: false), isTrue);
  });
}
