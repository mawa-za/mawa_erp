import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../models/membership_plan.dart';
import '../widgets/membership_plan_dropdown.dart';
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
  MembershipPlan? _selectedPlan;
  DateTime _dateJoined = DateTime.now();
  DateTime _startDate = DateTime.now();
  final TextEditingController _membershipNoController = TextEditingController();

  Future<void> _saveMembership() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a membership plan'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final payload = {
        "memberId": _selectedMember!.id,
        "planId": _selectedPlan!.id,
        "startDate": _startDate.toIso8601String().split('T')[0],
        "joinDate": _dateJoined.toIso8601String().split('T')[0],
        "status": "ACTIVE",
        "membershipNo": _membershipNoController.text.trim().isEmpty
            ? null
            : _membershipNoController.text.trim(),
      };

      await MembershipService().createMembership(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership created successfully'), behavior: SnackBarBehavior.floating),
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
        title: const Text('Create Membership'),
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
              _buildSectionTitle('Customer Selection', Icons.person_outline),
              const SizedBox(height: 16),
              PartnerSearchDropdown(
                role: 'CUSTOMER',
                label: 'Select Customer',
                onPartnerSelected: (p) => setState(() => _selectedMember = p),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('Plan & Dates', Icons.card_membership),
              const SizedBox(height: 16),
              MembershipPlanDropdown(
                value: _selectedPlan?.id,
                onChanged: (plan) => setState(() => _selectedPlan = plan),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _membershipNoController,
                decoration: InputDecoration(
                  labelText: 'Membership Number (Optional)',
                  prefixIcon: const Icon(Icons.numbers_outlined, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              _buildDatePickerField('Date Joined', _dateJoined, (date) => setState(() => _dateJoined = date)),
              const SizedBox(height: 16),
              _buildDatePickerField('Start Date', _startDate, (date) => setState(() => _startDate = date)),
              const SizedBox(height: 40),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _saveMembership,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('CREATE MEMBERSHIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                    ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
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

  @override
  void dispose() {
    _membershipNoController.dispose();
    super.dispose();
  }
}
