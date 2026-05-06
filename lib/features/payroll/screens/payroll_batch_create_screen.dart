import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api_client.dart';
import '../../partners/models/partner.dart';
import '../services/payroll_service.dart';

class PayrollBatchCreateScreen extends StatefulWidget {
  const PayrollBatchCreateScreen({super.key});

  @override
  State<PayrollBatchCreateScreen> createState() => _PayrollBatchCreateScreenState();
}

class _PayrollBatchCreateScreenState extends State<PayrollBatchCreateScreen> {
  final _formKey = GlobalKey<FormState>();

  // Batch Headers
  final _batchNoController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _payPeriodController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _paymentDate = DateTime.now();

  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _payPeriodController.text = DateFormat('yyyyMM').format(now);
    _batchNoController.text = 'PAY-${_payPeriodController.text}-001';
  }

  void _addItem() {
    setState(() {
      _items.add({
        'partner': null, // Selected Partner
        'amount': TextEditingController(),
        'paymentReference': TextEditingController(),
        'salaryReference': TextEditingController(),
        // Bank details can be edited if needed
        'bankName': TextEditingController(),
        'branchCode': TextEditingController(),
        'accountNo': TextEditingController(),
        'accountType': 'CURRENT',
        'accountHolderName': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<List<Partner>> _searchEmployees(String query) async {
    if (query.length < 2) return [];
    try {
      // Assuming employees are partners with a role or just searching partners
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching employees: $e');
    }
    return [];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'batchNo': _batchNoController.text,
        'description': _descriptionController.text,
        'payPeriod': _payPeriodController.text,
        'paymentDate': DateFormat('yyyy-MM-dd').format(_paymentDate),
        'notes': _notesController.text,
        'items': _items.map((item) {
          final partner = item['partner'] as Partner?;
          final amountDouble = double.tryParse((item['amount'] as TextEditingController).text) ?? 0.0;
          return {
            'employeeId': partner?.id,
            'employeeNo': partner?.number,
            'employeeName': partner?.fullName,
            'bankName': (item['bankName'] as TextEditingController).text,
            'branchCode': (item['branchCode'] as TextEditingController).text,
            'accountNo': (item['accountNo'] as TextEditingController).text,
            'accountType': item['accountType'],
            'accountHolderName': (item['accountHolderName'] as TextEditingController).text,
            'amountCents': (amountDouble * 100).round(),
            'paymentReference': (item['paymentReference'] as TextEditingController).text,
            'salaryReference': (item['salaryReference'] as TextEditingController).text,
          };
        }).toList(),
      };

      await PayrollService().createPayrollBatch(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payroll batch created successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('New Payroll Run'),
        actions: [
          if (!_isSubmitting)
            IconButton(onPressed: _submit, icon: const Icon(Icons.check)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildBatchHeader(),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('EMPLOYEE PAYMENTS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('ADD EMPLOYEE'),
                      ),
                    ],
                  ),
                  ...List.generate(_items.length, (index) => _buildItemCard(index)),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const CircularProgressIndicator()
              : const Text('CREATE PAYROLL BATCH', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _buildBatchHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _batchNoController,
                    decoration: const InputDecoration(labelText: 'Batch No', border: OutlineInputBorder(), isDense: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _payPeriodController,
                    decoration: const InputDecoration(labelText: 'Pay Period (YYYYMM)', border: OutlineInputBorder(), isDense: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder(), isDense: true),
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paymentDate,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _paymentDate = picked);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Payment Date', border: OutlineInputBorder(), isDense: true),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(DateFormat('yyyy-MM-dd').format(_paymentDate)),
                          const Icon(Icons.calendar_today, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder(), isDense: true),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SearchAnchor(
                    builder: (context, controller) {
                      return TextField(
                        controller: controller,
                        onTap: () => controller.openView(),
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: item['partner'] != null ? (item['partner'] as Partner).fullName : 'Select Employee',
                          isDense: true,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      );
                    },
                    suggestionsBuilder: (context, controller) async {
                      final employees = await _searchEmployees(controller.text);
                      return employees.map((p) => ListTile(
                        title: Text(p.fullName),
                        subtitle: Text(p.number),
                        onTap: () {
                          setState(() {
                            item['partner'] = p;
                            (item['accountHolderName'] as TextEditingController).text = p.fullName;
                            (item['paymentReference'] as TextEditingController).text = 'SALARY ${DateFormat('MMM yyyy').format(_paymentDate).toUpperCase()}';
                            (item['salaryReference'] as TextEditingController).text = '${_batchNoController.text}-${p.number}';
                            controller.closeView(p.fullName);
                          });
                        },
                      )).toList();
                    },
                  ),
                ),
                IconButton(
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item['amount'],
                    decoration: const InputDecoration(labelText: 'Amount', isDense: true, prefixText: 'R '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: item['accountType'],
                    decoration: const InputDecoration(labelText: 'Account Type', isDense: true),
                    items: ['CURRENT', 'SAVINGS', 'TRANSMISSION'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                    onChanged: (val) => setState(() => item['accountType'] = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item['bankName'],
                    decoration: const InputDecoration(labelText: 'Bank Name', isDense: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: item['branchCode'],
                    decoration: const InputDecoration(labelText: 'Branch Code', isDense: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: item['accountNo'],
              decoration: const InputDecoration(labelText: 'Account Number', isDense: true),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: item['paymentReference'],
              decoration: const InputDecoration(labelText: 'Payment Reference', isDense: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _batchNoController.dispose();
    _descriptionController.dispose();
    _payPeriodController.dispose();
    _notesController.dispose();
    for (var item in _items) {
      (item['amount'] as TextEditingController).dispose();
      (item['paymentReference'] as TextEditingController).dispose();
      (item['salaryReference'] as TextEditingController).dispose();
      (item['bankName'] as TextEditingController).dispose();
      (item['branchCode'] as TextEditingController).dispose();
      (item['accountNo'] as TextEditingController).dispose();
      (item['accountHolderName'] as TextEditingController).dispose();
    }
    super.dispose();
  }
}
