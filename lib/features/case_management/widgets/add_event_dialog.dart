import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_event.dart';
import '../services/case_management_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AddEventDialog extends StatefulWidget {
  final String caseId;
  final CaseEvent? event;

  const AddEventDialog({super.key, required this.caseId, this.event});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  String _eventType = 'OTHER';
  DateTime _startAt = DateTime.now().add(const Duration(hours: 1));
  DateTime? _endAt;
  DateTime? _reminderAt;

  final List<String> _eventTypes = [
    'CONSULTATION', 'HEARING', 'TRIAL', 'MEETING', 'CALL', 'DEADLINE', 'FILING', 'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title);
    _descriptionController = TextEditingController(text: widget.event?.description);
    _locationController = TextEditingController(text: widget.event?.location);
    if (widget.event != null) {
      _eventType = widget.event!.eventType;
      _startAt = widget.event!.startAt;
      _endAt = widget.event!.endAt;
      _reminderAt = widget.event!.reminderAt;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.event == null) {
        final request = CreateCaseEventRequest(
          eventType: _eventType,
          title: _titleController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
          startAt: _startAt,
          endAt: _endAt,
          location: _locationController.text.isNotEmpty ? _locationController.text : null,
          reminderAt: _reminderAt,
        );
        await _caseService.createEvent(widget.caseId, request);
      } else {
        final update = {
          'eventType': _eventType,
          'title': _titleController.text,
          'description': _descriptionController.text,
          'startAt': _startAt.toIso8601String(),
          'endAt': _endAt?.toIso8601String(),
          'location': _locationController.text,
          'reminderAt': _reminderAt?.toIso8601String(),
        };
        await _caseService.updateEvent(widget.event!.id, update);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e'))));
    }
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (date == null) return null;
    
    if (!mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.event == null ? 'Add Event' : 'Edit Event'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _eventType,
                decoration: const InputDecoration(labelText: 'Event Type'),
                items: _eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _eventType = v!),
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start At'),
                subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_startAt)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await _pickDateTime(_startAt);
                  if (picked != null) setState(() => _startAt = picked);
                },
              ),
              ListTile(
                title: const Text('End At'),
                subtitle: Text(_endAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(_endAt!) : 'Not set'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await _pickDateTime(_endAt ?? _startAt.add(const Duration(hours: 1)));
                  if (picked != null) setState(() => _endAt = picked);
                },
              ),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Location'),
              ),
              ListTile(
                title: const Text('Reminder At'),
                subtitle: Text(_reminderAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(_reminderAt!) : 'Not set'),
                trailing: const Icon(Icons.notifications_active_outlined),
                onTap: () async {
                  final picked = await _pickDateTime(_reminderAt ?? _startAt.subtract(const Duration(minutes: 30)));
                  if (picked != null) setState(() => _reminderAt = picked);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Save Event')),
      ],
    );
  }
}
