import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/vat_policy_service.dart';

/// Tenant accounting policy is independent of the Xero connection.
class VatConfigurationScreen extends StatefulWidget {
  const VatConfigurationScreen({super.key});

  @override
  State<VatConfigurationScreen> createState() => _VatConfigurationScreenState();
}

class _VatConfigurationScreenState extends State<VatConfigurationScreen> {
  final _service = VatPolicyService();
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _rate = TextEditingController(text: '0');
  bool _loading = true;
  bool _saving = false;
  bool _vatRegistered = false;
  String _pricing = 'EXCLUSIVE';
  DateTime _effectiveFrom = DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
  List<VatPolicy> _policies = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    _rate.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final policies = await _service.load();
      if (!mounted) return;
      setState(() { _policies = policies; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final tomorrow = DateUtils.dateOnly(DateTime.now().add(const Duration(days: 1)));
    final chosen = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom.isBefore(tomorrow) ? tomorrow : _effectiveFrom,
      firstDate: tomorrow,
      lastDate: DateTime(2100),
    );
    if (chosen != null && mounted) setState(() => _effectiveFrom = chosen);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create VAT policy?'),
        content: const Text('Policies are effective-dated and cannot be edited. This will not update existing invoices or enable Xero posting.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('CREATE POLICY')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await _service.create(
        vatRegistered: _vatRegistered,
        vatRegistrationNumber: _vatRegistered ? _number.text.trim() : null,
        defaultPricingMethod: _vatRegistered ? _pricing : 'EXCLUSIVE',
        standardRatePercent: _vatRegistered ? double.parse(_rate.text.trim()) : 0,
        effectiveFrom: _date(_effectiveFrom),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('VAT policy created. Invoice integration remains disabled.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VAT Configuration'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh policies')]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), TextButton(onPressed: _load, child: const Text('RETRY'))]))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Tenant VAT policies', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_policies.isEmpty) const Text('No VAT policy has been configured for this tenant.')
                    else ..._policies.map((p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(p.vatRegistered ? Icons.receipt_long_outlined : Icons.money_off_outlined),
                      title: Text(p.vatRegistered ? 'VAT registered · ${p.standardRatePercent}%' : 'Not VAT registered'),
                      subtitle: Text('Effective ${p.effectiveFrom}${p.effectiveTo == null ? '' : ' – ${p.effectiveTo}'} · ${p.defaultPricingMethod}'),
                    )),
                  ]))),
                  const SizedBox(height: 12),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('New effective-dated policy', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Policies are append-only. Existing invoices are not modified.'),
                    SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('VAT registered'), value: _vatRegistered, onChanged: _saving ? null : (v) => setState(() { _vatRegistered = v; if (!v) { _rate.text = '0'; _number.clear(); _pricing = 'EXCLUSIVE'; } else if (_rate.text == '0') { _rate.text = '15'; } })),
                    if (_vatRegistered) ...[
                      TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'VAT registration number'), validator: (v) => v == null || v.trim().isEmpty ? 'Enter the VAT registration number' : null),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(value: _pricing, decoration: const InputDecoration(labelText: 'Default invoice pricing'), items: const [DropdownMenuItem(value: 'INCLUSIVE', child: Text('VAT inclusive')), DropdownMenuItem(value: 'EXCLUSIVE', child: Text('VAT exclusive'))], onChanged: _saving ? null : (v) => setState(() => _pricing = v ?? 'EXCLUSIVE')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _rate, decoration: const InputDecoration(labelText: 'Standard VAT rate (%)'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], validator: (v) { final n = double.tryParse(v ?? ''); if (n == null || n < 0 || n > 100) return 'Enter a percentage from 0 to 100'; if ((v?.split('.').length ?? 0) > 2 || ((v?.split('.').length ?? 0) == 2 && v!.split('.').last.length > 4)) return 'Use at most four decimal places'; return null; }),
                    ] else const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No VAT will be charged. The policy will use a 0% rate and exclusive pricing.')),
                    const SizedBox(height: 12),
                    ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.event), title: const Text('Effective from'), subtitle: Text(_date(_effectiveFrom)), trailing: const Icon(Icons.edit_calendar_outlined), onTap: _saving ? null : _pickDate),
                    const SizedBox(height: 8),
                    const Text('New dates cannot overlap an existing policy. To change an open-ended policy, it must first be closed through a controlled backend workflow.', style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'SAVING...' : 'CREATE VAT POLICY')),
                  ])))),
                ]),
    );
  }
}
