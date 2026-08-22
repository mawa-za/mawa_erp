import 'package:flutter/material.dart';

import '../../features/partners/models/partner.dart';
import '../../features/partners/partner_service.dart';
import '../errors/app_error.dart';

Future<Partner?> showQuickCustomerCreateDialog(BuildContext context) {
  return showDialog<Partner>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const QuickCustomerCreateDialog(),
  );
}

class QuickCustomerCreateDialog extends StatefulWidget {
  const QuickCustomerCreateDialog({super.key});

  @override
  State<QuickCustomerCreateDialog> createState() => _QuickCustomerCreateDialogState();
}

class _QuickCustomerCreateDialogState extends State<QuickCustomerCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNames = TextEditingController();
  final _surname = TextEditingController();
  final _contactNumber = TextEditingController();
  final _email = TextEditingController();
  bool _saving = false;
  String? _error;

  String? _contactValidator(String? _) {
    if (_contactNumber.text.trim().isEmpty && _email.text.trim().isEmpty) {
      return 'Enter a contact number or email address';
    }
    return null;
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final customer = await PartnerService().createPartner({
        'type': 'INDIVIDUAL',
        'partnerType': 'INDIVIDUAL',
        'partnerRole': 'CUSTOMER',
        'name1': _surname.text.trim().toUpperCase(),
        'name2': _firstNames.text.trim().toUpperCase(),
        'name3': '',
        'email': _email.text.trim(),
        'contactNumber': _contactNumber.text.trim().isEmpty ? null : _contactNumber.text.trim(),
        'status': 'ACTIVE',
      });
      if (mounted) Navigator.of(context).pop(customer);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick Create Customer'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _firstNames,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'First name(s) *', prefixIcon: Icon(Icons.person_outline)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'First name(s) are required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _surname,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Surname *', prefixIcon: Icon(Icons.badge_outlined)),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Surname is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactNumber,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Contact number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: _contactValidator,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email address', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                      return 'Enter a valid email address';
                    }
                    return _contactValidator(value);
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _create,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Create Customer'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _firstNames.dispose();
    _surname.dispose();
    _contactNumber.dispose();
    _email.dispose();
    super.dispose();
  }
}
