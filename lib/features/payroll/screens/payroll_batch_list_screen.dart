import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payroll_batch.dart';
import '../services/payroll_service.dart';
import 'payroll_batch_detail_screen.dart';
import 'payroll_batch_create_screen.dart';

class PayrollBatchListScreen extends StatefulWidget {
  const PayrollBatchListScreen({super.key});

  @override
  State<PayrollBatchListScreen> createState() => _PayrollBatchListScreenState();
}

class _PayrollBatchListScreenState extends State<PayrollBatchListScreen> {
  bool _isLoading = true;
  List<PayrollBatchSummary> _batches = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchBatches();
  }

  Future<void> _fetchBatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final batches = await PayrollService().getPayrollBatches();
      setState(() {
        _batches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load payroll batches: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _copyBatch(PayrollBatchSummary batch) async {
    final referenceController = TextEditingController(text: 'Copy of ${batch.reference}');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Payroll Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a reference for the new payroll batch:'),
            const SizedBox(height: 16),
            TextField(
              controller: referenceController,
              decoration: const InputDecoration(
                labelText: 'New Reference',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('COPY'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await PayrollService().copyPayrollBatch(batch.id, referenceController.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payroll batch copied successfully')),
          );
          _fetchBatches();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Payroll Batches'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchBatches),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PayrollBatchCreateScreen()),
          );
          if (result == true) _fetchBatches();
        },
        label: const Text('New Payroll Run'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchBatches, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_batches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No payroll batches found', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _batches.length,
      itemBuilder: (context, index) {
        final batch = _batches[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(batch.reference, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Created: ${batch.dateCreated}'),
                Text('Items: ${batch.itemCount} • Total: R ${batch.totalAmount.toStringAsFixed(2)}'),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (val) {
                if (val == 'copy') _copyBatch(batch);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'copy', child: ListTile(leading: Icon(Icons.copy), title: Text('Copy Batch'), contentPadding: EdgeInsets.zero)),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PayrollBatchDetailScreen(batchId: batch.id)),
              );
            },
          ),
        );
      },
    );
  }
}
