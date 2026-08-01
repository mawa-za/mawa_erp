import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../approvals/models/approval.dart';
import '../../approvals/services/approval_service.dart';
import '../models/leave_request.dart';
import '../services/leave_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const LeaveRequestDetailScreen({super.key, required this.requestId});

  @override
  State<LeaveRequestDetailScreen> createState() => _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  final _service = LeaveService();
  final _approvalService = ApprovalService();

  bool _isLoading = true;
  bool _isActionLoading = false;
  LeaveRequest? _request;
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
      final request = await _service.getLeaveRequestById(widget.requestId);
      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = friendlyErrorMessage(e);
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submitForApproval() async {
    if (_request == null) return;
    setState(() => _isActionLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final submission = ApprovalSubmission(
        approvalType: 'LEAVE',
        referenceId: _request!.id,
        referenceNo: '${_request!.employeeName ?? _request!.employeeId} | ${_request!.startDate}',
        title: '${_request!.type} leave - ${_request!.employeeName ?? _request!.employeeId} - ${_request!.startDate} to ${_request!.endDate}',
        description: 'Approval requested for ${_request!.days} day(s) from ${_request!.startDate} to ${_request!.endDate} for ${_request!.employeeName ?? _request!.employeeId}',
        requesterId: userId,
        payloadJson: jsonEncode({
          ..._request!.toJson(),
          'employeeName': _request!.employeeName,
          'approverName': _request!.approverName,
          'leaveRequestId': _request!.id,
          'attachmentObjectIds': [_request!.id],
        }),
      );

      await _approvalService.submitApproval(submission);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted for approval'), backgroundColor: Colors.green),
        );
        _fetchDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed: $e')), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Leave Request Details'),
        actions: [
          if (_request != null && _request!.status == 'PENDING')
            IconButton(
              icon: _isActionLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.send_rounded),
              onPressed: _isActionLoading ? null : _submitForApproval,
              tooltip: 'Submit for Approval',
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetails),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorWidget()
              : _buildContent(colorScheme),
    );
  }

  Widget _buildContent(ColorScheme colorScheme) {
    final request = _request!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusHeader(request, colorScheme),
        const SizedBox(height: 16),
        _buildInfoCard(colorScheme),
        const SizedBox(height: 16),
        _buildPersonnelCard(colorScheme),
      ],
    );
  }

  Widget _buildStatusHeader(LeaveRequest request, ColorScheme colorScheme) {
    Color color;
    switch (request.status.toUpperCase()) {
      case 'APPROVED': color = Colors.green; break;
      case 'REJECTED': color = Colors.red; break;
      case 'PENDING': color = Colors.orange; break;
      case 'AWAITING-APPROVAL': color = Colors.deepOrange; break;
      default: color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            request.status.toUpperCase(),
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            '${request.days} Day(s) - ${request.type}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ColorScheme colorScheme) {
    final request = _request!;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TIME OFF PERIOD', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Divider(),
            _buildDetailRow('Start Date', request.startDate),
            _buildDetailRow('End Date', request.endDate),
            _buildDetailRow('Total Days', '${request.days}'),
            _buildDetailRow('Created At', request.createdAt ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelCard(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PERSONNEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const Divider(),
            _buildDetailRow('Employee', _request!.employeeName ?? _request!.employeeId),
            _buildDetailRow('Approver', _request!.approverName ?? _request!.approverId ?? 'Not Assigned'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          ElevatedButton(onPressed: _fetchDetails, child: const Text('Retry')),
        ],
      ),
    );
  }
}
