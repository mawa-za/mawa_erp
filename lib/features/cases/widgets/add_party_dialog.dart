import 'package:flutter/material.dart';
import '../models/case_party.dart';
import '../services/case_management_service.dart';
import '../../../core/widgets/partner_search_dropdown.dart';

class AddPartyDialog extends StatefulWidget {
  final String caseId;
  final CaseParty? party; // If provided, we are editing

  const AddPartyDialog({super.key, required this.caseId, this.party});

  @override
  State<AddPartyDialog> createState() => _AddPartyDialogState();
}

class _AddPartyDialogState extends State<AddPartyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _caseService = CaseManagementService();

  late TextEditingController _nameController;
  late TextEditingController _idNumberController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _firmController;
  late TextEditingController _attorneyController;
  late TextEditingController _notesController;

  String? _partnerId;
  String _partyType = 'OTHER';

  final List<String> _partyTypes = [
    'CLIENT', 'APPLICANT', 'RESPONDENT', 'PLAINTIFF', 'DEFENDANT', 
    'WITNESS', 'OPPOSING_ATTORNEY', 'ADVOCATE', 'EXPERT', 'OTHER'
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.party?.partyName);
    _idNumberController = TextEditingController(text: widget.party?.idNumber);
    _emailController = TextEditingController(text: widget.party?.email);
    _phoneController = TextEditingController(text: widget.party?.phoneNumber);
    _firmController = TextEditingController(text: widget.party?.attorneyFirm);
    _attorneyController = TextEditingController(text: widget.party?.attorneyName);
    _notesController = TextEditingController(text: widget.party?.notes);
    _partnerId = widget.party?.partnerId;
    _partyType = widget.party?.partyType ?? 'OTHER';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.party == null) {
        final request = CreateCasePartyRequest(
          partnerId: _partnerId,
          partyName: _nameController.text,
          partyType: _partyType,
          idNumber: _idNumberController.text,
          email: _emailController.text,
          phoneNumber: _phoneController.text,
          attorneyFirm: _firmController.text,
          attorneyName: _attorneyController.text,
          notes: _notesController.text,
        );
        await _caseService.createParty(widget.caseId, request);
      } else {
        final update = {
          'partyName': _nameController.text,
          'partyType': _partyType,
          'idNumber': _idNumberController.text,
          'email': _emailController.text,
          'phoneNumber': _phoneController.text,
          'attorneyFirm': _firmController.text,
          'attorneyName': _attorneyController.text,
          'notes': _notesController.text,
          'partnerId': _partnerId,
        };
        await _caseService.updateParty(widget.party!.id, update);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.party == null ? 'Add Party' : 'Edit Party'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PartnerSearchDropdown(
                label: 'Link to Partner (Optional)',
                onPartnerSelected: (p) => setState(() => _partnerId = p?.id),
                initialPartnerId: _partnerId,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Party Name*'),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _partyType,
                decoration: const InputDecoration(labelText: 'Party Type'),
                items: _partyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) => setState(() => _partyType = v!),
              ),
              TextFormField(controller: _idNumberController, decoration: const InputDecoration(labelText: 'ID/Reg Number')),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email')),
              TextFormField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
              TextFormField(controller: _firmController, decoration: const InputDecoration(labelText: 'Attorney Firm')),
              TextFormField(controller: _attorneyController, decoration: const InputDecoration(labelText: 'Attorney Name')),
              TextFormField(controller: _notesController, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
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
