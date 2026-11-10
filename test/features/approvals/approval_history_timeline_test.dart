import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/approvals/models/approval.dart';
import 'package:mawa_erp/features/approvals/widgets/approval_history_section.dart';

void main() {
  final approvedRequest = Approval(
    id: 'approval-1',
    approvalType: 'MEMBERSHIP',
    referenceId: 'membership-1',
    referenceNo: '1000043030',
    title: 'Membership date change - 1000043030',
    description: 'Change membership dates',
    requesterId: 'user-1',
    requesterName: 'Membership Clerk',
    currentStepNo: 1,
    status: 'APPROVED',
    createdAt: '2026-10-27T23:17:00Z',
    updatedAt: '2026-10-28T00:03:00Z',
    finalActionByName: 'Supervisor',
    finalActionAt: '2026-10-28T00:03:00Z',
  );

  testWidgets('timeline displays approval status and audit actors', (tester) async {
    String? requestedReference;
    String? requestedType;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
      child: ApprovalHistorySection(
        referenceId: 'membership-1',
        objectType: 'MEMBERSHIP',
        timeline: true,
        historyLoader: (referenceId, objectType) async {
          requestedReference = referenceId;
          requestedType = objectType;
          return [approvedRequest];
        },
      ),
    ))));
    await tester.pumpAndSettle();

    expect(requestedReference, 'membership-1');
    expect(requestedType, 'MEMBERSHIP');
    expect(find.text('Approval activity'), findsOneWidget);
    expect(find.text('Membership date change - 1000043030'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.textContaining('Membership Clerk'), findsOneWidget);
    expect(find.textContaining('Supervisor'), findsOneWidget);
    expect(find.text('VIEW REQUEST'), findsOneWidget);
  });

  testWidgets('timeline has a useful empty state', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApprovalHistorySection(
      referenceId: 'membership-2',
      timeline: true,
      historyLoader: (_, __) async => <Approval>[],
    ))));
    await tester.pumpAndSettle();
    expect(find.textContaining('No approval requests'), findsOneWidget);
  });

  testWidgets('existing non-timeline variant remains available', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApprovalHistorySection(
      referenceId: 'membership-3',
      historyLoader: (_, __) async => [approvedRequest],
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Approval History'), findsOneWidget);
    expect(find.text('Membership date change - 1000043030'), findsOneWidget);
  });

  testWidgets('timeline exposes a retry when approval history fails', (tester) async {
    var requests = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ApprovalHistorySection(
      referenceId: 'membership-4',
      timeline: true,
      historyLoader: (_, __) async {
        requests++;
        if (requests == 1) throw StateError('Temporary error');
        return [approvedRequest];
      },
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Approval history could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(find.text('Membership date change - 1000043030'), findsOneWidget);
  });

}
