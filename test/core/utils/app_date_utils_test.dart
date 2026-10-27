import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/core/utils/app_date_utils.dart';
import 'package:mawa_erp/features/approvals/models/approval.dart';

void main() {
  setUp(() => AppDateUtils.configureTimeZone('Africa/Harare'));

  group('AppDateUtils approval payload formats', () {
    test('shows Java LocalDate values instead of N/A', () {
      expect(AppDateUtils.displayDate('2026-07-08'), '08 Jul 2026');
      expect(AppDateUtils.displayDate('2026-10-08'), '08 Oct 2026');
      expect(AppDateUtils.displayDate('2026-10-05'), '05 Oct 2026');
      expect(AppDateUtils.displayDate('2027-01-08'), '08 Jan 2027');
      expect(AppDateUtils.normalizeDate('2026-10-05'), '2026-10-05');
      expect(AppDateUtils.displayDate('2026-02-30'), 'N/A');
    });

    test('accepts approval createdAt as epoch milliseconds or a numeric string', () {
      const createdAt = 1793135839000;
      for (final value in [createdAt, createdAt.toString()]) {
        expect(
          AppDateUtils.displayDateTimePattern(value, 'dd MMM yyyy, HH:mm'),
          '27 Oct 2026, 23:17',
        );
        expect(AppDateUtils.normalizeDateTime(value),
            '2026-10-27T21:17:19.000Z');
      }
    });

    test('keeps existing ISO datetime and array parsing', () {
      expect(
        AppDateUtils.displayDateTimePattern(
          '2026-10-27T21:17:19.628071892', 'dd MMM yyyy, HH:mm'),
        '27 Oct 2026, 23:17',
      );
      expect(AppDateUtils.displayDate([2026, 10, 8]), '08 Oct 2026');
      expect(AppDateUtils.displayDate('202607'), 'N/A');
    });

    test('approval response preserves saved comparison dates and submission time', () {
      final payload = <String, dynamic>{
        'currentValues': <String, dynamic>{
          'joinDate': '2026-07-08',
          'startDate': '2026-10-08',
          'effectiveDate': '2027-01-08',
        },
        'proposedValues': <String, dynamic>{
          'joinDate': '2026-07-08',
          'startDate': '2026-10-05',
          'effectiveDate': '2027-01-08',
        },
      };
      final approval = Approval.fromJson({
        'id': 'approval-1',
        'approvalType': 'MEMBERSHIP_DATE_CHANGE',
        'referenceId': 'change-1',
        'referenceNo': '1000043030',
        'title': 'Membership date change',
        'description': 'Review the requested changes',
        'requesterId': 'user-1',
        'requesterName': 'Test User',
        'status': 'IN_PROGRESS',
        'currentStepNo': 1,
        'payloadJson': jsonEncode(payload),
        'createdAt': 1793135839000,
      });
      final decoded = jsonDecode(approval.payloadJson!) as Map<String, dynamic>;
      final current = decoded['currentValues'] as Map<String, dynamic>;
      final proposed = decoded['proposedValues'] as Map<String, dynamic>;
      expect(AppDateUtils.displayDate(current['startDate']), '08 Oct 2026');
      expect(AppDateUtils.displayDate(proposed['startDate']), '05 Oct 2026');
      expect(AppDateUtils.displayDate(proposed['effectiveDate']), '08 Jan 2027');
      expect(
        AppDateUtils.displayDateTimePattern(approval.createdAt, 'dd MMM yyyy, HH:mm'),
        '27 Oct 2026, 23:17',
      );
    });
  });
}
