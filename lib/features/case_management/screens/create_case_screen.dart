import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../../core/services/user_service.dart';
import '../../../core/models/user.dart';
import '../../../core/routing/app_routes.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

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
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _clientPartnerId == null) {
      if (_clientPartnerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client')));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Case created successfully')));
        if (context.canPop()) {
          context.pop(true);
        }
        context.push('/cases/${newCase.id}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Error: $e')), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Case', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoadingUsers 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSection('Basic Information', [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Case Title*'),
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
                      DropdownButtonFormField<String>(
                        value: _caseType,
                        decoration: const InputDecoration(labelText: 'Case Type'),
                        items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _caseType = val!),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Management', [
                      DropdownButtonFormField<String>(
                        value: _priority,
                        decoration: const InputDecoration(labelText: 'Priority'),
                        items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        onChanged: (val) => setState(() => _priority = val!),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String?>(
                        value: _assignedTo,
                        decoration: const InputDecoration(labelText: 'Assigned To'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Unassigned')),
                          ..._users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.displayName ?? u.username))),
                        ],
                        onChanged: (val) => setState(() => _assignedTo = val),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _buildSection('Billing', [
                      DropdownButtonFormField<String>(
                        value: _billingType,
                        decoration: const InputDecoration(labelText: 'Billing Type'),
                        items: _billingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _billingType = val!),
                      ),
                      if (_billingType == 'HOURLY')
                        TextFormField(
                          controller: _hourlyRateController,
                          decoration: const InputDecoration(labelText: 'Hourly Rate', prefixText: 'R '),
                          keyboardType: TextInputType.number,
                        ),
                      if (_billingType == 'FIXED_FEE')
                        TextFormField(
                          controller: _fixedFeeController,
                          decoration: const InputDecoration(labelText: 'Fixed Fee', prefixText: 'R '),
                          keyboardType: TextInputType.number,
                        ),
                    ]),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _save,
                        child: _isSubmitting ? const CircularProgressIndicator() : const Text('CREATE CASE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            ...children,
          ],
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
