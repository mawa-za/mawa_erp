import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/cashup.dart';
import '../services/cashup_service.dart';
import 'cashup_detail_screen.dart';

class CashupListScreen extends StatefulWidget {
  const CashupListScreen({super.key});

  @override
  State<CashupListScreen> createState() => _CashupListScreenState();
}

class _CashupListScreenState extends State<CashupListScreen> {
  static const _pageSize = 50;
  static const _statuses = <String, String>{
    'ALL': 'All',
    'OPEN': 'Open',
    'AWAITING_DEPOSITS': 'Awaiting deposits',
    'COMPLETED': 'Completed',
    'SUBMITTED': 'Submitted',
    'APPROVED': 'Approved',
    'REJECTED': 'Rejected',
  };

  final CashupService _cashupService = CashupService();
  final ScrollController _scrollController = ScrollController();
  final List<Cashup> _cashups = [];

  String _selectedStatus = 'ALL';
  int _page = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCashups(reset: true);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _isLoading || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      _loadCashups();
    }
  }

  Future<void> _loadCashups({bool reset = false}) async {
    if (reset) {
      _loadGeneration++;
      setState(() {
        _page = 0;
        _hasMore = true;
        _cashups.clear();
        _isLoading = true;
        _isLoadingMore = false;
        _error = null;
      });
    } else {
      if (!_hasMore || _isLoading || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    final generation = _loadGeneration;
    final requestedStatus = _selectedStatus;
    final requestedPage = _page;

    try {
      final result = await _cashupService.getCashupPage(
        status: requestedStatus,
        page: requestedPage,
        size: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _cashups.addAll(result.items);
        _page = result.page + 1;
        _hasMore = !result.last;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _selectStatus(String status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    _loadCashups(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Cashups'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _loadCashups(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusSelector(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 64,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          children: _statuses.entries.map((entry) {
            final selected = _selectedStatus == entry.key;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(entry.value),
                onSelected: (_) => _selectStatus(entry.key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _cashups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 52, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadCashups(reset: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_cashups.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadCashups(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .55,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.point_of_sale_outlined,
                        size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(
                      'No ${_statuses[_selectedStatus]!.toLowerCase()} cashups',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadCashups(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _cashups.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _cashups.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCashupCard(_cashups[index]);
        },
      ),
    );
  }

  Widget _buildCashupCard(Cashup cashup) {
    final statusColor = _statusColor(cashup.status);
    final parsedDate = DateTime.tryParse(cashup.cashupDate);
    final dateLabel = parsedDate == null
        ? cashup.cashupDate
        : DateFormat('dd MMM yyyy').format(parsedDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CashupDetailScreen(cashupId: cashup.id),
            ),
          );
          if (mounted) _loadCashups(reset: true);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cashup #${cashup.cashupNo}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(dateLabel,
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatStatus(cashup.status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _info('Receipts', '${cashup.receiptCount}'),
                  _info('Cashier', cashup.userId),
                  _info('Device', cashup.deviceId),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TOTAL',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.bold)),
                      Text(
                        'R ${cashup.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '—' : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return Colors.green.shade700;
      case 'REJECTED':
        return Colors.red.shade700;
      case 'SUBMITTED':
        return Colors.indigo.shade700;
      case 'AWAITING_DEPOSITS':
      case 'COMPLETED':
        return Colors.orange.shade800;
      case 'OPEN':
      default:
        return Colors.blue.shade700;
    }
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Unknown';
    return status
        .split('_')
        .map((part) => part.isEmpty
            ? part
            : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
        .join(' ');
  }
}
