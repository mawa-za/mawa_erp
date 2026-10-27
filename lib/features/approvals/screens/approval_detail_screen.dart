import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/models/user.dart';
import '../../../core/services/user_service.dart';
import '../../../core/utils/app_date_utils.dart';
import '../../../core/widgets/attachment_section.dart';
import '../models/approval.dart';
import '../navigation/approval_item_navigator.dart';
import '../services/approval_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class _ApprovalComparisonHeader extends StatelessWidget {
  final String text;
  final bool emphasise;

  const _ApprovalComparisonHeader(this.text, {this.emphasise = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      color: emphasise ? const Color(0xFFDCFCE7) : null,
      child: Text(
        text,
        style: TextStyle(
          color: emphasise ? const Color(0xFF166534) : const Color(0xFF64748B),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

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
  bool _isLoadingApprovalDetails = true;
  bool _approvalDetailsLoadFailed = false;
  String? _currentUserId;
  final _commentController = TextEditingController();
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _approval = widget.approval;
    _resolveInitialNames();
    _loadCurrentUser();
    _fetchApprovalDetails();
    _fetchAuditTrail();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _currentUserId = prefs.getString('userId'));
  }

  bool get _isOwnRequest => !_approval.canSelfApprove &&
      _currentUserId != null && _currentUserId!.isNotEmpty &&
      _currentUserId == _approval.requesterId;

  /// The list item is only a navigation summary; always load the full approval
  /// payload before making a decision, especially for membership date changes.
  Future<void> _fetchApprovalDetails() async {
    if (mounted) {
      setState(() {
        _isLoadingApprovalDetails = true;
        _approvalDetailsLoadFailed = false;
      });
    }
    try {
      final latest = await _service.getApprovalById(_approval.id);
      if (!mounted) return;
      setState(() {
        _approval = latest;
        _isLoadingApprovalDetails = false;
      });
      _resolveInitialNames();
    } catch (error) {
      debugPrint('Could not load full approval details: $error');
      if (!mounted) return;
      setState(() {
        _isLoadingApprovalDetails = false;
        _approvalDetailsLoadFailed = true;
      });
    }
  }

  /// Reject placeholders and absent proposed dates. Old values may legitimately
  /// be null for historical records, but their keys must still be present.
  bool get _hasVerifiableMembershipDates {
    if (_approval.approvalType != 'MEMBERSHIP_DATE_CHANGE') return true;
    final payload = _decodedPayload;
    if (payload is! Map) return false;
    final current = payload['currentValues'];
    final proposed = payload['proposedValues'];
    if (current is! Map || proposed is! Map) return false;
    if (!current.containsKey('startDate') ||
        !current.containsKey('effectiveDate') ||
        !proposed.containsKey('startDate') ||
        !proposed.containsKey('effectiveDate')) return false;
    bool isProvidedDate(dynamic value) {
      if (value == null) return false;
      if (value is List && value.length >= 3) {
        return value.take(3).every((part) => part is int);
      }
      if (value is! String) return false;
      final text = value.trim();
      return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
          DateTime.tryParse(text) != null;
    }
    final oldStart = current['startDate'];
    final oldEffective = current['effectiveDate'];
    final newStart = proposed['startDate'];
    final newEffective = proposed['effectiveDate'];
    return isProvidedDate(newStart) &&
        (oldStart == null || isProvidedDate(oldStart)) &&
        (oldEffective == null || isProvidedDate(oldEffective)) &&
        (newEffective == null || isProvidedDate(newEffective));
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

  Future<void> _viewOriginalTransaction() async {
    final opened = await ApprovalItemNavigator.openOriginal(context, _approval);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Detail screen for this type is not yet implemented')),
      );
    }
  }

  Future<int?> _selectClaimArrearsMonths() async {
    var oneMonthFineCents = 0;
    var twoMonthFineCents = 0;
    try {
      final response = await ApiClient().get('/v2/membership-lapse/configuration');
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          oneMonthFineCents = _intValue(decoded['oneMonthArrearsFineCents']);
          twoMonthFineCents = _intValue(decoded['twoMonthArrearsFineCents']);
        }
      }
    } catch (_) {
      // Backend remains the source of truth; the dialog can still collect months.
    }

    if (!mounted) return null;
    int selected = 0;
    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Membership arrears'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specify how many months the membership is in arrears. '
                'The applicable fine will be deducted from the claim payout.',
              ),
              const SizedBox(height: 16),
              SearchableDropdownFormField<int>(
                value: selected,
                decoration: const InputDecoration(
                  labelText: 'Months in arrears',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('0 months — no fine')),
                  DropdownMenuItem(
                    value: 1,
                    child: Text('1 month — fine ${_money(oneMonthFineCents)}'),
                  ),
                  DropdownMenuItem(
                    value: 2,
                    child: Text('2 months — fine ${_money(twoMonthFineCents)}'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 12),
              Text(
                '3 months in arrears means the membership has lapsed and this claim cannot be approved.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('CONTINUE'),
            ),
          ],
        ),
      ),
    );
  }

  int _intValue(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _money(int cents) => NumberFormat.currency(
        locale: 'en_ZA',
        symbol: 'R',
        decimalDigits: 2,
      ).format(cents / 100);

  /// A few older approval rows have no createdAt. The membership change
  /// submission timestamp is still stored inside the immutable request detail.
  /// Preserve the distinction between approval-row creation and request time.
  dynamic get _displayRequestTime {
    if (AppDateUtils.parse(_approval.createdAt) != null) {
      return _approval.createdAt;
    }
    final payload = _decodedPayload;
    if (payload is Map && payload['requestSummary'] is Map) {
      return (payload['requestSummary'] as Map)['requestedAt'];
    }
    return null;
  }

  bool get _hasApprovalCreationTime =>
      AppDateUtils.parse(_approval.createdAt) != null;

  Future<void> _takeAction(String action) async {
    if (_isOwnRequest && (action == 'APPROVE' || action == 'REJECT')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A separate approver must decide this request.'),
      ));
      return;
    }
    if (action.toUpperCase() == 'APPROVE' &&
        (_isLoadingApprovalDetails || _approvalDetailsLoadFailed ||
            !_hasVerifiableMembershipDates)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Approval is blocked until the original membership dates can be verified.'),
      ));
      return;
    }
    int? arrearsMonths;
    if (action.toUpperCase() == 'APPROVE' &&
        _isClaimApprovalType(_approval.approvalType)) {
      arrearsMonths = await _selectClaimArrearsMonths();
      if (arrearsMonths == null) return;
    }

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
          updated = await _service.approve(
            _approval.id,
            comments: comment,
            actionBy: userId,
            arrearsMonths: arrearsMonths,
          );
          break;
        case 'REJECT':
          updated = await _service.reject(_approval.id, comments: comment, actionBy: userId);
          break;
        case 'CANCEL':
          updated = await _service.cancel(_approval.id, comments: comment, actionBy: userId);
          break;
        default:
          throw AppException('Unknown action: $action');
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
            content: Text(friendlyErrorMessage('Error: $e')),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  bool _isClaimApprovalType(String value) {
    final type = value.trim().toUpperCase();
    return type == 'CLAIM' || type.startsWith('CLAIM_');
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
                        if (_isLoadingApprovalDetails)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                        if (_approval.approvalType == 'MEMBERSHIP_DATE_CHANGE' &&
                            !_isLoadingApprovalDetails &&
                            (_approvalDetailsLoadFailed || !_hasVerifiableMembershipDates))
                          _buildMissingDateWarning(),
                        if (_hasRequestDetails) ...[
                          const SizedBox(height: 16),
                          _buildRequestDetailsSection(),
                        ],
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

  Widget _buildMissingDateWarning() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        border: Border.all(color: const Color(0xFFFDBA74)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFF9A3412)),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Membership date comparison is unavailable or incomplete. '
              'Approval is disabled until the original old and new dates are loaded.',
              style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _fetchApprovalDetails,
            child: const Text('RETRY'),
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
                AppDateUtils.displayDateTimePattern(_displayRequestTime, 'EEEE, d MMMM yyyy'),
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
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildMiniIndicator(Icons.tag_rounded, _approval.referenceNo),
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
          _buildInfoRow(
            'Reference Number',
            _approval.referenceNo.trim().isNotEmpty
                ? _approval.referenceNo
                : _approval.referenceId,
          ),
          _buildInfoRow('Requester', _userNameCache[_approval.requesterId] ?? _approval.requesterName),
          _buildInfoRow('Workflow Step', 'Step ${_approval.currentStepNo}'),
          _buildInfoRow(
            _hasApprovalCreationTime ? 'Submitted at' : 'Requested at',
            AppDateUtils.displayDateTimePattern(_displayRequestTime, 'dd MMM yyyy, HH:mm'),
          ),
          if (_approval.finalActionAt != null)
            _buildInfoRow('Final decision at', _formatShortDate(_approval.finalActionAt!)),
          if (_approval.finalActionBy != null)
            _buildInfoRow('Processed By', _userNameCache[_approval.finalActionBy!] ?? _approval.finalActionByName ?? 'Unknown user'),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  dynamic get _decodedPayload {
    final payload = _approval.payloadJson;
    if (payload == null || payload.trim().isEmpty) return null;
    try {
      return jsonDecode(payload);
    } catch (_) {
      return payload.trim();
    }
  }

  bool get _hasRequestDetails {
    final value = _decodedPayload;
    if (value == null) return false;
    if (value is Map) {
      return value.entries.any((entry) => entry.key.toString() != 'attachmentObjectIds');
    }
    if (value is List) return value.isNotEmpty;
    return value.toString().trim().isNotEmpty;
  }

  Widget _buildRequestDetailsSection() {
    final payload = _decodedPayload;
    return _buildSectionLayout(
      title: 'REQUEST DETAILS',
      icon: Icons.fact_check_outlined,
      child: _buildPayloadValue(payload, level: 0),
    );
  }

  Widget _buildPayloadValue(dynamic value, {required int level, String? fieldName}) {
    if (value is Map) {
      final entries = value.entries
          .where((entry) => entry.key.toString() != 'attachmentObjectIds'
              // Already displayed in the header and identification section.
              && !(level == 0 && entry.key.toString() == 'approvalSummary'))
          .toList();
      if (entries.isEmpty) return const Text('No additional request details were supplied.');

      final current = value['currentValues'] ??
          value['currentBankingDetails'] ??
          value['oldValues'] ??
          value['oldValue'] ??
          value['previousValues'] ??
          value['previousValue'];
      final proposed = value['proposedValues'] ??
          value['proposedBankingDetails'] ??
          value['newValues'] ??
          value['newValue'] ??
          value['requestedValues'] ??
          value['requestedValue'];
      final remaining = entries.where((entry) => !{
        'currentValues',
        'currentBankingDetails',
        'oldValues',
        'oldValue',
        'previousValues',
        'previousValue',
        'proposedValues',
        'proposedBankingDetails',
        'newValues',
        'newValue',
        'requestedValues',
        'requestedValue',
      }.contains(entry.key.toString())).toList();
      final technicalEntries = remaining
          .where((entry) => _isTechnicalIdentifier(entry.key.toString()))
          .toList();
      final descriptiveEntries = remaining
          .where((entry) => !_isTechnicalIdentifier(entry.key.toString()))
          .toList();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...descriptiveEntries.map((entry) => _buildPayloadEntry(
                entry.key.toString(),
                entry.value,
                level: level,
              )),
          if (technicalEntries.isNotEmpty)
            _buildTechnicalIdentifiers(technicalEntries, level: level),
          if (current != null || proposed != null) ...[
            if (remaining.isNotEmpty) const SizedBox(height: 8),
            _buildComparisonTable(current: current, proposed: proposed),
          ],
        ],
      );
    }

    if (value is List) {
      if (value.isEmpty) return const Text('None');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: value.asMap().entries.map((entry) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: _buildPayloadValue(entry.value, level: level + 1),
          );
        }).toList(),
      );
    }

    return SelectableText(
      _formatPayloadValue(fieldName, value),
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPayloadEntry(String key, dynamic value, {required int level}) {
    if (value == null || (value is String && value.trim().isEmpty)) {
      return const SizedBox.shrink();
    }
    final complex = value is Map || value is List;
    if (complex) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: level == 0 ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fieldLabel(key).toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _buildPayloadValue(value, level: level + 1, fieldName: key),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _fieldLabel(key),
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SelectableText(
              _formatPayloadValue(key, value),
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isTechnicalIdentifier(String key) {
    final value = key.trim();
    final lower = value.toLowerCase();
    return lower == 'id' ||
        lower == 'ids' ||
        lower.contains('uuid') ||
        RegExp(r'(^|[_\-\s])ids?$').hasMatch(lower) ||
        RegExp(r'Ids?$').hasMatch(value);
  }

  Widget _buildTechnicalIdentifiers(
    List<MapEntry<dynamic, dynamic>> entries, {
    required int level,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        leading: const Icon(Icons.data_object_rounded, size: 18, color: Color(0xFF94A3B8)),
        title: const Text(
          'TECHNICAL IDENTIFIERS',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        subtitle: const Text(
          'System references are available when needed',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
        ),
        children: entries
            .map((entry) => _buildPayloadEntry(
                  entry.key.toString(),
                  entry.value,
                  level: level + 1,
                ))
            .toList(),
      ),
    );
  }

  Map<String, dynamic> _comparisonValues(dynamic value) {
    if (value == null) return <String, dynamic>{};
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    if (value is List) {
      if (value.isEmpty) return <String, dynamic>{};
      final first = value.first;
      if (first is Map) {
        final result = first.map((key, item) => MapEntry(key.toString(), item));
        if (value.length > 1) {
          result['additionalRecords'] = value.length - 1;
        }
        return result;
      }
      return <String, dynamic>{'value': value};
    }
    return <String, dynamic>{'value': value};
  }

  Widget _buildComparisonTable({required dynamic current, required dynamic proposed}) {
    final currentValues = _comparisonValues(current);
    final proposedValues = _comparisonValues(proposed);
    final orderedKeys = <String>[];
    for (final key in [...currentValues.keys, ...proposedValues.keys]) {
      if (!orderedKeys.contains(key)) orderedKeys.add(key);
    }

    final descriptiveKeys = orderedKeys
        .where((key) => !_isTechnicalIdentifier(key))
        .where((key) => currentValues[key] != null || proposedValues[key] != null)
        .toList();
    final technicalKeys = orderedKeys
        .where(_isTechnicalIdentifier)
        .where((key) => currentValues[key] != null || proposedValues[key] != null)
        .toList();
    final rows = descriptiveKeys.isNotEmpty ? descriptiveKeys : technicalKeys;

    if (rows.isEmpty) {
      return const Text('No old or new values were supplied.');
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            color: const Color(0xFFF8FAFC),
            child: const Row(
              children: [
                Icon(Icons.compare_arrows_rounded, size: 18, color: Color(0xFF475569)),
                SizedBox(width: 8),
                Text(
                  'CHANGE COMPARISON',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final minWidth = constraints.maxWidth < 680 ? 680.0 : constraints.maxWidth;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: minWidth,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(1.25),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                    },
                    border: const TableBorder(
                      horizontalInside: BorderSide(color: Color(0xFFE2E8F0)),
                      verticalInside: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          _ApprovalComparisonHeader('FIELD'),
                          _ApprovalComparisonHeader('CURRENT / OLD'),
                          _ApprovalComparisonHeader('PROPOSED / NEW', emphasise: true),
                        ],
                      ),
                      ...rows.map((key) {
                        final oldValue = currentValues[key];
                        final newValue = proposedValues[key];
                        final changed = _comparisonText(key, oldValue) != _comparisonText(key, newValue);
                        return TableRow(
                          decoration: BoxDecoration(
                            color: changed ? const Color(0xFFFCFDFD) : Colors.white,
                          ),
                          children: [
                            _buildComparisonCell(_fieldLabel(key), label: true),
                            _buildComparisonCell(_comparisonText(key, oldValue)),
                            _buildComparisonCell(
                              _comparisonText(key, newValue),
                              proposed: true,
                              changed: changed,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
          if (technicalKeys.isNotEmpty && descriptiveKeys.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                dense: true,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                title: const Text(
                  'Show technical identifiers',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                children: technicalKeys
                    .map((key) => Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: _buildInfoRow(
                            _fieldLabel(key),
                            '${_comparisonText(key, currentValues[key])} → ${_comparisonText(key, proposedValues[key])}',
                          ),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComparisonCell(
    String value, {
    bool label = false,
    bool proposed = false,
    bool changed = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: proposed && changed ? const Color(0xFFF0FDF4) : null,
      alignment: Alignment.centerLeft,
      child: SelectableText(
        value,
        style: TextStyle(
          color: label
              ? const Color(0xFF475569)
              : proposed && changed
                  ? const Color(0xFF166534)
                  : const Color(0xFF1E293B),
          fontSize: 12,
          fontWeight: label || (proposed && changed) ? FontWeight.w800 : FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  String _comparisonText(String key, dynamic value) {
    // Older Jackson payloads can encode LocalDate as [year, month, day].
    if (key.toLowerCase().endsWith('date') &&
        value is List && value.length >= 3 &&
        value.take(3).every((part) => part is int)) {
      final iso = '${value[0]}-${value[1].toString().padLeft(2, '0')}-${value[2].toString().padLeft(2, '0')}';
      return _formatPayloadValue(key, iso);
    }
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (_) {
        return value.toString();
      }
    }
    return _formatPayloadValue(key, value);
  }

  String _fieldLabel(String key) {
    final withSpaces = key
        // Amounts stored in cents are converted to rand for display.
        .replaceAll('Cents', '')
        .replaceAll('_cents', '')
        .replaceAll('_', ' ')
        .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match.group(1)} ${match.group(2)}');
    return withSpaces
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part.length <= 3 && part.toUpperCase() == part
            ? part
            : '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatPayloadValue(String? key, dynamic value) {
    if (value == null) return 'Not supplied';
    if (value is bool) return value ? 'Yes' : 'No';
    final text = value.toString();
    final normalizedKey = key?.toLowerCase() ?? '';
    // Use the resolved requester's identity rather than echoing a database ID.
    if (normalizedKey == 'requestedby' && text == _approval.requesterId) {
      return _userNameCache[_approval.requesterId] ?? _approval.requesterName;
    }
    // Financial field names also include suffixes such as BeforeNewStart.
    if (normalizedKey.contains('cents')) {
      final cents = num.tryParse(text);
      if (cents != null) return _money(cents.round());
    }
    // Periods are persisted as YYYYMM, never display them as opaque numbers.
    if (normalizedKey == 'paiduptoperiod' && RegExp(r'^\d{6}$').hasMatch(text)) {
      final year = int.parse(text.substring(0, 4));
      final month = int.parse(text.substring(4, 6));
      if (month >= 1 && month <= 12) {
        return DateFormat('MMMM yyyy').format(DateTime.utc(year, month));
      }
    }
    if (RegExp(r'^\d{4}-\d{2}-\d{2}(T.*)?$').hasMatch(text)) {
      try {
        return text.contains('T')
            ? AppDateUtils.displayDateTimePattern(text, 'dd MMM yyyy, HH:mm')
            : AppDateUtils.displayDate(text);
      } catch (_) {}
    }
    return text.replaceAll('_', ' ');
  }

  List<String> _attachmentObjectIds() {
    final decoded = _decodedPayload;
    if (decoded is Map && decoded['attachmentObjectIds'] is List) {
      final ids = (decoded['attachmentObjectIds'] as List)
          .map((value) => value?.toString().trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();
      if (ids.isNotEmpty) return ids;
    }
    return [_approval.referenceId];
  }

  Widget _buildAttachmentSection() {
    final objectIds = _attachmentObjectIds();
    return _buildSectionLayout(
      title: 'EVIDENCE & DOCUMENTS',
      icon: Icons.attach_file_rounded,
      child: Column(
        children: objectIds.asMap().entries.map((entry) {
          return Padding(
            padding: EdgeInsets.only(top: entry.key == 0 ? 0 : 16),
            child: AttachmentSection(
              objectId: entry.value,
              readOnly: true,
            ),
          );
        }).toList(),
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
                  Text('by ${_userNameCache[action.actionBy] ?? action.actionByName}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
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
          if (_isOwnRequest) const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('You submitted this request. Another approver must review it.',
              style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600)),
          ),
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
                  onPressed: _isOwnRequest ? null : () => _takeAction('REJECT'),
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
                  onPressed: (_isOwnRequest || _isLoadingApprovalDetails || _approvalDetailsLoadFailed ||
                          !_hasVerifiableMembershipDates)
                      ? null : () => _takeAction('APPROVE'),
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
      return AppDateUtils.displayDateTimePattern(dateStr, 'MMM d, HH:mm');
    } catch (_) {
      return dateStr.split('T')[0];
    }
  }

  String _formatFullDate(String dateStr) {
    try {
      return AppDateUtils.displayDateTimePattern(dateStr, 'EEEE, d MMMM yyyy');
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
      case 'CLAIM':
      case 'CLAIM_CASH':
      case 'CLAIM_TOMBSTONE':
      case 'CLAIM_FUNERAL':
      case 'CLAIM_COMBINATION':
      case 'CLAIM_GROCERY':
        return const Color(0xFF7C3AED);
      case 'PAYMENT': return const Color(0xFF2563EB);
      case 'PAYMENT_REQUEST':
      case 'PREMIUM_PAYMENT_DELETION': return const Color(0xFFF20D1A);
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
