import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_time_entry.dart';
import '../models/case_task.dart';
import '../services/case_management_service.dart';
import '../../../core/models/user.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddTimeEntryDialog extends StatefulWidget {
  final String caseId;
  final List<CaseTask> tasks;
  final List<User> users;
  final int defaultHourlyRateCents;

  const AddTimeEntryDialog({
    super.key,
    required this.caseId,
    required this.tasks,
    required this.users,
    required this.defaultHourlyRateCents,
  });

  @override
  State<AddTimeEntryDialog> createState() => _AddTimeEntryDialogState();
}

class _AddTimeEntryDialogState extends State<AddTimeEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  final _descriptionController = TextEditingController();
  final _minutesController = TextEditingController(text: '15');
  final _hourlyRateController = TextEditingController();

  String? _taskId;
  String? _userId;
  DateTime _entryDate = DateTime.now();
  bool _billable = true;

  @override
  void initState() {
    super.initState();
    _hourlyRateController.text = (widget.defaultHourlyRateCents / 100).toStringAsFixed(2);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _userId == null) {
      if (_userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a user')));
      }
      return;
    }

    try {
      final request = CreateCaseTimeEntryRequest(
        taskId: _taskId,
        entryDate: _entryDate,
        userId: _userId!,
        description: _descriptionController.text,
        minutes: int.tryParse(_minutesController.text) ?? 0,
        hourlyRateCents: (double.tryParse(_hourlyRateController.text) ?? 0 * 100).round(),
        billable: _billable,
      );
      await _caseService.createTimeEntry(widget.caseId, request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capture Time'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String?>(
                value: _taskId,
                decoration: const InputDecoration(labelText: 'Related Task (Optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...widget.tasks.map((t) => DropdownMenuItem(value: t.id, child: Text(t.title))),
                ],
                onChanged: (v) => setState(() => _taskId = v),
              ),
              DropdownButtonFormField<String>(
                value: _userId,
                decoration: const InputDecoration(labelText: 'User*'),
                items: widget.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))).toList(),
                onChanged: (v) => setState(() => _userId = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _entryDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) setState(() => _entryDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(DateFormat('yyyy-MM-dd').format(_entryDate)),
                ),
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _minutesController,
                decoration: const InputDecoration(labelText: 'Minutes*'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _hourlyRateController,
                decoration: const InputDecoration(labelText: 'Hourly Rate (Rand)', prefixText: 'R '),
                keyboardType: TextInputType.number,
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
