import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../../laybys/services/layby_service.dart';

class LaybyConfigurationScreen extends StatefulWidget {
  const LaybyConfigurationScreen({super.key});

  @override
  State<LaybyConfigurationScreen> createState() => _LaybyConfigurationScreenState();
}

class _LaybyConfigurationScreenState extends State<LaybyConfigurationScreen> {
  final LaybyService _service = LaybyService();
  final TextEditingController _duration = TextEditingController();
  final TextEditingController _depositPercent = TextEditingController();
  final TextEditingController _penaltyPercent = TextEditingController();
  final TextEditingController _graceDays = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _enabled = true;
  bool _depositRequired = false;
  bool _cancellationApproval = true;
  bool _refundApproval = true;
  bool _reserveStock = true;
  bool _allowShortStock = false;
  String _frequency = 'MONTHLY';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _duration.dispose();
    _depositPercent.dispose();
    _penaltyPercent.dispose();
    _graceDays.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await _service.configuration();
      if (!mounted) return;
      setState(() {
        _enabled = _bool(c['enabled']);
        _frequency = _text(c['default_payment_frequency']).isEmpty ? 'MONTHLY' : _text(c['default_payment_frequency']);
        _duration.text = _text(c['default_duration_months']);
        _depositRequired = _bool(c['deposit_required']);
        _depositPercent.text = _text(c['minimum_deposit_percent']);
        _penaltyPercent.text = _text(c['cancellation_penalty_percent']);
        _graceDays.text = _text(c['default_grace_business_days']);
        _cancellationApproval = _bool(c['require_cancellation_approval']);
        _refundApproval = _bool(c['require_refund_approval']);
        _reserveStock = _bool(c['automatically_reserve_stock']);
        _allowShortStock = _bool(c['allow_stock_short_layby']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.updateConfiguration({
        'enabled': _enabled,
        'defaultPaymentFrequency': _frequency,
        'defaultDurationMonths': int.tryParse(_duration.text) ?? 3,
        'depositRequired': _depositRequired,
        'minimumDepositPercent': double.tryParse(_depositPercent.text.replaceAll(',', '.')) ?? 0,
        'cancellationPenaltyPercent': double.tryParse(_penaltyPercent.text.replaceAll(',', '.')) ?? 1,
        'defaultGraceBusinessDays': int.tryParse(_graceDays.text) ?? 60,
        'requireCancellationApproval': _cancellationApproval,
        'requireRefundApproval': _refundApproval,
        'automaticallyReserveStock': _reserveStock,
        'allowStockShortLayby': _allowShortStock,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Layby configuration saved.')));
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('Layby Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Configure tenant-wide layby terms, stock reservation and cancellation/refund controls.'),
          const SizedBox(height: 18),
          SwitchListTile(title: const Text('Laybys enabled'), subtitle: const Text('Allows Sales & Customers users to create new layby agreements.'), value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
          const Divider(),
          Wrap(spacing: 14, runSpacing: 14, children: [
            SizedBox(width: 280, child: DropdownButtonFormField<String>(value: _frequency, decoration: const InputDecoration(labelText: 'Default payment frequency', border: OutlineInputBorder()), items: const ['WEEKLY', 'FORTNIGHTLY', 'MONTHLY', 'ONCE'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => _frequency = v ?? 'MONTHLY'))),
            SizedBox(width: 240, child: TextField(controller: _duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default duration (months)', border: OutlineInputBorder()))),
            SizedBox(width: 240, child: TextField(controller: _graceDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Default grace (business days)', border: OutlineInputBorder(), helperText: 'Minimum 60'))),
          ]),
          const SizedBox(height: 18),
          SwitchListTile(title: const Text('Deposit required'), value: _depositRequired, onChanged: (v) => setState(() => _depositRequired = v)),
          SizedBox(width: 280, child: TextField(controller: _depositPercent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Minimum deposit %', border: OutlineInputBorder()))),
          const SizedBox(height: 18),
          SizedBox(width: 280, child: TextField(controller: _penaltyPercent, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Cancellation penalty %', border: OutlineInputBorder(), helperText: 'Maximum 1%'))),
          const SizedBox(height: 10),
          SwitchListTile(title: const Text('Require cancellation approval'), value: _cancellationApproval, onChanged: (v) => setState(() => _cancellationApproval = v)),
          SwitchListTile(title: const Text('Require refund approval'), value: _refundApproval, onChanged: (v) => setState(() => _refundApproval = v)),
          const Divider(),
          SwitchListTile(title: const Text('Automatically reserve stock on activation'), value: _reserveStock, onChanged: (v) => setState(() => _reserveStock = v)),
          SwitchListTile(title: const Text('Allow activation when stock cannot be fully reserved'), subtitle: const Text('Recommended off. When disabled, activation fails unless all items can be reserved.'), value: _allowShortStock, onChanged: (v) => setState(() => _allowShortStock = v)),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save Configuration'))),
        ],
      ),
    );
  }
}

String _text(dynamic value) => value == null ? '' : value.toString();
bool _bool(dynamic value) => value == true || value == 1 || _text(value).toLowerCase() == 'true' || _text(value) == '1';
