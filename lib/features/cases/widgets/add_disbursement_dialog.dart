import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_disbursement.dart';
import '../services/case_management_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddDisbursementDialog extends StatefulWidget {
  final String caseId;

  const AddDisbursementDialog({super.key, required this.caseId});

  @override
  State<AddDisbursementDialog> createState() => _AddDisbursementDialogState();
}

class _AddDisbursementDialogState extends State<AddDisbursementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  String _disbursementType = 'OTHER';
  DateTime _disbursementDate = DateTime.now();
  bool _billable = true;

  final List<String> _types = [
    'SHERIFF', 'COURT_FEE', 'TRAVEL', 'PRINTING', 'POSTAGE', 'ADVOCATE', 'EXPERT', 'OTHER'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final request = CreateCaseDisbursementRequest(
        disbursementDate: _disbursementDate,
        disbursementType: _disbursementType,
        description: _descriptionController.text,
        amountCents: (double.parse(_amountController.text) * 100).round(),
        billable: _billable,
      );
      await _caseService.createDisbursement(widget.caseId, request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Disbursement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _disbursementType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _disbursementType = v!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _disbursementDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) setState(() => _disbursementDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(DateFormat('yyyy-MM-dd').format(_disbursementDate)),
                ),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (Rand)*', prefixText: 'R '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SwitchListTile(
                title: const Text('Billable'),
                value: _billable,
                onChanged: (v) => setState(() => _billable = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
