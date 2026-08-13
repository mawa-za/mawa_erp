import 'package:flutter/material.dart';

import '../models/purple_configuration.dart';
import '../services/purple_configuration_service.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class PurpleConfigurationScreen extends StatefulWidget {
  const PurpleConfigurationScreen({super.key});

  @override
  State<PurpleConfigurationScreen> createState() => _PurpleConfigurationScreenState();
}

class _PurpleConfigurationScreenState extends State<PurpleConfigurationScreen> {
  final _service = PurpleConfigurationService();
  final _formKey = GlobalKey<FormState>();
  final _slug = TextEditingController();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _logo = TextEditingController();
  final _email = TextEditingController();
  final _cellphone = TextEditingController();
  PurpleConfiguration? _configuration;
  List<Map<String, dynamic>> _products = const [];
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  bool _bookings = true;
  bool _requests = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in [_slug, _name, _description, _logo, _email, _cellphone]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait([_service.load(), _service.products()]);
      final configuration = values[0] as PurpleConfiguration;
      final provider = configuration.provider;
      _slug.text = '${provider['publicSlug'] ?? ''}';
      _name.text = '${provider['displayName'] ?? ''}';
      _description.text = '${provider['description'] ?? ''}';
      _logo.text = '${provider['logoUrl'] ?? ''}';
      _email.text = '${provider['contactEmail'] ?? ''}';
      _cellphone.text = '${provider['contactNumber'] ?? ''}';
      _active = _bool(provider['active'], true);
      _bookings = _bool(provider['bookingEnabled'], true);
      _requests = _bool(provider['serviceRequestEnabled'], true);
      if (mounted) setState(() {
        _configuration = configuration;
        _products = values[1] as List<Map<String, dynamic>>;
      });
    } catch (error) {
      _show(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProvider() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.saveProvider({
        'publicSlug': _slug.text.trim(),
        'displayName': _name.text.trim(),
        'description': _description.text.trim(),
        'logoUrl': _logo.text.trim(),
        'contactEmail': _email.text.trim(),
        'contactNumber': _cellphone.text.trim(),
        'bookingEnabled': _bookings,
        'serviceRequestEnabled': _requests,
        'active': _active,
      });
      _message('Purple provider profile saved');
      await _load();
    } catch (error) {
      _show(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _serviceDialog([Map<String, dynamic>? existing]) async {
    String? productId = existing?['productId']?.toString();
    final displayName = TextEditingController(text: '${existing?['displayName'] ?? ''}');
    final description = TextEditingController(text: '${existing?['description'] ?? ''}');
    final duration = TextEditingController(text: '${existing?['durationMinutes'] ?? 30}');
    final interval = TextEditingController(text: '${existing?['slotIntervalMinutes'] ?? 30}');
    final location = TextEditingController(text: '${existing?['location'] ?? ''}');
    bool booking = _bool(existing?['bookingEnabled'], true);
    bool request = _bool(existing?['serviceRequestEnabled'], true);
    bool active = _bool(existing?['active'], true);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Enrol Purple service' : 'Edit Purple service'),
        content: SizedBox(width: 560, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SearchableDropdownFormField<String>(
            value: _products.any((p) => '${p['id']}' == productId) ? productId : null,
            decoration: const InputDecoration(labelText: 'MAWA product/service'),
            items: _products.map((p) => DropdownMenuItem(value: '${p['id']}', child: Text('${p['description'] ?? p['code']}'))).toList(),
            onChanged: existing == null ? (value) => setLocal(() => productId = value) : null,
          ),
          TextField(controller: displayName, decoration: const InputDecoration(labelText: 'Purple display name')),
          TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Customer description')),
          Row(children: [
            Expanded(child: TextField(controller: duration, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duration (minutes)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: interval, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Slot interval'))),
          ]),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location (optional)')),
          SwitchListTile(value: booking, onChanged: (v) => setLocal(() => booking = v), title: const Text('Available for bookings')),
          SwitchListTile(value: request, onChanged: (v) => setLocal(() => request = v), title: const Text('Available for service requests')),
          SwitchListTile(value: active, onChanged: (v) => setLocal(() => active = v), title: const Text('Active')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: productId == null ? null : () async {
            try {
              await _service.saveService({
                'productId': productId,
                'displayName': displayName.text.trim(),
                'description': description.text.trim(),
                'durationMinutes': int.tryParse(duration.text) ?? 30,
                'slotIntervalMinutes': int.tryParse(interval.text) ?? 30,
                'bufferBeforeMinutes': existing?['bufferBeforeMinutes'] ?? 0,
                'bufferAfterMinutes': existing?['bufferAfterMinutes'] ?? 0,
                'location': location.text.trim(),
                'displayOrder': existing?['displayOrder'] ?? 0,
                'bookingEnabled': booking,
                'serviceRequestEnabled': request,
                'active': active,
              });
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) { _show(error); }
          }, child: const Text('Save')),
        ],
      )),
    );
    displayName.dispose(); description.dispose(); duration.dispose(); interval.dispose(); location.dispose();
    if (saved == true) await _load();
  }

  Future<void> _availabilityDialog([Map<String, dynamic>? existing]) async {
    final services = _configuration?.services ?? const [];
    String? serviceId = existing?['serviceEnrolmentId']?.toString();
    int day = int.tryParse('${existing?['dayOfWeek'] ?? 1}') ?? 1;
    final start = TextEditingController(text: '${existing?['startTime'] ?? '08:00'}');
    final end = TextEditingController(text: '${existing?['endTime'] ?? '17:00'}');
    final location = TextEditingController(text: '${existing?['location'] ?? ''}');
    final saved = await showDialog<bool>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(existing == null ? 'Add availability' : 'Edit availability'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          SearchableDropdownFormField<String>(
            value: services.any((s) => '${s['id']}' == serviceId) ? serviceId : null,
            decoration: const InputDecoration(labelText: 'Purple service'),
            items: services.map((s) => DropdownMenuItem(value: '${s['id']}', child: Text('${s['displayName']}'))).toList(),
            onChanged: (value) => setLocal(() => serviceId = value),
          ),
          SearchableDropdownFormField<int>(
            value: day,
            decoration: const InputDecoration(labelText: 'Day'),
            items: List.generate(7, (i) => DropdownMenuItem(value: i + 1, child: Text(const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][i]))),
            onChanged: (value) => setLocal(() => day = value ?? 1),
          ),
          Row(children: [
            Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: 'Start time (HH:mm)'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: 'End time (HH:mm)'))),
          ]),
          TextField(controller: location, decoration: const InputDecoration(labelText: 'Location (optional)')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: serviceId == null ? null : () async {
            try {
              await _service.saveAvailabilityRule({
                'id': existing?['id'], 'serviceEnrolmentId': serviceId, 'dayOfWeek': day,
                'startTime': start.text.trim(), 'endTime': end.text.trim(),
                'location': location.text.trim(), 'active': true,
              });
              if (context.mounted) Navigator.pop(context, true);
            } catch (error) { _show(error); }
          }, child: const Text('Save')),
        ],
      ),
    ));
    start.dispose(); end.dispose(); location.dispose();
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purple Customer App')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Provider profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Control how this tenant appears to customers in Purple.'),
            const SizedBox(height: 16),
            Wrap(spacing: 16, runSpacing: 12, children: [
              SizedBox(width: 340, child: TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Display name'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
              SizedBox(width: 340, child: TextFormField(controller: _slug, decoration: const InputDecoration(labelText: 'Public URL name'), validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null)),
              SizedBox(width: 340, child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Contact email'))),
              SizedBox(width: 340, child: TextFormField(controller: _cellphone, decoration: const InputDecoration(labelText: 'Contact cellphone'))),
              SizedBox(width: 696, child: TextFormField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Description'))),
              SizedBox(width: 696, child: TextFormField(controller: _logo, decoration: const InputDecoration(labelText: 'Logo URL'))),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: const Text('Listed in Purple')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _bookings, onChanged: (v) => setState(() => _bookings = v), title: const Text('Accept bookings')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: _requests, onChanged: (v) => setState(() => _requests = v), title: const Text('Accept service requests')),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _saving ? null : _saveProvider, icon: const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save provider'))),
          ])))),
          const SizedBox(height: 16),
          _section(
            title: 'Services offered on Purple',
            action: FilledButton.icon(onPressed: () => _serviceDialog(), icon: const Icon(Icons.add), label: const Text('Enrol service')),
            children: (_configuration?.services ?? const []).map((item) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.design_services_outlined)),
              title: Text('${item['displayName'] ?? ''}'),
              subtitle: Text('${item['durationMinutes'] ?? 30} minutes • ${_bool(item['bookingEnabled'], false) ? 'Bookings' : ''}${_bool(item['serviceRequestEnabled'], false) ? ' Service requests' : ''}'),
              onTap: () => _serviceDialog(item),
              trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await _service.deleteService('${item['id']}'); await _load(); }),
            )).toList(),
          ),
          const SizedBox(height: 16),
          _section(
            title: 'Booking availability',
            action: FilledButton.icon(onPressed: (_configuration?.services.isEmpty ?? true) ? null : () => _availabilityDialog(), icon: const Icon(Icons.add), label: const Text('Add hours')),
            children: (_configuration?.availabilityRules ?? const []).map((item) {
              final service = (_configuration?.services ?? const []).cast<Map<String, dynamic>?>().firstWhere((s) => '${s?['id']}' == '${item['serviceEnrolmentId']}', orElse: () => null);
              final day = int.tryParse('${item['dayOfWeek']}') ?? 1;
              final dayIndex = day < 1 ? 0 : (day > 7 ? 6 : day - 1);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.schedule_outlined)),
                title: Text('${service?['displayName'] ?? 'Service'} • ${const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][dayIndex]}'),
                subtitle: Text('${item['startTime']} – ${item['endTime']}${('${item['location'] ?? ''}').isEmpty ? '' : ' • ${item['location']}'}'),
                onTap: () => _availabilityDialog(item),
                trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { await _service.deleteAvailabilityRule('${item['id']}'); await _load(); }),
              );
            }).toList(),
          ),
        ]),
      ),
    );
  }

  Widget _section({required String title, required Widget action, required List<Widget> children}) {
    return Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), action]),
      const Divider(height: 28),
      if (children.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text('Nothing has been configured yet.')) else ...children,
    ])));
  }

  bool _bool(dynamic value, bool fallback) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '${value}'.toLowerCase() == 'true';
  }

  void _show(Object error) => _message(error.toString().replaceFirst('Exception: ', ''), error: true);
  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value), backgroundColor: error ? Theme.of(context).colorScheme.error : null));
  }
}
