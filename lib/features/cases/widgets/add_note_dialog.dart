import 'package:flutter/material.dart';
import '../models/case_note.dart';
import '../services/case_management_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddNoteDialog extends StatefulWidget {
  final String caseId;

  const AddNoteDialog({super.key, required this.caseId});

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  String _noteType = 'GENERAL';
  bool _privateNote = false;

  final List<String> _noteTypes = [
    'GENERAL', 'CONSULTATION', 'COURT_NOTE', 'TELEPHONE', 'EMAIL', 'INTERNAL'
  ];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final request = CreateCaseNoteRequest(
        noteType: _noteType,
        title: _titleController.text,
        note: _noteController.text,
        privateNote: _privateNote,
      );
      await _caseService.createNote(widget.caseId, request);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Case Note'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _noteType,
                decoration: const InputDecoration(labelText: 'Note Type'),
                items: _noteTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _noteType = v!),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note Content*'),
                maxLines: 5,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              SwitchListTile(
                title: const Text('Private Note'),
                subtitle: const Text('Only visible to internal users'),
                value: _privateNote,
                onChanged: (v) => setState(() => _privateNote = v),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save Note')),
      ],
    );
  }
}
