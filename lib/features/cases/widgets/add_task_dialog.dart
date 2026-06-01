import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_task.dart';
import '../services/case_management_service.dart';
import '../../../core/models/user.dart';

class AddTaskDialog extends StatefulWidget {
  final String caseId;
  final List<User> users;
  final CaseTask? task;

  const AddTaskDialog({super.key, required this.caseId, required this.users, this.task});

  @override
  State<AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _estimatedMinutesController;

  String _priority = 'NORMAL';
  String? _assignedTo;
  DateTime? _dueDate;
  bool _billable = true;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title);
    _descriptionController = TextEditingController(text: widget.task?.description);
    _estimatedMinutesController = TextEditingController(text: widget.task?.estimatedMinutes.toString() ?? '0');
    _priority = widget.task?.priority ?? 'NORMAL';
    _assignedTo = widget.task?.assignedTo;
    _dueDate = widget.task?.dueDate;
    _billable = widget.task?.billable ?? true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.task == null) {
        final request = CreateCaseTaskRequest(
          title: _titleController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          assignedTo: _assignedTo,
          priority: _priority,
          dueDate: _dueDate,
          billable: _billable,
          estimatedMinutes: int.tryParse(_estimatedMinutesController.text) ?? 0,
        );
        await _caseService.createTask(widget.caseId, request);
      } else {
        // Update task logic if needed
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Task Title*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              DropdownButtonFormField<String>(
                value: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: ['LOW', 'NORMAL', 'HIGH', 'URGENT'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              DropdownButtonFormField<String?>(
                value: _assignedTo,
                decoration: const InputDecoration(labelText: 'Assign To'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Unassigned')),
                  ...widget.users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))),
                ],
                onChanged: (v) => setState(() => _assignedTo = v),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2101),
                  );
                  if (picked != null) setState(() => _dueDate = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Due Date'),
                  child: Text(_dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : 'Select Date'),
                ),
              ),
              TextFormField(
                controller: _estimatedMinutesController,
                decoration: const InputDecoration(labelText: 'Estimated Minutes'),
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
