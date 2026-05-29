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
      if (mounted) {
        setState(() {
          _users = users;
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _clientPartnerId == null) {
      if (_clientPartnerId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a client'), behavior: SnackBarBehavior.floating),
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

      await _caseService.createCase(request);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case created successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('New Case', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoadingUsers 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outline_rounded,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: _inputDecoration('Case Title*', Icons.title_rounded),
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
                                decoration: _inputDecoration('Case Type', Icons.category_rounded),
                                items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                onChanged: (val) => setState(() => _caseType = val!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _caseCategoryController,
                                decoration: _inputDecoration('Category', Icons.label_outline_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: _inputDecoration('Description', Icons.description_rounded),
                          maxLines: 3,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Management & Schedule',
                      icon: Icons.calendar_today_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _priority,
                                decoration: _inputDecoration('Priority', Icons.priority_high_rounded),
                                items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                onChanged: (val) => setState(() => _priority = val!),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                value: _assignedTo,
                                decoration: _inputDecoration('Assigned To', Icons.person_outline_rounded),
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
                            decoration: _inputDecoration('Opened Date*', Icons.event_available_rounded),
                            child: Text(DateFormat('yyyy-MM-dd').format(_openedDate)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Court Details',
                      icon: Icons.gavel_rounded,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _courtNameController,
                                decoration: _inputDecoration('Court Name', Icons.account_balance_rounded),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _courtCaseNoController,
                                decoration: _inputDecoration('Court Case No', Icons.tag_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _forumTypeController,
                          decoration: _inputDecoration('Forum Type (e.g. High Court)', Icons.meeting_room_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Billing Information',
                      icon: Icons.payments_rounded,
                      children: [
                        DropdownButtonFormField<String>(
                          value: _billingType,
                          decoration: _inputDecoration('Billing Type', Icons.receipt_long_rounded),
                          items: _billingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) => setState(() => _billingType = val!),
                        ),
                        const SizedBox(height: 16),
                        if (_billingType == 'HOURLY')
                          TextFormField(
                            controller: _hourlyRateController,
                            decoration: _inputDecoration('Hourly Rate', Icons.timer_rounded).copyWith(prefixText: 'R '),
                            keyboardType: TextInputType.number,
                            validator: (value) => _billingType == 'HOURLY' && (value == null || value.isEmpty) ? 'Required' : null,
                          ),
                        if (_billingType == 'FIXED_FEE')
                          TextFormField(
                            controller: _fixedFeeController,
                            decoration: _inputDecoration('Fixed Fee', Icons.attach_money_rounded).copyWith(prefixText: 'R '),
                            keyboardType: TextInputType.number,
                            validator: (value) => _billingType == 'FIXED_FEE' && (value == null || value.isEmpty) ? 'Required' : null,
                          ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Billable Case', style: TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: const Text('Enable billing for time and disbursements'),
                          value: _billable,
                          onChanged: (val) => setState(() => _billable = val),
                          activeColor: colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _save,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSubmitting 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('CREATE CASE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.black87),
                ),
              ],
            ),
          ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[400]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
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
