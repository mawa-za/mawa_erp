import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/cashup.dart';
import '../services/cashup_service.dart';

class CashupListScreen extends StatefulWidget {
  const CashupListScreen({super.key});

  @override
  State<CashupListScreen> createState() => _CashupListScreenState();
}

class _CashupListScreenState extends State<CashupListScreen> {
  final CashupService _cashupService = CashupService();
  List<Cashup> _cashups = [];
  bool _isLoading = true;
  String? _error;

  DateTime? _fromDate;
  DateTime? _toDate;
  final TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCashups();
  }

  Future<void> _fetchCashups() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fromStr = _fromDate != null ? DateFormat('yyyy-MM-dd').format(_fromDate!) : null;
      final toStr = _toDate != null ? DateFormat('yyyy-MM-dd').format(_toDate!) : null;
      
      final cashups = await _cashupService.getCashups(
        userId: _userIdController.text.isEmpty ? null : _userIdController.text,
        fromDate: fromStr,
        toDate: toStr,
      );

      setState(() {
        _cashups = cashups;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCashups,
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _cashups.isEmpty
                  ? const Center(child: Text('No cashups found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cashups.length,
                      itemBuilder: (context, index) {
                        final cashup = _cashups[index];
                        return _buildCashupCard(cashup);
                      },
                    ),
    );
  }

  Widget _buildCashupCard(Cashup cashup) {
    return Card(
      margin: const EdgeInsets.bottom(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text('Cashup #${cashup.cashupNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Date: ${cashup.cashupDate} • Status: ${cashup.status}'),
        trailing: Text(
          'R ${cashup.totalAmount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Device ID', cashup.deviceId),
                _buildInfoRow('User ID', cashup.userId),
                _buildInfoRow('Receipt Count', cashup.receiptCount.toString()),
                const Divider(),
                const Text('Payments', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...cashup.payments.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${p.paymentMethod} (${p.paymentCount})'),
                      Text('R ${p.amount.toStringAsFixed(2)}'),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Cashups'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _userIdController,
                decoration: const InputDecoration(labelText: 'User ID'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        await _selectDate(context, true);
                        setDialogState(() {});
                      },
                      child: Text(_fromDate == null 
                          ? 'From Date' 
                          : DateFormat('yyyy-MM-dd').format(_fromDate!)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        await _selectDate(context, false);
                        setDialogState(() {});
                      },
                      child: Text(_toDate == null 
                          ? 'To Date' 
                          : DateFormat('yyyy-MM-dd').format(_toDate!)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _userIdController.clear();
                  _fromDate = null;
                  _toDate = null;
                });
                Navigator.pop(context);
                _fetchCashups();
              },
              child: const Text('CLEAR'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _fetchCashups();
              },
              child: const Text('APPLY'),
            ),
          ],
        ),
      ),
    );
  }
}
