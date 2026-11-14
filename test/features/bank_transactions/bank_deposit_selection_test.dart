import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/bank_transactions/bank_transaction_service.dart';
import 'package:mawa_erp/features/bank_transactions/widgets/bank_deposit_id_field.dart';

void main() {
  const credit = BankTransaction(
    depositId: 'DEP-00000123', transactionId: 'TXN-00000123',
    date: '2026-11-14', amountCents: 100000, availableCents: 50000,
    reference: 'PREMIUM-AB123', accountNumber: '1234567890', status: 'PARTIAL',
  );
  const debit = BankTransaction(
    depositId: null, transactionId: 'TXN-00000124',
    date: '2026-11-14', amountCents: -25000, availableCents: 0,
    reference: 'PREMIUM-AB123', accountNumber: '1234567890', status: 'DEBIT',
  );
  const spentCredit = BankTransaction(
    depositId: 'DEP-00000125', transactionId: 'TXN-00000125',
    date: '2026-11-14', amountCents: 50000, availableCents: 0,
    reference: 'PREMIUM-AB123', accountNumber: '1234567890', status: 'ALLOCATED',
  );

  test('Deposit lookup requires five trimmed characters', () {
    expect(BankTransactionService.canSearchDepositCredits(null), isFalse);
    expect(BankTransactionService.canSearchDepositCredits(''), isFalse);
    expect(BankTransactionService.canSearchDepositCredits('ABCD'), isFalse);
    expect(BankTransactionService.canSearchDepositCredits('  ABCD  '), isFalse);
    expect(BankTransactionService.canSearchDepositCredits('ABCDE'), isTrue);
    expect(BankTransactionService.canSearchDepositCredits('  DEP-00000123  '), isTrue);
  });

  testWidgets('Deposit field is read-only and searches only after five characters', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final searched = <String>[];
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Form(
      child: BankDepositIdField(
        controller: controller, isRequired: true,
        lookupCredits: (query) async {
          searched.add(query);
          return const BankTransactionsPage([credit, debit, spentCredit], true);
        },
      ),
    ))));

    final depositTextField = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(depositTextField.readOnly, isTrue);
    await tester.tap(find.byType(TextFormField).first);
    await tester.pumpAndSettle();
    expect(find.text('Find bank Deposit ID'), findsOneWidget);

    final searchButton = find.byTooltip('Search available credits');
    await tester.enterText(find.byType(TextField).last, 'ABCD');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(searchButton).onPressed, isNull);
    expect(searched, isEmpty);
    expect(find.byType(ListTile), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'PREMI');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(searchButton).onPressed, isNotNull);
    await tester.tap(searchButton);
    await tester.pumpAndSettle();
    expect(searched, ['PREMI']);
    expect(find.byType(ListTile), findsOneWidget); // debit and spent credit excluded

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();
    expect(controller.text, 'DEP-00000123');
  });

  testWidgets('Editing the search query clears previous matching credits', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BankDepositIdField(
      controller: controller, isRequired: false,
      lookupCredits: (query) async => const BankTransactionsPage([credit], true),
    ))));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'PREMI');
    await tester.tap(find.byTooltip('Search available credits'));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'X');
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(controller.text, isEmpty);
  });

  testWidgets('Delayed results for an old query cannot repopulate the picker', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final deferred = Completer<BankTransactionsPage>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: BankDepositIdField(
      controller: controller, isRequired: true,
      lookupCredits: (_) => deferred.future,
    ))));
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'PREMI');
    await tester.tap(find.byTooltip('Search available credits'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'OTHER');
    deferred.complete(const BankTransactionsPage([credit], true));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
}
