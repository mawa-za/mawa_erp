import 'dart:convert';
import 'package:flutter/material.dart';
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
  final _referenceController = TextEditingController();
  final List<Map<String, dynamic>> _items = [];
  bool _isSubmitting = false;

  void _addItem() {
    setState(() {
      _items.add({
        'recipient': null, // Partner object
        'amount': TextEditingController(),
        'reference': TextEditingController(),
      });
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<List<Partner>> _searchPartners(String query) async {
    if (query.length < 2) return [];
    try {
      final response = await ApiClient().get('/v2/partner?query=$query');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Partner.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error searching partners: $e');
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
        'reference': _referenceController.text,
        'items': _items.map((item) {
          final partner = item['recipient'] as Partner?;
          return {
            'recipientId': partner?.id,
            'amount': double.tryParse((item['amount'] as TextEditingController).text) ?? 0.0,
            'reference': (item['reference'] as TextEditingController).text,
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Batch Reference',
                  hintText: 'e.g. Salaries March 2025',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('PAYMENT ITEMS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  TextButton.icon(
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('ADD ITEM'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  return _buildItemRow(index);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isSubmitting
          ? const LinearProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('CREATE PAYROLL BATCH'),
              ),
            ),
    );
  }

  Widget _buildItemRow(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
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
                          hintText: item['recipient'] != null ? (item['recipient'] as Partner).fullName : 'Select Recipient',
                          isDense: true,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      );
                    },
                    suggestionsBuilder: (context, controller) async {
                      final partners = await _searchPartners(controller.text);
                      return partners.map((p) => ListTile(
                        title: Text(p.fullName),
                        subtitle: Text(p.number),
                        onTap: () {
                          setState(() {
                            item['recipient'] = p;
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
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: item['amount'],
                    decoration: const InputDecoration(labelText: 'Amount', isDense: true),
                    keyboardType: TextInputType.number,
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item['reference'],
                    decoration: const InputDecoration(labelText: 'Reference', isDense: true),
                    validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    for (var item in _items) {
      (item['amount'] as TextEditingController).dispose();
      (item['reference'] as TextEditingController).dispose();
    }
    super.dispose();
  }
}
