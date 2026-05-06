import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import '../../../core/widgets/app_dropdown.dart';

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
  String? _selectedType;
  DateTime _validFrom = DateTime.now();

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
        "partnerId": _selectedPartner!.id,
        "type": _selectedType,
        "validFrom": _validFrom.toIso8601String().split('T')[0],
      };

      await MembershipService().addDependent(widget.membershipId, payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dependent added successfully'), behavior: SnackBarBehavior.floating),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
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
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SELECT PERSON',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              PartnerSearchDropdown(
                role: 'INDIVIDUAL',
                label: 'Search by Name or ID...',
                onPartnerSelected: (p) => setState(() => _selectedPartner = p),
              ),
              const SizedBox(height: 24),
              const Text(
                'DEPENDENT DETAILS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              AppDropdownField(
                field: 'DEPENDENT-TYPE',
                label: 'Relationship Type',
                icon: Icons.people_outline,
                value: _selectedType,
                onChanged: (v) => setState(() => _selectedType = v),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              _buildDatePickerField('Valid From', _validFrom, (date) => setState(() => _validFrom = date)),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('ADD DEPENDENT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
            ],
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.grey),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(
                  DateFormat('EEEE, d MMMM yyyy').format(date),
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
