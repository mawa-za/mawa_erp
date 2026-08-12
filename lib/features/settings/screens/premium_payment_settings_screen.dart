import 'package:flutter/material.dart';

import '../../../core/services/setting_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PremiumPaymentSettingsScreen extends StatefulWidget {
  const PremiumPaymentSettingsScreen({super.key});

  @override
  State<PremiumPaymentSettingsScreen> createState() => _PremiumPaymentSettingsScreenState();
}

class _PremiumPaymentSettingsScreenState extends State<PremiumPaymentSettingsScreen> {
  final _controller = TextEditingController(text: '3');
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await SettingService().getSettings();
      final matches = settings.where((s) =>
          s.type.trim().toUpperCase() == 'MEMBERSHIP' &&
          s.attribute.trim().toUpperCase() == 'MAX_PREMIUM_PAYMENT_MONTHS');
      if (matches.isNotEmpty && int.tryParse(matches.first.value) != null) {
        _controller.text = matches.first.value;
      }
    } catch (e) {
      _error = friendlyErrorMessage(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > 24) {
      setState(() => _error = 'Enter a value between 1 and 24 months.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await SettingService().updateSetting('MEMBERSHIP', 'MAX_PREMIUM_PAYMENT_MONTHS', '$value');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium payment limit saved.')));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Premium Payment Settings')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Text('Limit how many months of membership premiums can be processed in one online ERP payment.'),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Maximum premium months per payment',
                      helperText: 'Default is 3 months.',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(_saving ? 'Saving...' : 'Save'),
                  ),
                ],
              ),
      );
}
