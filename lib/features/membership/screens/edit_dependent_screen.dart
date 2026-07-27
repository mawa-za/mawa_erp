import 'package:flutter/material.dart';
import '../models/dependent.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../../core/widgets/partner_search_dropdown.dart';

class EditDependentScreen extends StatefulWidget {
  final String membershipId;
  final Dependent dependent;

  const EditDependentScreen({
    super.key,
    required this.membershipId,
    required this.dependent,
  });

  @override
  State<EditDependentScreen> createState() => _EditDependentScreenState();
}

class _EditDependentScreenState extends State<EditDependentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  Partner? _replacementPartner;
  late DependentType _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = DependentType.fromString(widget.dependent.dependentType);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_replacementPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select the replacement person')),
      );
      return;
    }
    if (_replacementPartner!.id == widget.dependent.dependentPartnerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Replacement must be a different person')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final change = await MembershipService().replaceDependent(
        widget.membershipId,
        widget.dependent.id,
        {
          'dependentPartnerId': _replacementPartner!.id,
          'dependentType': _selectedType.name,
          'reason': _reasonController.text.trim(),
        },
      );
      if (!mounted) return;
      final pending = change.status == 'PENDING_APPROVAL';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(pending
              ? 'Dependent replacement submitted for approval'
              : 'Dependent replaced successfully'),
          backgroundColor: pending ? Colors.orange[800] : Colors.green[700],
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700]),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Replace Dependent'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Current dependent: ${widget.dependent.fullName}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      PartnerSearchDropdown(
                        role: '',
                        label: 'Select replacement person',
                        onPartnerSelected: (partner) => setState(() => _replacementPartner = partner),
                        validator: (partner) => partner == null ? 'Replacement person is required' : null,
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<DependentType>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Replacement Relationship',
                          border: OutlineInputBorder(),
                        ),
                        items: DependentType.values
                            .where((type) => type != DependentType.ANY && type != DependentType.MAIN_MEMBER)
                            .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                            .toList(),
                        onChanged: (value) => setState(() => _selectedType = value!),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Reason *',
                          helperText: 'The existing dependent remains in the audit history.',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Reason is required' : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _save,
                  icon: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.find_replace_outlined),
                  label: const Text('REPLACE DEPENDENT', style: TextStyle(fontWeight: FontWeight.bold)),
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
    _reasonController.dispose();
    super.dispose();
  }
}
