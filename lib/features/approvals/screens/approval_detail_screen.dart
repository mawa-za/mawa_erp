import 'package:flutter/material.dart';
import '../models/approval.dart';
import '../services/approval_service.dart';

class ApprovalDetailScreen extends StatefulWidget {
  final Approval approval;

  const ApprovalDetailScreen({super.key, required this.approval});

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  final ApprovalService _service = ApprovalService();
  late Approval _approval;
  List<ApprovalAction> _auditTrail = [];
  bool _isLoading = false;
  bool _isLoadingAudit = true;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _approval = widget.approval;
    _fetchAuditTrail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchAuditTrail() async {
    try {
      final audit = await _service.getAuditTrail(_approval.id);
      if (mounted) {
        setState(() {
          _auditTrail = audit;
          _isLoadingAudit = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAudit = false);
      }
      debugPrint('Error fetching audit trail: $e');
    }
  }

  Future<void> _takeAction(String action) async {
    setState(() => _isLoading = true);
    try {
      Approval updated;
      final comment = _commentController.text.trim();
      
      switch (action.toUpperCase()) {
        case 'APPROVE':
          updated = await _service.approve(_approval.id, comments: comment);
          break;
        case 'REJECT':
          updated = await _service.reject(_approval.id, comments: comment);
          break;
        case 'CANCEL':
          updated = await _service.cancel(_approval.id, comments: comment);
          break;
        default:
          throw Exception('Unknown action: $action');
      }

      if (mounted) {
        setState(() {
          _approval = updated;
          _isLoading = false;
          _commentController.clear();
        });
        _fetchAuditTrail(); // Refresh audit trail
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action $action performed successfully')),
        );
        // Optionally pop if approved/rejected/cancelled fully
        if (_approval.status != 'PENDING' && _approval.status != 'IN_PROGRESS') {
           // Navigator.pop(context, true); 
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Approval Details'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(colorScheme),
                const SizedBox(height: 16),
                _buildDetailsCard(),
                const SizedBox(height: 16),
                _buildAuditTrailCard(),
                const SizedBox(height: 16),
                if (_approval.payloadJson != null) _buildPayloadCard(),
                const SizedBox(height: 24),
                if (_approval.status == 'PENDING' || _approval.status == 'IN_PROGRESS') 
                  _buildActionSection(colorScheme),
              ],
            ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBadge(_approval.status, _getStatusColor(_approval.status)),
                Text(
                  _approval.createdAt.split('T')[0],
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _approval.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _approval.description,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard() {
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
            const Text('INFORMATION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const Divider(),
            _buildDetailRow('Reference No', _approval.referenceNo),
            _buildDetailRow('Type', _approval.approvalType),
            _buildDetailRow('Requester ID', _approval.requesterId),
            _buildDetailRow('Workflow Step', 'Step ${_approval.currentStepNo}'),
            if (_approval.finalActionBy != null) _buildDetailRow('Processed By', _approval.finalActionBy!),
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailCard() {
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
            const Text('AUDIT TRAIL', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const Divider(),
            if (_isLoadingAudit)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_auditTrail.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No history found', style: TextStyle(color: Colors.grey, fontSize: 12)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _auditTrail.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 40),
                itemBuilder: (context, index) {
                  final action = _auditTrail[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: _getActionColor(action.action).withOpacity(0.1),
                      child: Icon(_getActionIcon(action.action), size: 18, color: _getActionColor(action.action)),
                    ),
                    title: Row(
                      children: [
                        Text(action.action, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const Spacer(),
                        Text(action.actionAt.split('T')[0], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By: ${action.actionBy}', style: const TextStyle(fontSize: 12)),
                        if (action.comments != null && action.comments!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Comment: ${action.comments}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayloadCard() {
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
            const Text('PAYLOAD DATA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const Divider(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _approval.payloadJson ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('YOUR ACTION', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            hintText: 'Add a comment (optional)...',
            border: OutlineInputBorder(),
            fillColor: Colors.white,
            filled: true,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _takeAction('REJECT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: FilledButton(
                onPressed: () => _takeAction('APPROVE'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => _takeAction('CANCEL'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text('CANCEL REQUEST'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'PENDING':
      case 'IN_PROGRESS':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      case 'SUBMITTED':
        return Colors.blue;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'SUBMITTED':
        return Icons.send_outlined;
      case 'CANCELLED':
        return Icons.block_outlined;
      default:
        return Icons.comment_outlined;
    }
  }
}
