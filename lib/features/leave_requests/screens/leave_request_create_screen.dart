import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_client.dart';
import '../../../core/models/field_option.dart';
import '../../../core/models/user.dart';
import '../../../core/services/field_service.dart';
import '../../../core/services/user_service.dart';
import '../services/leave_service.dart';

class LeaveRequestCreateScreen extends StatefulWidget {
  const LeaveRequestCreateScreen({super.key});

  @override
  State<LeaveRequestCreateScreen> createState() => _LeaveRequestCreateScreenState();
}

class _LeaveRequestCreateScreenState extends State<LeaveRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LeaveService();
  final _fieldService = FieldService();
  final _userService = UserService();

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;

  String? _selectedLeaveType;
  User? _selectedEmployee;
  User? _selectedApprover;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _daysController = TextEditingController(text: '1');

  List<FieldOption> _leaveTypeOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final types = await _fieldService.getOptionsByField('LEAVE-TYPE');
      setState(() {
        _leaveTypeOptions = types;
        if (_leaveTypeOptions.isNotEmpty) _selectedLeaveType = _leaveTypeOptions.first.code;
        _isLoadingOptions = false;
      });
    } catch (e) {
      debugPrint('Error loading options: $e');
      setState(() => _isLoadingOptions = false);
    }
  }

  void _calculateDays() {
    final difference = _endDate.difference(_startDate).inDays;
    setState(() {
      _daysController.text = (difference + 1).toString();
    });
  }

  Future<List<User>> _searchUsers(String query) async {
    try {
      final users = await _userService.getUsers();
      if (query.isEmpty) return users;
      return users.where((u) =>
        u.username.toLowerCase().contains(query.toLowerCase()) ||
        (u.email?.toLowerCase().contains(query.toLowerCase()) ?? false)
      ).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null || _selectedApprover == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select employee and approver')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'type': _selectedLeaveType,
        'employee': _selectedEmployee!.id,
        'approver': _selectedApprover!.id,
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        'days': double.tryParse(_daysController.text) ?? 0.0,
      };

      await _service.createLeaveRequest(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Leave request submitted successfully'), backgroundColor: Colors.green),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Request Leave'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionCard(
                    title: 'LEAVE DETAILS',
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLeaveType,
                        decoration: const InputDecoration(labelText: 'Leave Type', border: OutlineInputBorder()),
                        items: _leaveTypeOptions.map((opt) => DropdownMenuItem(value: opt.code, child: Text(opt.description))).toList(),
                        onChanged: (val) => setState(() => _selectedLeaveType = val),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDatePicker('Start Date', _startDate, (d) {
                            setState(() => _startDate = d);
                            _calculateDays();
                          })),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDatePicker('End Date', _endDate, (d) {
                            setState(() => _endDate = d);
                            _calculateDays();
                          })),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _daysController,
                        decoration: const InputDecoration(labelText: 'Total Days', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'PERSONNEL',
                    children: [
                      _buildUserSearch('Employee', _selectedEmployee, (u) => setState(() => _selectedEmployee = u)),
                      const SizedBox(height: 16),
                      _buildUserSearch('Approver', _selectedApprover, (u) => setState(() => _selectedApprover = u)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('SUBMIT REQUEST'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onPicked) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2000),
          lastDate: DateTime(2101),
        );
        if (picked != null) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        child: Text(DateFormat('yyyy-MM-dd').format(date)),
      ),
    );
  }

  Widget _buildUserSearch(String label, User? selected, Function(User?) onSelected) {
    return SearchAnchor(
      builder: (context, controller) {
        return TextField(
          controller: controller,
          onTap: () => controller.openView(),
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: selected?.username ?? 'Select $label',
            prefixIcon: const Icon(Icons.person_outline),
            border: const OutlineInputBorder(),
            suffixIcon: selected != null ? IconButton(icon: const Icon(Icons.clear), onPressed: () => onSelected(null)) : null,
          ),
        );
      },
      suggestionsBuilder: (context, controller) async {
        final users = await _searchUsers(controller.text);
        return users.map((u) => ListTile(
          title: Text(u.username),
          subtitle: Text(u.email ?? ''),
          onTap: () {
            onSelected(u);
            controller.closeView(u.username);
          },
        )).toList();
      },
    );
  }
}
