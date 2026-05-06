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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_batch?.batchNo ?? 'Payroll Batch'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
                _buildHeaderInfo(),
                const SizedBox(height: 24),
                const Text(
                  'PAYMENT ITEMS',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = _batch!.items[index];
              return _buildItemTile(item);
            },
            childCount: _batch!.items.length,
          ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
      ],
    );
  }

  Widget _buildHeaderInfo() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow('Description', _batch!.description),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(child: _buildInfoRow('Pay Period', _batch!.payPeriod)),
                Expanded(child: _buildInfoRow('Payment Date', _batch!.paymentDate)),
              ],
            ),
            if (_batch!.notes.isNotEmpty) ...[
              const Divider(height: 24),
              _buildInfoRow('Notes', _batch!.notes),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Widget _buildItemTile(PayrollItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade100),
      ),
      child: ExpansionTile(
        title: Text(item.employeeName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Ref: ${item.paymentReference ?? '-'}'),
        trailing: Text(
          'R ${item.amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _buildDetailRow('Employee No', item.employeeNo ?? '-'),
                _buildDetailRow('Bank', item.bankName ?? '-'),
                _buildDetailRow('Account No', item.accountNo ?? '-'),
                _buildDetailRow('Account Type', item.accountType ?? '-'),
                _buildDetailRow('Branch Code', item.branchCode ?? '-'),
                _buildDetailRow('Salary Ref', item.salaryReference ?? '-'),
              ],
            ),
          ),
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
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
