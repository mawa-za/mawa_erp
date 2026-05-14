import 'package:flutter/material.dart';
import '../models/payroll_batch.dart';
import '../services/payroll_service.dart';

class PayrollBatchDetailScreen extends StatefulWidget {
  final String batchId;
  const PayrollBatchDetailScreen({super.key, required this.batchId});

  @override
  State<PayrollBatchDetailScreen> createState() => _PayrollBatchDetailScreenState();
}

class _PayrollBatchDetailScreenState extends State<PayrollBatchDetailScreen> {
  bool _isLoading = true;
  PayrollBatchDetail? _batch;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await PayrollService().getPayrollBatch(widget.batchId);
      setState(() {
        _batch = detail;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load details: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: Text(_batch?.batchNo ?? 'Batch Details'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          if (_batch != null)
            IconButton(
              icon: const Icon(Icons.print_rounded),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report generation coming soon')),
                );
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_batch == null) return const Center(child: Text('No data found'));

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(colorScheme),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'PAYMENT ITEMS (${_batch!.items.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey[600], letterSpacing: 1.0),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final item = _batch!.items[index];
                return _buildItemCard(item, colorScheme);
              },
              childCount: _batch!.items.length,
            ),
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildHeaderCard(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusChip(_batch!.status),
              Text(
                _batch!.payPeriod,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _batch!.description,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
          const SizedBox(height: 8),
          if (_batch!.notes.isNotEmpty)
            Text(
              _batch!.notes,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildInfoItem('PAYMENT DATE', _batch!.paymentDate, Icons.calendar_month_rounded),
              const Spacer(),
              _buildInfoItem('TOTAL VALUE', 'R ${_calculateTotal()}', Icons.payments_rounded, isAmount: true),
            ],
          ),
        ],
      ),
    );
  }

  String _calculateTotal() {
    double total = 0;
    for (var item in _batch!.items) {
      total += item.amount;
    }
    return total.toStringAsFixed(2);
  }

  Widget _buildInfoItem(String label, String value, IconData icon, {bool isAmount = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: isAmount ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isAmount) ...[Icon(icon, size: 14, color: Colors.grey[400]), const SizedBox(width: 4)],
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isAmount ? colorScheme.primary : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PROCESSED': color = Colors.green; break;
      case 'FAILED': color = Colors.red; break;
      case 'NEW': color = Colors.orange; break;
      default: color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildItemCard(PayrollItem item, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          child: Text(
            item.employeeName?.substring(0, 1).toUpperCase() ?? 'E',
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          item.employeeName ?? 'Unknown Employee',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          item.employeeNo ?? 'No ID',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Text(
          'R ${item.amount.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: colorScheme.primary),
        ),
        children: [
          const Divider(),
          _buildDetailRow('Account Holder', item.accountHolderName ?? '-'),
          _buildDetailRow('Bank Name', item.bankName ?? '-'),
          _buildDetailRow('Account Number', item.accountNo ?? '-'),
          _buildDetailRow('Account Type', item.accountType ?? '-'),
          _buildDetailRow('Branch Code', item.branchCode ?? '-'),
          _buildDetailRow('Reference', item.paymentReference ?? '-'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
