import 'dart:convert';

import 'package:flutter/material.dart';

import '../../cashup/screens/cashup_detail_screen.dart';
import '../../invoicing/screens/invoice_detail_screen.dart';
import '../../laybys/screens/layby_management_screen.dart';
import '../../leave_requests/screens/leave_request_detail_screen.dart';
import '../../membership/screens/membership_claim_detail_screen.dart';
import '../../membership/screens/membership_detail_screen.dart';
import '../../payments/screens/payment_request_detail_screen.dart';
import '../../payroll/screens/payroll_batch_detail_screen.dart';
import '../models/approval.dart';

class ApprovalItemNavigator {
  const ApprovalItemNavigator._();

  static Future<bool> openOriginal(BuildContext context, Approval approval) async {
    final screen = _screenFor(approval);
    if (screen == null) return false;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return true;
  }

  static Widget? _screenFor(Approval approval) {
    final id = approval.referenceId;
    final type = approval.approvalType.toUpperCase();

    switch (type) {
      case 'INVOICE':
        return InvoiceDetailScreen(invoiceId: id);
      case 'CLAIM':
      case 'CLAIM_CASH':
      case 'CLAIM_TOMBSTONE':
      case 'CLAIM_FUNERAL':
      case 'CLAIM_COMBINATION':
      case 'CLAIM_GROCERY':
        return MembershipClaimDetailScreen(claimId: id);
      case 'PAYMENT':
        return PayrollBatchDetailScreen(batchId: id);
      case 'PAYMENT_REQUEST':
        return PaymentRequestDetailScreen(paymentId: id);
      case 'CASHUP':
        return CashupDetailScreen(cashupId: id);
      case 'MEMBERSHIP_TRANSFER':
      case 'MEMBERSHIP_PLAN_CHANGE':
      case 'MEMBERSHIP_PREMIUM_EDIT':
      case 'MEMBERSHIP_PARTNER_IDENTITY_CORRECTION':
      case 'MEMBERSHIP_DEPENDENT_CHANGE':
      case 'PREMIUM_PAYMENT_DELETION':
        final membershipId = _payloadField(approval.payloadJson, 'membershipId');
        return membershipId == null ? null : MembershipDetailScreen(membershipId: membershipId);
      case 'LAYBY_CANCELLATION':
      case 'LAYBY_REFUND':
        final laybyId = _payloadField(approval.payloadJson, 'laybyId');
        return laybyId == null ? null : LaybyManagementScreen(initialLaybyId: laybyId);
      case 'LEAVE':
        return LeaveRequestDetailScreen(requestId: id);
      default:
        return null;
    }
  }

  static String? _payloadField(String? payload, String fieldName) {
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      return _findStringField(jsonDecode(payload), fieldName);
    } catch (_) {
      return null;
    }
  }

  static String? _findStringField(dynamic value, String fieldName) {
    if (value is Map) {
      final direct = value[fieldName];
      if (direct != null && direct.toString().trim().isNotEmpty) {
        return direct.toString().trim();
      }
      for (final nested in value.values) {
        final found = _findStringField(nested, fieldName);
        if (found != null) return found;
      }
    } else if (value is List) {
      for (final nested in value) {
        final found = _findStringField(nested, fieldName);
        if (found != null) return found;
      }
    }
    return null;
  }
}
