import 'package:flutter/material.dart';
import '../models/approval.dart';
import '../services/approval_service.dart';
import 'approval_detail_screen.dart';

class ApprovalListScreen extends StatefulWidget {
  final String? approvalType;
  final String? title;

  const ApprovalListScreen({
    super.key,
    this.approvalType,
    this.title,
  });

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ApprovalService _service = ApprovalService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title?.trim().isNotEmpty == true
        ? widget.title!
        : widget.approvalType?.trim().isNotEmpty == true
            ? '${_label(widget.approvalType!)} Approvals'
            : 'Approvals';
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const ['PENDING', 'IN_PROGRESS', 'APPROVED', 'REJECTED', 'CANCELLED']
            .map((status) => _ApprovalListView(
                  key: ValueKey('${widget.approvalType}-$status'),
                  status: status,
                  approvalType: widget.approvalType,
                  service: _service,
                ))
            .toList(),
      ),
    );
  }

  static String _label(String value) => value
      .split('_')
      .map((part) => part.isEmpty
          ? part
          : '${part[0]}${part.substring(1).toLowerCase()}')
      .join(' ');
}

class _ApprovalListView extends StatefulWidget {
  final String status;
  final String? approvalType;
  final ApprovalService service;

  const _ApprovalListView({
    super.key,
    required this.status,
    required this.approvalType,
    required this.service,
  });

  @override
  State<_ApprovalListView> createState() => _ApprovalListViewState();
}

class _ApprovalListViewState extends State<_ApprovalListView> {
  bool _isLoading = true;
  List<Approval> _approvals = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  DateTime _dateOf(String raw) {
    final direct = DateTime.tryParse(raw);
    if (direct != null) return direct;
    final normalized = raw.replaceFirst(' ', 'T');
    return DateTime.tryParse(normalized) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _fetchApprovals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.service.getApprovals(
        status: widget.status,
        approvalType: widget.approvalType,
      );
      results.sort((a, b) => _dateOf(b.createdAt).compareTo(_dateOf(a.createdAt)));
      if (!mounted) return;
      setState(() {
        _approvals = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $_error', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: _fetchApprovals, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_approvals.isEmpty) {
      return Center(
        child: Text(
          'No ${widget.status.replaceAll('_', ' ').toLowerCase()} approvals',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovals,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _approvals.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final approval = _approvals[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            leading: CircleAvatar(
              child: Icon(_iconForType(approval.approvalType)),
            ),
            title: Text(
              approval.title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${approval.description}\n${approval.referenceNo} • ${approval.requesterId}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: true,
            trailing: Text(
              approval.approvalType.replaceAll('_', ' '),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ApprovalDetailScreen(approval: approval),
                ),
              );
              if (result == true) _fetchApprovals();
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'CLAIM':
        return Icons.request_quote_outlined;
      case 'PAYMENT':
      case 'PAYMENT_REQUEST':
        return Icons.payments_outlined;
      case 'PURCHASE_ORDER':
      case 'SUPPLIER_INVOICE':
        return Icons.shopping_cart_checkout_outlined;
      case 'SUPPLIER_ONBOARDING':
        return Icons.person_add_alt_outlined;
      case 'SUPPLIER_BANKING_DETAILS':
        return Icons.account_balance_outlined;
      case 'LEAVE':
        return Icons.event_available_outlined;
      default:
        return Icons.approval_outlined;
    }
  }
}
