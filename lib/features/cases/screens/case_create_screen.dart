import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/services/user_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../models/legal_case.dart';
import '../services/case_management_service.dart';
import 'case_detail_screen.dart';

class CaseCreateScreen extends StatefulWidget {
  const CaseCreateScreen({super.key});

  @override
  State<CaseCreateScreen> createState() => _CaseCreateScreenState();
}

class _CaseCreateScreenState extends State<CaseCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final CaseManagementService _caseService = CaseManagementService();
  
  bool _isLoading = false;
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _courtNameController = TextEditingController();
  final _courtCaseNoController = TextEditingController();
  final _forumTypeController = TextEditingController();
  final _hourlyRateController = TextEditingController(text: '0');
  final _fixedFeeController = TextEditingController(text: '0');
  final _openedDateController = TextEditingController();
  
  String? _selectedClientId;
  String _selectedCaseType = 'CIVIL';
  String? _caseCategory;
  String _selectedPriority = 'NORMAL';
  String? _assignedToId;
  String _selectedBillingType = 'HOURLY';
  bool _billable = true;
  DateTime? _openedDate = DateTime.now();

  final List<String> _caseTypes = ['CIVIL', 'CRIMINAL', 'FAMILY', 'LABOUR', 'PROPERTY', 'COMMERCIAL', 'ESTATE', 'OTHER'];
  final List<String> _priorities = ['LOW', 'NORMAL', 'HIGH', 'URGENT'];
  final List<String> _billingTypes = ['HOURLY', 'FIXED_FEE', 'CONTINGENCY', 'PRO_BONO'];

  @override
  void initState() {
    super.initState();
    _openedDateController.text = DateFormat('yyyy-MM-dd').format(_openedDate!);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a client')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = CreateLegalCaseRequest(
        title: _titleController.text,
        clientPartnerId: _selectedClientId!,
        caseType: _selectedCaseType,
        caseCategory: _caseCategory,
        description: _descriptionController.text,
        priority: _selectedPriority,
        assignedTo: _assignedToId,
        openedDate: _openedDate,
        courtName: _courtNameController.text,
        courtCaseNo: _courtCaseNoController.text,
        forumType: _forumTypeController.text,
        billingType: _selectedBillingType,
        hourlyRateCents: (double.tryParse(_hourlyRateController.text) ?? 0 * 100).toInt(),
        fixedFeeCents: (double.tryParse(_fixedFeeController.text) ?? 0 * 100).toInt(),
        billable: _billable,
      );

      final newCase = await _caseService.createCase(request);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: newCase.id)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Legal Case')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Basic Info', [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Case Title*', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    PartnerSearchDropdown(
                      role: 'CLIENT',
                      label: 'Client*',
                      onPartnerSelected: (p) => setState(() => _selectedClientId = p?.id),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCaseType,
                            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                            items: _caseTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (v) => setState(() => _selectedCaseType = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                            onChanged: (v) => _caseCategory = v,
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Court & Legal', [
                    TextFormField(
                      controller: _courtNameController,
                      decoration: const InputDecoration(labelText: 'Court Name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _courtCaseNoController,
                            decoration: const InputDecoration(labelText: 'Court Case No', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _forumTypeController,
                            decoration: const InputDecoration(labelText: 'Forum Type', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                  ]),
                  const SizedBox(height: 24),
                  _buildSection('Billing', [
                    DropdownButtonFormField<String>(
                      value: _selectedBillingType,
                      decoration: const InputDecoration(labelText: 'Billing Type', border: OutlineInputBorder()),
                      items: _billingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _selectedBillingType = v!),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedBillingType == 'HOURLY')
                      TextFormField(
                        controller: _hourlyRateController,
                        decoration: const InputDecoration(labelText: 'Hourly Rate (R)', prefixText: 'R '),
                        keyboardType: TextInputType.number,
                      ),
                    if (_selectedBillingType == 'FIXED_FEE')
                      TextFormField(
                        controller: _fixedFeeController,
                        decoration: const InputDecoration(labelText: 'Fixed Fee (R)', prefixText: 'R '),
                        keyboardType: TextInputType.number,
                      ),
                    CheckboxListTile(
                      title: const Text('Billable'),
                      value: _billable,
                      onChanged: (v) => setState(() => _billable = v ?? true),
                    ),
                  ]),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save Case', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const Divider(),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}
