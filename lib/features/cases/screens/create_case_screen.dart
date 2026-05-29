import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../../core/services/user_service.dart';
import '../../../core/models/user.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final CaseManagementService _caseService = CaseManagementService();
  final UserService _userService = UserService();

  bool _isSubmitting = false;

  // Form fields
  final _titleController = TextEditingController();
  final _caseCategoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _courtCaseNoController = TextEditingController();
  final _forumTypeController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _fixedFeeController = TextEditingController();

  String? _clientPartnerId;
  String _caseType = 'CIVIL';
  String _priority = 'NORMAL';
  String? _assignedTo;
  DateTime _openedDate = DateTime.now();
  String _billingType = 'HOURLY';
  bool _billable = true;

  List<User> _users = [];
  bool _isLoadingUsers = true;

  final List<String> _caseTypes = ['CIVIL', 'CRIMINAL', 'FAMILY', 'LABOUR', 'PROPERTY', 'COMMERCIAL', 'ESTATE', 'OTHER'];
  final List<String> _priorities = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];
  final List<String> _billingTypes = ['HOURLY', 'FIXED_FEE', 'CONTINGENCY', 'PRO_BONO'];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await _userService.getUsers();
      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _clientPartnerId == null) {
      if (_clientPartnerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a client')),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final request = CreateLegalCaseRequest(
        title: _titleController.text,
        clientPartnerId: _clientPartnerId!,
        caseType: _caseType,
        caseCategory: _caseCategoryController.text.isNotEmpty ? _caseCategoryController.text : null,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        priority: _priority,
        assignedTo: _assignedTo,
        openedDate: _openedDate,
        courtName: _courtNameController.text.isNotEmpty ? _courtNameController.text : null,
        courtCaseNo: _courtCaseNoController.text.isNotEmpty ? _courtCaseNoController.text : null,
        forumType: _forumTypeController.text.isNotEmpty ? _forumTypeController.text : null,
        billingType: _billingType,
        hourlyRateCents: (double.tryParse(_hourlyRateController.text) ?? 0 * 100).round(),
        fixedFeeCents: (double.tryParse(_fixedFeeController.text) ?? 0 * 100).round(),
        billable: _billable,
      );

      final newCase = await _caseService.createCase(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case created successfully')),
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
      appBar: AppBar(title: const Text('Create New Case')),
      body: _isLoadingUsers 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Case Title*', border: OutlineInputBorder()),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    PartnerSearchDropdown(
                      role: 'CLIENT',
                      label: 'Client*',
                      onPartnerSelected: (partner) => setState(() => _clientPartnerId = partner?.id),
                      validator: (partner) => partner == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _caseType,
                            decoration: const InputDecoration(labelText: 'Case Type', border: OutlineInputBorder()),
                            items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) => setState(() => _caseType = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _caseCategoryController,
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _priority,
                            decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                            items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                            onChanged: (val) => setState(() => _priority = val!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: _assignedTo,
                            decoration: const InputDecoration(labelText: 'Assigned To', border: OutlineInputBorder()),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('Unassigned')),
                              ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))),
                            ],
                            onChanged: (val) => setState(() => _assignedTo = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _openedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) setState(() => _openedDate = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Opened Date*', border: OutlineInputBorder()),
                        child: Text(DateFormat('yyyy-MM-dd').format(_openedDate)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Court Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _courtNameController,
                            decoration: const InputDecoration(labelText: 'Court Name', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _courtCaseNoController,
                            decoration: const InputDecoration(labelText: 'Court Case No', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _forumTypeController,
                      decoration: const InputDecoration(labelText: 'Forum Type (e.g. High Court)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 24),
                    const Text('Billing Information', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _billingType,
                      decoration: const InputDecoration(labelText: 'Billing Type', border: OutlineInputBorder()),
                      items: _billingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _billingType = val!),
                    ),
                    const SizedBox(height: 16),
                    if (_billingType == 'HOURLY')
                      TextFormField(
                        controller: _hourlyRateController,
                        decoration: const InputDecoration(labelText: 'Hourly Rate (Rand)', border: OutlineInputBorder(), prefixText: 'R '),
                        keyboardType: TextInputType.number,
                        validator: (value) => _billingType == 'HOURLY' && (value == null || value.isEmpty) ? 'Required' : null,
                      ),
                    if (_billingType == 'FIXED_FEE')
                      TextFormField(
                        controller: _fixedFeeController,
                        decoration: const InputDecoration(labelText: 'Fixed Fee (Rand)', border: OutlineInputBorder(), prefixText: 'R '),
                        keyboardType: TextInputType.number,
                        validator: (value) => _billingType == 'FIXED_FEE' && (value == null || value.isEmpty) ? 'Required' : null,
                      ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      title: const Text('Billable'),
                      value: _billable,
                      onChanged: (val) => setState(() => _billable = val ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _save,
                        child: _isSubmitting 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('CREATE CASE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caseCategoryController.dispose();
    _descriptionController.dispose();
    _courtNameController.dispose();
    _courtCaseNoController.dispose();
    _forumTypeController.dispose();
    _hourlyRateController.dispose();
    _fixedFeeController.dispose();
    super.dispose();
  }
}
