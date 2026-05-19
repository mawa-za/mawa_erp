import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import '../models/cashup.dart';
import '../services/cashup_service.dart';

class CashupDetailScreen extends StatefulWidget {
  final String cashupId;
  const CashupDetailScreen({super.key, required this.cashupId});

  @override
  State<CashupDetailScreen> createState() => _CashupDetailScreenState();
}

class _CashupDetailScreenState extends State<CashupDetailScreen> {
  final CashupService _cashupService = CashupService();
  final UserService _userService = UserService();
  final ApprovalService _approvalService = ApprovalService();
  
  Cashup? _cashup;
  String? _userName;
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final cashup = await _cashupService.getCashupById(widget.cashupId);
      
      // Fetch user name
      String? userName;
      try {
        final user = await _userService.getUser(cashup.userId);
        userName = user.displayName ?? user.username;
      } catch (e) {
        debugPrint('Error fetching user ${cashup.userId}: $e');
      }

      setState(() {
        _cashup = cashup;
        _userName = userName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitForApproval() async {
    if (_cashup == null) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Cashup'),
        content: const Text('Are you sure you want to submit this cashup for verification?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SUBMIT')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final submission = ApprovalSubmission(
        approvalType: 'CASHUP',
        referenceId: _cashup!.id,
        referenceNo: _cashup!.cashupNo.toString(),
        title: 'Cashup Verification: #${_cashup!.cashupNo}',
        description: 'Verification requested for R ${_cashup!.totalAmount.toStringAsFixed(2)} collected on ${_cashup!.cashupDate} by ${_userName ?? _cashup!.userId}',
        requesterId: userId,
        payloadJson: jsonEncode(_cashup!.toJson()),
      );

      await _approvalService.submitApproval(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cashup submitted for approval successfully'), backgroundColor: Colors.green),
        );
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_cashup != null ? 'Cashup #${_cashup!.cashupNo}' : 'Cashup Details'),
        actions: [
          if (_cashup != null && (_cashup!.status == 'NEW' || _cashup!.status == 'DRAFT'))
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: _isSubmitting ? null : _submitForApproval,
                icon: _isSubmitting 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 18),
                label: const Text('SUBMIT'),
                style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget(colorScheme)
              : _buildContent(colorScheme),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load cashup details', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _fetchDetails, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final cashup = _cashup!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryHeader(cashup, colorScheme),
          const SizedBox(height: 16),
          _buildInfoSection(cashup),
          const SizedBox(height: 16),
          _buildPaymentsSection(cashup, colorScheme),
          const SizedBox(height: 16),
          AttachmentSection(
            objectId: widget.cashupId,
            documentTypeField: 'DOCUMENT-TYPE-CASHUP',
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(Cashup cashup, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withBlue(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('Total Collected', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            'R ${cashup.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cashup.status.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Cashup cashup) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CASHUP INFORMATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.numbers_outlined, 'Cashup Number', cashup.cashupNo.toString()),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.event_available, 'Date', cashup.cashupDate),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.devices_outlined, 'Device ID', cashup.deviceId),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_outline, 'User', _userName ?? cashup.userId),
            if (_userName != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(Icons.badge_outlined, 'User ID', cashup.userId),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(Icons.receipt_long_outlined, 'Receipt Count', cashup.receiptCount.toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
      ],
    );
  }

  Widget _buildPaymentsSection(Cashup cashup, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('PAYMENT BREAKDOWN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        ),
        ...cashup.payments.map((p) => Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              child: Icon(Icons.payments_outlined, color: colorScheme.primary, size: 20),
            ),
            title: Text(p.paymentMethod, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('${p.paymentCount} payments'),
            trailing: Text(
              'R ${p.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16),
            ),
          ),
        )),
      ],
    );
  }
}
