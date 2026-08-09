import 'package:flutter/material.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class MembershipPlanCreateScreen extends StatefulWidget {
  final MembershipPlan? plan;
  const MembershipPlanCreateScreen({super.key, this.plan});

  @override
  State<MembershipPlanCreateScreen> createState() => _MembershipPlanCreateScreenState();
}

class _MembershipPlanCreateScreenState extends State<MembershipPlanCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _planCodeController;
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _premiumController;
  late TextEditingController _maxDependentsController;
  late TextEditingController _currencyController;
  late bool _active;
  bool _isSubmitting = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _planCodeController = TextEditingController(text: widget.plan?.planCode ?? '');
    _nameController = TextEditingController(text: widget.plan?.name ?? '');
    _descriptionController = TextEditingController(text: widget.plan?.description ?? '');
    _premiumController = TextEditingController(text: widget.plan != null ? (widget.plan!.premiumCents / 100.0).toString() : '');
    _maxDependentsController = TextEditingController(text: widget.plan?.maxDependents.toString() ?? '');
    _currencyController = TextEditingController(text: widget.plan?.currency ?? 'ZAR');
    _active = widget.plan?.active ?? true;
  }

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

      if (_isEditing) {
        await MembershipService().updateMembershipPlan(widget.plan!.id, payload);
      } else {
        await MembershipService().createMembershipPlan(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Plan ${_isEditing ? 'updated' : 'created'} successfully'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.green[700],
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyErrorMessage('Error: $e')),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Membership Plan' : 'New Membership Plan'),
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
              _buildSectionHeader(Icons.settings_suggest_outlined, 'PLAN IDENTITY'),
              const SizedBox(height: 16),
              _buildCard([
                _buildTextField(
                  _planCodeController,
                  'Unique Plan Code',
                  'e.g. GOLD-2024',
                  icon: Icons.qr_code_rounded,
                  validator: (v) => v!.isEmpty ? 'Code is required' : null,
                  enabled: !_isEditing,
                  helperText: 'Internal reference code for this plan.',
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  _nameController,
                  'Display Name',
                  'e.g. Gold Family Plan',
                  icon: Icons.badge_outlined,
                  validator: (v) => v!.isEmpty ? 'Name is required' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  _descriptionController,
                  'Description',
                  'Tell users what this plan covers...',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
              ]),
              const SizedBox(height: 32),
              _buildSectionHeader(Icons.account_balance_wallet_outlined, 'PRICING & TERMS'),
              const SizedBox(height: 16),
              _buildCard([
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        _premiumController,
                        'Monthly Premium',
                        '0.00',
                        prefixText: 'R ',
                        icon: Icons.payments_outlined,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: _buildTextField(
                        _currencyController,
                        'Currency',
                        'ZAR',
                        icon: Icons.language_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  _maxDependentsController,
                  'Max Dependents Included',
                  '5',
                  icon: Icons.group_outlined,
                  keyboardType: TextInputType.number,
                  helperText: 'Base number of dependents allowed.',
                ),
                const SizedBox(height: 12),
                const Divider(),
                SwitchListTile(
                  title: const Text('Is Plan Active?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Only active plans can be assigned to new members.', style: TextStyle(fontSize: 12)),
                  value: _active,
                  activeColor: colorScheme.primary,
                  onChanged: (v) => setState(() => _active = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ]),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : Text(
                          _isEditing ? 'UPDATE PLAN' : 'CREATE PLAN',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
                        ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Colors.grey[700],
            letterSpacing: 1.5,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    int maxLines = 1,
    String? prefixText,
    IconData? icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool enabled = true,
    String? helperText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 6),
            ],
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          enabled: enabled,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 10),
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400], fontWeight: FontWeight.normal),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade100)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade50,
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
