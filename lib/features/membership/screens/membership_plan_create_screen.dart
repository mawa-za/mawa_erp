import 'package:flutter/material.dart';
import '../services/membership_service.dart';

class MembershipPlanCreateScreen extends StatefulWidget {
  const MembershipPlanCreateScreen({super.key});

  @override
  State<MembershipPlanCreateScreen> createState() => _MembershipPlanCreateScreenState();
}

class _MembershipPlanCreateScreenState extends State<MembershipPlanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _premiumController = TextEditingController();
  final _maxDependentsController = TextEditingController();
  final _currencyController = TextEditingController(text: 'ZAR');
  bool _active = true;
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final premiumDouble = double.tryParse(_premiumController.text) ?? 0.0;
      final payload = {
        'planCode': _planCodeController.text.toUpperCase().replaceAll(' ', '-'),
        'name': _nameController.text,
        'description': _descriptionController.text,
        'premiumCents': (premiumDouble * 100).round(),
        'currency': _currencyController.text,
        'maxDependents': int.tryParse(_maxDependentsController.text) ?? 0,
        'active': _active,
      };

      await MembershipService().createMembershipPlan(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership plan created successfully'), behavior: SnackBarBehavior.floating),
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
        title: const Text('New Membership Plan'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(Icons.settings_outlined, 'PLAN CONFIGURATION'),
              const SizedBox(height: 16),
              _buildCard([
                _buildTextField(_planCodeController, 'Plan Code', 'e.g. SILVER-PLAN', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField(_nameController, 'Plan Name', 'e.g. Silver Membership', validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 16),
                _buildTextField(_descriptionController, 'Description', 'Provide details about the plan', maxLines: 3),
              ]),
              const SizedBox(height: 24),
              _buildSectionHeader(Icons.payments_outlined, 'PRICING & LIMITS'),
              const SizedBox(height: 16),
              _buildCard([
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(_premiumController, 'Monthly Premium', '0.00', prefixText: 'R ', keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v!.isEmpty ? 'Required' : null),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(_currencyController, 'Currency', 'ZAR'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(_maxDependentsController, 'Max Dependents', 'e.g. 5', keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Plan Active', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Inactive plans cannot be linked to members', style: TextStyle(fontSize: 12)),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CREATE PLAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.2),
        ),
      ],
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1, String? prefixText, TextInputType? keyboardType, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _planCodeController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _premiumController.dispose();
    _maxDependentsController.dispose();
    _currencyController.dispose();
    super.dispose();
  }
}
