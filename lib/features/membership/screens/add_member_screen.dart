import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../../core/widgets/app_dropdown.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Form Fields
  Partner? _selectedMember;
  Partner? _selectedRep;
  String? _selectedMembershipType;
  String? _selectedProduct;
  String? _selectedCreationType;
  String? _selectedSalesArea;
  DateTime _dateJoined = DateTime.now();

  Future<void> _saveMembership() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMember == null || _selectedRep == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both a customer and a sales representative')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        "memberId": _selectedMember!.id,
        "salesRepresentativeId": _selectedRep!.id,
        "membershipType": _selectedMembershipType,
        "productId": _selectedProduct,
        "creationType": _selectedCreationType,
        "salesArea": _selectedSalesArea,
        "dateJoined": _dateJoined.toUtc().toIso8601String(),
      };

      await MembershipService().createMembership(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership created successfully')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Membership'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle('Primary Information'),
              const SizedBox(height: 16),
              PartnerSearchDropdown(
                role: 'CUSTOMER',
                label: 'Select Customer',
                onPartnerSelected: (p) => setState(() => _selectedMember = p),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              PartnerSearchDropdown(
                role: 'EMPLOYEE',
                label: 'Sales Representative',
                onPartnerSelected: (p) => setState(() => _selectedRep = p),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              _buildSectionTitle('Membership Details'),
              const SizedBox(height: 16),
              AppDropdownField(
                field: 'MEMBERSHIP-TYPE',
                label: 'Membership Type',
                icon: Icons.card_membership_outlined,
                value: _selectedMembershipType,
                onChanged: (v) => setState(() => _selectedMembershipType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppDropdownField(
                field: 'PRODUCT',
                label: 'Product',
                icon: Icons.inventory_2_outlined,
                value: _selectedProduct,
                onChanged: (v) => setState(() => _selectedProduct = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: AppDropdownField(
                      field: 'CREATION-TYPE',
                      label: 'Creation Type',
                      value: _selectedCreationType,
                      onChanged: (v) => setState(() => _selectedCreationType = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDropdownField(
                      field: 'SALES-AREA',
                      label: 'Sales Area',
                      value: _selectedSalesArea,
                      onChanged: (v) => setState(() => _selectedSalesArea = v),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDatePickerField('Date Joined', _dateJoined, (date) => setState(() => _dateJoined = date)),
              const SizedBox(height: 32),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveMembership,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('LINK MEMBERSHIP', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[600],
            letterSpacing: 1.2,
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildDatePickerField(String label, DateTime date, Function(DateTime) onPicked) {
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  DateFormat('yyyy-MM-dd').format(date),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
