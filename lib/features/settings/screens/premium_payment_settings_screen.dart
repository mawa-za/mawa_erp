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
  bool _allowDeleteWithoutCashupValidation = false;
  bool _allowPremiumPaymentTransfer = false;
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
      String? valueFor(String attribute) {
        final matches = settings.where((s) =>
            s.type.trim().toUpperCase() == 'MEMBERSHIP' &&
            s.attribute.trim().toUpperCase() == attribute);
        return matches.isEmpty ? null : matches.first.value;
      }

      bool enabled(String? value) {
        final normalized = value?.trim().toLowerCase();
        return normalized == '1' ||
            normalized == 'true' ||
            normalized == 'yes' ||
            normalized == 'on';
      }

      final maxMonths = valueFor('MAX_PREMIUM_PAYMENT_MONTHS');
      if (maxMonths != null && int.tryParse(maxMonths) != null) {
        _controller.text = maxMonths;
      }
      _allowDeleteWithoutCashupValidation = enabled(
        valueFor('ALLOW_PREMIUM_PAYMENT_DELETE_WITHOUT_CASHUP_VALIDATION'),
      );
      _allowPremiumPaymentTransfer = enabled(
        valueFor('ALLOW_PREMIUM_PAYMENT_TRANSFER'),
      );
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
      final settings = SettingService();
      await settings.updateSetting('MEMBERSHIP', 'MAX_PREMIUM_PAYMENT_MONTHS', '$value');
      await settings.updateSetting(
        'MEMBERSHIP',
        'ALLOW_PREMIUM_PAYMENT_DELETE_WITHOUT_CASHUP_VALIDATION',
        _allowDeleteWithoutCashupValidation ? '1' : '0',
      );
      await settings.updateSetting(
        'MEMBERSHIP',
        'ALLOW_PREMIUM_PAYMENT_TRANSFER',
        _allowPremiumPaymentTransfer ? '1' : '0',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium payment settings saved.')),
      );
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
                  const Text(
                    'Control premium payment limits and restricted correction actions. Override options are disabled by default.',
                  ),
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
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text(
                            'Allow deletion without cash-up validation',
                          ),
                          subtitle: const Text(
                            'When enabled, approved premium payment deletions are not restricted to receipts linked to an OPEN cash-up. Cash-up totals are recalculated when links exist.',
                          ),
                          value: _allowDeleteWithoutCashupValidation,
                          onChanged: (value) => setState(
                            () => _allowDeleteWithoutCashupValidation = value,
                          ),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: const Text('Allow manual premium payment transfer'),
                          subtitle: const Text(
                            'Allows a manually captured premium payment posted to the wrong membership to be reassigned to another membership and premium month.',
                          ),
                          value: _allowPremiumPaymentTransfer,
                          onChanged: (value) => setState(
                            () => _allowPremiumPaymentTransfer = value,
                          ),
                        ),
                      ],
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
