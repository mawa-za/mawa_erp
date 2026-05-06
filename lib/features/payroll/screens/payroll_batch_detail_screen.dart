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
      appBar: AppBar(
        title: Text(_batch?.reference ?? 'Payroll Batch'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
    if (_batch == null) return const Center(child: Text('No data found'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _batch!.items.length,
      itemBuilder: (context, index) {
        final item = _batch!.items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(item.recipientName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Ref: ${item.reference}'),
            trailing: Text(
              'R ${item.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}
