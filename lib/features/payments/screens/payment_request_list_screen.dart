import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../../../core/utils/app_date_utils.dart';
import '../models/payment_request.dart';
import '../services/payment_request_service.dart';
import 'payment_request_create_screen.dart';
import 'payment_request_detail_screen.dart';

class PaymentRequestListScreen extends StatefulWidget {
  const PaymentRequestListScreen({super.key});

  @override
  State<PaymentRequestListScreen> createState() => _PaymentRequestListScreenState();
}

class _PaymentRequestListScreenState extends State<PaymentRequestListScreen> {
  final PaymentRequestService _service = PaymentRequestService();
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _statuses = <String>[
    'ALL',
    'DRAFT',
    'PENDING_APPROVAL',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
    'PAID',
  ];

  bool _isLoading = true;
  List<PaymentRequestSummary> _payments = <PaymentRequestSummary>[];
  String? _error;
  String _selectedStatus = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPayments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _service.getPaymentRequests(
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );
      results.sort(_latestFirst);
      if (!mounted) return;
      setState(() {
        _payments = results;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage('Failed to load payment requests: $e');
        _isLoading = false;
      });
    }
  }

  int _latestFirst(PaymentRequestSummary a, PaymentRequestSummary b) {
    final aDate = AppDateUtils.parse(a.createdAt);
    final bDate = AppDateUtils.parse(b.createdAt);
    return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
        .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
  }

  List<PaymentRequestSummary> get _visiblePayments {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return _payments;
    return _payments.where((payment) {
      final searchable = <String>[
        payment.requestNo,
        payment.payeeName,
        payment.externalReference ?? '',
        payment.invoiceNo ?? '',
        payment.paymentReason ?? '',
        payment.requestType,
        payment.status,
        payment.amount.toStringAsFixed(2),
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final visibleCount = _visiblePayments.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Payment Requests'),
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchPayments,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(visibleCount),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const PaymentRequestCreateScreen(),
            ),
          );
          if (result == true) _fetchPayments();
        },
        label: const Text('New Request'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildToolbar(int visibleCount) {
    return Material(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedStatus == 'ALL'
                            ? '$visibleCount payment request${visibleCount == 1 ? '' : 's'}'
                            : '$visibleCount ${_statusLabel(_selectedStatus).toLowerCase()} request${visibleCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Text(
                      'Latest first',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search request number, supplier, reference or reason',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final status = _statuses[index];
                      final selected = status == _selectedStatus;
                      return ChoiceChip(
                        label: Text(_statusLabel(status)),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (value) {
                          if (!value || selected) return;
                          setState(() => _selectedStatus = status);
                          _fetchPayments();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return _MessageState(
        icon: Icons.error_outline,
        title: 'Unable to load payment requests',
        message: _error!,
        actionLabel: 'Retry',
        onAction: _fetchPayments,
      );
    }

    if (_payments.isEmpty) {
      return const _MessageState(
        icon: Icons.payments_outlined,
        title: 'No payment requests',
        message: 'There are no payment requests for the selected status.',
      );
    }

    final visible = _visiblePayments;
    if (visible.isEmpty) {
      return const _MessageState(
        icon: Icons.search_off,
        title: 'No matching requests',
        message: 'Try a different search term or status filter.',
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPayments,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1150),
            child: _buildPaymentCard(visible[index]),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentRequestSummary payment) {
    final theme = Theme.of(context);
    final reference = (payment.externalReference ?? payment.invoiceNo ?? '').trim();
    final reason = (payment.paymentReason ?? '').trim();
    final payee = payment.payeeName.trim().isEmpty ? 'Payee not specified' : payment.payeeName.trim();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaymentRequestDetailScreen(paymentId: payment.id),
            ),
          );
          if (result == true) _fetchPayments();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payee,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          payment.requestNo.isEmpty ? 'Payment request' : payment.requestNo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${payment.currency} ${payment.amount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildStatusChip(payment.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 10,
                children: [
                  _meta(
                    Icons.category_outlined,
                    'Type',
                    _statusLabel(payment.requestType),
                  ),
                  _meta(
                    Icons.event_outlined,
                    'Requested payment',
                    AppDateUtils.displayDate(payment.requestedPaymentDate),
                  ),
                  if (reference.isNotEmpty)
                    _meta(Icons.tag_outlined, 'Reference', reference),
                  if (reason.isNotEmpty)
                    _meta(Icons.notes_outlined, 'Reason', reason),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 330),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(String value) {
    if (value.isEmpty) return 'Not specified';
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _buildStatusChip(String status) {
    final color = switch (status.toUpperCase()) {
      'PAID' || 'APPROVED' => Colors.green,
      'REJECTED' || 'CANCELLED' || 'FAILED' => Colors.red,
      'PENDING_APPROVAL' || 'QUEUED_FOR_PAYMENT' => Colors.orange,
      _ => Colors.blueGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
