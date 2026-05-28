import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_disbursement.dart';
import '../services/case_management_service.dart';

class CaseDisbursementsTab extends StatefulWidget {
  final String caseId;
  const CaseDisbursementsTab({super.key, required this.caseId});

  @override
  State<CaseDisbursementsTab> createState() => _CaseDisbursementsTabState();
}

class _CaseDisbursementsTabState extends State<CaseDisbursementsTab> {
  final CaseManagementService _caseService = CaseManagementService();
  List<CaseDisbursement> _disbursements = [];
  bool _isLoading = true;
  String? _error;

  final List<String> _disbursementTypes = [
    'SHERIFF', 'COURT_FEE', 'TRAVEL', 'PRINTING', 'POSTAGE', 'ADVOCATE', 'EXPERT', 'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDisbursements();
  }

  Future<void> _fetchDisbursements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _caseService.getDisbursements(widget.caseId);
      setState(() {
        _disbursements = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showAddDisbursementDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedType = 'OTHER';
    DateTime date = DateTime.now();
    bool billable = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Disbursement'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: _disbursementTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Amount (R)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text('Date: ${DateFormat('yyyy-MM-dd').format(date)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => date = picked);
                  },
                ),
                CheckboxListTile(
                  title: const Text('Billable'),
                  value: billable,
                  onChanged: (val) => setDialogState(() => billable = val ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (descController.text.isEmpty || amountController.text.isEmpty) return;
                
                setState(() => _isLoading = true);
                try {
                  await _caseService.createDisbursement(
                    widget.caseId,
                    CreateCaseDisbursementRequest(
                      disbursementDate: date,
                      disbursementType: selectedType,
                      description: descController.text,
                      amountCents: (double.tryParse(amountController.text) ?? 0 * 100).toInt(),
                      billable: billable,
                    ),
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    _fetchDisbursements();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _disbursements.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_disbursements.length} Disbursements', style: const TextStyle(fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _showAddDisbursementDialog,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Add Disbursement'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _disbursements.isEmpty
              ? const Center(child: Text('No disbursements recorded'))
              : ListView.separated(
                  itemCount: _disbursements.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _disbursements[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange.withOpacity(0.1),
                        child: Icon(_getIcon(item.disbursementType), color: Colors.orange, size: 20),
                      ),
                      title: Text(item.description),
                      subtitle: Text(
                        '${DateFormat('dd MMM yyyy').format(item.disbursementDate)} • ${item.disbursementType}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            item.amountFormatted,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            item.billable ? (item.billed ? 'Billed' : 'Unbilled') : 'Non-billable',
                            style: TextStyle(
                              fontSize: 10,
                              color: item.billable ? (item.billed ? Colors.green : Colors.orange) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'COURT_FEE': return Icons.gavel;
      case 'TRAVEL': return Icons.directions_car;
      case 'PRINTING': return Icons.print;
      case 'POSTAGE': return Icons.local_post_office;
      case 'ADVOCATE': return Icons.person;
      default: return Icons.receipt;
    }
  }
}
