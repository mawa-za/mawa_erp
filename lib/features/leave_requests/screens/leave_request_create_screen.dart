import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/field_option.dart';
import '../../../core/services/field_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../partners/models/partner.dart';
import '../services/leave_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveRequestCreateScreen extends StatefulWidget {
  const LeaveRequestCreateScreen({super.key});

  @override
  State<LeaveRequestCreateScreen> createState() => _LeaveRequestCreateScreenState();
}

class _LeaveRequestCreateScreenState extends State<LeaveRequestCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LeaveService();
  final _fieldService = FieldService();

  bool _isLoadingOptions = true;
  bool _isSubmitting = false;
  String? _optionsError;

  String? _selectedLeaveType;
  Partner? _selectedEmployee;
  Partner? _selectedApprover;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _daysController = TextEditingController(text: '2');

  List<FieldOption> _leaveTypeOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final types = await _fieldService.getOptionsByField('LEAVE-TYPE');
      if (!mounted) return;
      setState(() {
        _leaveTypeOptions = types;
        _selectedLeaveType = types.isEmpty ? null : types.first.code;
        _optionsError = types.isEmpty ? 'No LEAVE-TYPE field options are configured.' : null;
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optionsError = friendlyErrorMessage('Unable to load leave types: $e');
        _isLoadingOptions = false;
      });
    }
  }

  void _calculateDays() {
    final difference = _endDate.difference(_startDate).inDays;
    _daysController.text = (difference + 1).clamp(1, 9999).toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLeaveType == null || _selectedLeaveType!.isEmpty) {
      _showError('Please select a leave type.');
      return;
    }
    if (_selectedEmployee == null || _selectedApprover == null) {
      _showError('Please select the employee and approver.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      _showError('End Date cannot be before Start Date.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'type': _selectedLeaveType,
        'employee': _selectedEmployee!.id,
        'approver': _selectedApprover!.id,
        'startDate': DateFormat('yyyy-MM-dd').format(_startDate),
        'endDate': DateFormat('yyyy-MM-dd').format(_endDate),
        'days': double.tryParse(_daysController.text) ?? 0.0,
      };

      await _service.createLeaveRequest(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave request created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _showError(friendlyErrorMessage('Unable to create leave request: $e'));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  if (_optionsError != null) ...[
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline),
                            const SizedBox(width: 12),
                            Expanded(child: Text(_optionsError!)),
                            IconButton(onPressed: _loadOptions, icon: const Icon(Icons.refresh)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionCard(
                    title: 'LEAVE DETAILS',
                    children: [
                      DropdownButtonFormField<String>(
                        value: _selectedLeaveType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Leave Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _leaveTypeOptions
                            .map((opt) => DropdownMenuItem(
                                  value: opt.code,
                                  child: Text(opt.description),
                                ))
                            .toList(),
                        validator: (value) => value == null || value.isEmpty ? 'Select a leave type' : null,
                        onChanged: (val) => setState(() => _selectedLeaveType = val),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDatePicker('Start Date', _startDate, (date) {
                              setState(() {
                                _startDate = date;
                                if (_endDate.isBefore(date)) _endDate = date;
                                _calculateDays();
                              });
                            }),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildDatePicker('End Date', _endDate, (date) {
                              setState(() {
                                _endDate = date;
                                _calculateDays();
                              });
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _daysController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Total Days',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSectionCard(
                    title: 'PERSONNEL',
                    children: [
                      PartnerSearchDropdown(
                        role: 'EMPLOYEE',
                        label: 'Select Employee',
                        onPartnerSelected: (partner) => _selectedEmployee = partner,
                        validator: (partner) => partner == null ? 'Select an employee' : null,
                      ),
                      const SizedBox(height: 16),
                      PartnerSearchDropdown(
                        role: 'EMPLOYEE',
                        label: 'Select Approver',
                        onPartnerSelected: (partner) => _selectedApprover = partner,
                        validator: (partner) => partner == null ? 'Select an approver' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSubmitting || _leaveTypeOptions.isEmpty ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('CREATE REQUEST'),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, ValueChanged<DateTime> onPicked) {
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
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(date)),
      ),
    );
  }
}
