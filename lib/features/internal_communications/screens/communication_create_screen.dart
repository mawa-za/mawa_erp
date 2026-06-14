import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/communication.dart';
import '../services/communication_service.dart';

class CommunicationCreateScreen extends StatefulWidget {
  const CommunicationCreateScreen({super.key});

  @override
  State<CommunicationCreateScreen> createState() => _CommunicationCreateScreenState();
}

class _CommunicationCreateScreenState extends State<CommunicationCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CommunicationService();
  bool _isSubmitting = false;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  CommunicationType _selectedType = CommunicationType.announcement;
  DateTime? _scheduledAt;

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null) {
        setState(() {
          _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'title': _titleController.text,
        'content': _contentController.text,
        'type': _selectedType.name.toUpperCase(),
        'status': _scheduledAt != null ? 'SCHEDULED' : 'DRAFT',
        'scheduledAt': _scheduledAt?.toIso8601String(),
      };

      await _service.createCommunication(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Communication created successfully'), backgroundColor: Colors.green),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('New Communication'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<CommunicationType>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: CommunicationType.values.map((type) => DropdownMenuItem(
                value: type,
                child: Text(type.name.toUpperCase()),
              )).toList(),
              onChanged: (val) => setState(() => _selectedType = val!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: 'Content', border: OutlineInputBorder()),
              maxLines: 5,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Schedule Send Time'),
              subtitle: Text(_scheduledAt == null 
                  ? 'Send manually (Draft)' 
                  : DateFormat('MMM d, yyyy HH:mm').format(_scheduledAt!)),
              trailing: const Icon(Icons.calendar_today_outlined),
              tileColor: Colors.grey[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('CREATE COMMUNICATION'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
