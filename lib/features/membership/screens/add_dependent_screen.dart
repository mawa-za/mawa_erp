import 'package:flutter/material.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../models/dependent.dart';

class AddDependentScreen extends StatefulWidget {
  final String membershipId;
  const AddDependentScreen({super.key, required this.membershipId});

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Partner? _selectedPartner;
  DependentType _selectedType = DependentType.OTHER;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPartner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a person'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        "dependentPartnerId": _selectedPartner!.id,
        "dependentType": _selectedType.name,
        "active": true,
        "membershipId": widget.membershipId,
      };

      await MembershipService().addDependent(widget.membershipId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Dependent added successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Add Dependent'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('PERSON SELECTION', Icons.person_search_outlined),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: PartnerSearchDropdown(
                  role: 'INDIVIDUAL',
                  label: 'Search by Name or ID...',
                  onPartnerSelected: (p) => setState(() => _selectedPartner = p),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('RELATIONSHIP DETAILS', Icons.people_outline),
              const SizedBox(height: 16),
              _buildCard([
                DropdownButtonFormField<DependentType>(
                  value: _selectedType,
                  decoration: InputDecoration(
                    labelText: 'Relationship Type',
                    prefixIcon: Icon(Icons.people_outline, color: colorScheme.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: DependentType.values.where((e) => e != DependentType.ANY).map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedType = v!),
                ),
              ]),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('ADD DEPENDENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey[700],
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
        border: Border.all(color: Colors.white),
      ),
      child: Column(children: children),
    );
  }
}
