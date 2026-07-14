import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../models/membership_plan.dart';
import '../widgets/membership_plan_dropdown.dart';
import '../../../core/widgets/partner_search_dropdown.dart';
import 'membership_detail_screen.dart';

class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Partner? _selectedMember;
  MembershipPlan? _selectedPlan;
  DateTime _dateJoined = DateTime.now();
  DateTime _startDate = DateTime.now();

  Future<void> _saveMembership() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a member'), behavior: SnackBarBehavior.floating),
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
      };

      final String membershipId = await MembershipService().createMembership(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Membership created successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green[700],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => MembershipDetailScreen(membershipId: membershipId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red[700], behavior: SnackBarBehavior.floating),
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
              _buildSectionTitle('1. MEMBER SELECTION', Icons.person_search_outlined),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: PartnerSearchDropdown(
                  role: 'MEMBER',
                  label: 'Search for a member...',
                  onPartnerSelected: (p) => setState(() => _selectedMember = p),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle('2. PLAN CONFIGURATION', Icons.card_membership_outlined),
              const SizedBox(height: 16),
              _buildCard([
                MembershipPlanDropdown(
                  value: _selectedPlan?.id,
                  onChanged: (plan) => setState(() => _selectedPlan = plan),
                  validator: (v) => v == null ? 'Please select a plan' : null,
                ),
                const SizedBox(height: 24),
                _buildDatePickerField('Date Joined', _dateJoined, Icons.calendar_today, (date) => setState(() => _dateJoined = date)),
                const SizedBox(height: 16),
                _buildDatePickerField('Policy Start Date', _startDate, Icons.event_available, (date) => setState(() => _startDate = date)),
              ]),
              const SizedBox(height: 48),
              SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: _isLoading ? null : _saveMembership,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text('CREATE MEMBERSHIP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 32),
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

  Widget _buildDatePickerField(String label, DateTime date, IconData icon, Function(DateTime) onPicked) {
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(date),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_month_outlined, size: 20, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
