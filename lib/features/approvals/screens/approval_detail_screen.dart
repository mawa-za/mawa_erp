import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../invoicing/screens/invoice_detail_screen.dart';
import '../../membership/screens/membership_claim_detail_screen.dart';
import '../../membership/screens/membership_detail_screen.dart';
import '../../payments/screens/payment_request_detail_screen.dart';
import '../../cashup/screens/cashup_detail_screen.dart';
import '../../leave_requests/screens/leave_request_detail_screen.dart';
import '../../payroll/screens/payroll_batch_detail_screen.dart';
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
  final UserService _userService = UserService();
  late Approval _approval;
  List<ApprovalAction> _auditTrail = [];
  bool _isLoading = false;
  bool _isLoadingAudit = true;
  final _commentController = TextEditingController();
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _approval = widget.approval;
    _resolveInitialNames();
    _fetchAuditTrail();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _resolveInitialNames() {
    _resolveUserName(_approval.requesterId);
    if (_approval.finalActionBy != null) {
      _resolveUserName(_approval.finalActionBy!);
    }
  }

  Future<void> _resolveUserName(String userId) async {
    if (userId.isEmpty || _userNameCache.containsKey(userId)) return;
    try {
      final user = await _userService.getUser(userId);
      if (mounted) {
        setState(() {
          _userNameCache[userId] = user.displayName ?? user.username;
        });
      }
    } catch (e) {
      debugPrint('Error resolving user $userId: $e');
    }
  }

  String _getDisplayName(String id) {
    if (_userNameCache.containsKey(id)) {
      return _userNameCache[id]!;
    }
    // If it's a UUID, show a shortened version while loading
    if (id.length > 20 && id.contains('-')) {
      return 'ID: ${id.split('-').first}...';
    }
    return id;
  }

  Future<void> _fetchAuditTrail() async {
    try {
      final audit = await _service.getAuditTrail(_approval.id);
      if (mounted) {
        setState(() {
          _auditTrail = audit;
          _isLoadingAudit = false;
        });
        for (var action in audit) {
          _resolveUserName(action.actionBy);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAudit = false);
      }
      debugPrint('Error fetching audit trail: $e');
    }
  }

  void _viewOriginalTransaction() {
    final id = _approval.referenceId;
    final type = _approval.approvalType.toUpperCase();

    Widget? screen;
    switch (type) {
      case 'INVOICE':
        screen = InvoiceDetailScreen(invoiceId: id);
        break;
      case 'CLAIM':
        screen = MembershipClaimDetailScreen(claimId: id);
        break;
      case 'PAYMENT':
        screen = PayrollBatchDetailScreen(batchId: id);
        break;
      case 'PAYMENT_REQUEST':
        screen = PaymentRequestDetailScreen(paymentId: id);
        break;
      case 'CASHUP':
        screen = CashupDetailScreen(cashupId: id);
        break;
      case 'MEMBERSHIP_TRANSFER':
      case 'MEMBERSHIP_PLAN_CHANGE':
        final membershipId = _membershipIdFromPayload();
        if (membershipId != null) {
          screen = MembershipDetailScreen(membershipId: membershipId);
        }
        break;
      case 'LEAVE':
        screen = LeaveRequestDetailScreen(requestId: id);
        break;
    }

    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen!));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail screen for this type is not yet implemented')),
      );
    }
  }

  String? _membershipIdFromPayload() {
    final payload = _approval.payloadJson;
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map && decoded['membershipId'] != null) {
        final value = decoded['membershipId'].toString().trim();
        return value.isEmpty ? null : value;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _takeAction(String action) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${action[0]}${action.substring(1).toLowerCase()} Request', 
            style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        content: Text('Confirm your decision to $action this approval request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: action == 'APPROVE' ? const Color(0xFF10B981) : (action == 'REJECT' ? const Color(0xFFEF4444) : const Color(0xFF334155)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      Approval updated;
      final comment = _commentController.text.trim();
      
      switch (action.toUpperCase()) {
        case 'APPROVE':
          updated = await _service.approve(_approval.id, comments: comment, actionBy: userId);
          break;
        case 'REJECT':
          updated = await _service.reject(_approval.id, comments: comment, actionBy: userId);
          break;
        case 'CANCEL':
          updated = await _service.cancel(_approval.id, comments: comment, actionBy: userId);
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
        _resolveInitialNames();
        _fetchAuditTrail(); 
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Action $action completed successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Review Workflow', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 20, color: Color(0xFF64748B)),
            onPressed: _viewOriginalTransaction,
            tooltip: 'View Original Source',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF20D1A)))
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroHeader(),
                        const SizedBox(height: 16),
                        _buildIdentificationSheet(),
                        const SizedBox(height: 16),
                        _buildAttachmentSection(),
                        const SizedBox(height: 16),
                        _buildActivityLogSection(),
                        const SizedBox(height: 32),
                        if (_approval.status == 'PENDING' || _approval.status == 'IN_PROGRESS' || _approval.status == 'PENDING_APPROVAL') 
                          _buildActionDecisionCard(),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeroHeader() {
    final statusColor = _getStatusColor(_approval.status);
    final typeColor = _getTypeColor(_approval.approvalType);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildModernBadge(_approval.status, statusColor),
              Text(
                _formatFullDate(_approval.createdAt),
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _approval.title,
                      style: const TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.w900, 
                        color: Color(0xFF0F172A), 
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _approval.approvalType.replaceAll('_', ' '),
                      style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _approval.description,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 16, height: 1.5, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              _buildMiniIndicator(Icons.tag_rounded, _approval.referenceNo),
              const SizedBox(width: 16),
              _buildMiniIndicator(Icons.account_tree_outlined, 'Step ${_approval.currentStepNo}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(100), 
        border: Border.all(color: color.withOpacity(0.3), width: 1)
      ),
      child: Text(text.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 0.8)),
    );
  }

  Widget _buildMiniIndicator(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildIdentificationSheet() {
    return _buildSectionLayout(
      title: 'IDENTIFICATION',
      icon: Icons.fingerprint_rounded,
      child: Column(
        children: [
          _buildInfoRow('Reference', '${_approval.referenceNo} (${_approval.referenceId})'),
          _buildInfoRow('Requester', _getDisplayName(_approval.requesterId)),
          _buildInfoRow('Workflow Step', 'Step ${_approval.currentStepNo}'),
          if (_approval.finalActionBy != null)
            _buildInfoRow('Processed By', _getDisplayName(_approval.finalActionBy!)),
          const Divider(height: 24, color: Color(0xFFF1F5F9)),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _viewOriginalTransaction,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('VIEW SOURCE TRANSACTION', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFF20D1A),
                side: const BorderSide(color: Color(0xFFF20D1A)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildAttachmentSection() {
    return _buildSectionLayout(
      title: 'EVIDENCE & DOCUMENTS',
      icon: Icons.attach_file_rounded,
      child: AttachmentSection(
        objectId: _approval.referenceId,
        readOnly: true,
      ),
    );
  }

  Widget _buildActivityLogSection() {
    return _buildSectionLayout(
      title: 'ACTIVITY LOG',
      icon: Icons.history_rounded,
      child: _isLoadingAudit
          ? const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              children: _auditTrail.map((action) => _buildTimelineStep(action, action == _auditTrail.last)).toList(),
            ),
    );
  }

  Widget _buildTimelineStep(ApprovalAction action, bool isLast) {
    final color = _getActionColor(action.action);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 1, color: const Color(0xFFE2E8F0), margin: const EdgeInsets.symmetric(vertical: 4)),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(action.action, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1E293B))),
                      const Spacer(),
                      Text(_formatShortDate(action.actionAt), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text('by ${_getDisplayName(action.actionBy)}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                  if (action.comments != null && action.comments!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Text(action.comments!, style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF334155), height: 1.4)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionDecisionCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF20D1A).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF20D1A).withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DECISION HUB', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFF20D1A), fontSize: 11, letterSpacing: 1.5)),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Add an optional comment for the audit log...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _takeAction('REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('REJECT', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => _takeAction('APPROVE'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('APPROVE', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton(
              onPressed: () => _takeAction('CANCEL'), 
              child: const Text('WITHDRAW REQUEST', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLayout({required String title, required IconData icon, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF0F172A)),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 11, letterSpacing: 1.0)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
          child,
        ],
      ),
    );
  }

  String _formatShortDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('MMM d, HH:mm').format(dt);
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  String _formatFullDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy').format(dt);
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED': return const Color(0xFF059669);
      case 'REJECTED': return const Color(0xFFDC2626);
      case 'PENDING':
      case 'PENDING_APPROVAL':
      case 'IN_PROGRESS': return const Color(0xFFD97706);
      case 'CANCELLED': return const Color(0xFF64748B);
      default: return const Color(0xFF2563EB);
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'INVOICE': return const Color(0xFF0891B2);
      case 'CLAIM': return const Color(0xFF7C3AED);
      case 'PAYMENT': return const Color(0xFF2563EB);
      case 'PAYMENT_REQUEST': return const Color(0xFFF20D1A);
      case 'CASHUP': return const Color(0xFFEA580C);
      case 'LEAVE': return const Color(0xFFDB2777);
      default: return const Color(0xFF475569);
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVED': return const Color(0xFF059669);
      case 'REJECTED': return const Color(0xFFDC2626);
      case 'SUBMITTED': return const Color(0xFF2563EB);
      case 'CANCELLED': return const Color(0xFF64748B);
      default: return const Color(0xFFD97706);
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'APPROVED': return Icons.check_circle_rounded;
      case 'REJECTED': return Icons.cancel_rounded;
      case 'SUBMITTED': return Icons.send_rounded;
      case 'CANCELLED': return Icons.block_rounded;
      default: return Icons.comment_rounded;
    }
  }
}
