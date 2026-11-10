import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/utils/app_date_utils.dart';
import 'package:mawa_erp/features/bank_transactions/bank_transaction_service.dart';

void main() {
  final transactionJson = <String, dynamic>{
    'depositId': 'DEP-00000165',
    'date': [2026, 11, 9],
    'amountCents': 109000,
    'availableCents': 109000,
    'reference': 'SPEEDPOINT',
    'accountNumber': '00000000000062854070077',
    'status': 'AVAILABLE',
  };

  test('converts Java LocalDate arrays into canonical API dates', () {
    final transaction = BankTransaction.fromJson(transactionJson);
    expect(transaction.date, '2026-11-09');
    expect(AppDateUtils.displayDate(transaction.date), '09 Nov 2026');
  });

  test('shows the same date format for ISO dates and selected filter dates', () {
    final transaction = BankTransaction.fromJson({
      ...transactionJson,
      'date': '2026-11-07',
    });
    expect(AppDateUtils.displayDate(transaction.date), '07 Nov 2026');
    expect(AppDateUtils.displayDate(DateTime(2026, 11, 9)), '09 Nov 2026');
  });

  test('handles an absent bank transaction date without displaying brackets', () {
    final transaction = BankTransaction.fromJson({
      ...transactionJson,
      'date': null,
    });
    expect(AppDateUtils.displayDate(transaction.date), 'N/A');
  });
}
