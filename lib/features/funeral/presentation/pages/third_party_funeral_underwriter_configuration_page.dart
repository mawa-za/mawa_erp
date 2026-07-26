import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api_client.dart';

class ThirdPartyFuneralUnderwriterConfigurationPage extends StatefulWidget {
  const ThirdPartyFuneralUnderwriterConfigurationPage({super.key});

  @override
  State<ThirdPartyFuneralUnderwriterConfigurationPage> createState() =>
      _ThirdPartyFuneralUnderwriterConfigurationPageState();
}

class _ThirdPartyFuneralUnderwriterConfigurationPageState
    extends State<ThirdPartyFuneralUnderwriterConfigurationPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _underwriters = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/funeral-underwriting/underwriters');
      if (response.statusCode != 200) throw Exception(response.body);
      if (!mounted) return;
      setState(() {
        _underwriters = (jsonDecode(response.body) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load underwriters: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _selectOrganisation() async {
    final search = TextEditingController();
    List<Map<String, dynamic>> rows = [];
    bool loading = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> runSearch() async {
            setDialogState(() => loading = true);
            try {
              final response = await _api.get(
                '/v2/partner',
                queryParameters: {'query': search.text.trim()},
              );
              if (response.statusCode != 200) throw Exception(response.body);
              final decoded = (jsonDecode(response.body) as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .where((e) => (e['type'] ?? '').toString().toUpperCase() != 'INDIVIDUAL')
                  .toList();
              setDialogState(() => rows = decoded);
            } finally {
              setDialogState(() => loading = false);
            }
          }

          return AlertDialog(
            title: const Text('Select underwriter organisation'),
            content: SizedBox(
              width: 620,
              height: 440,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Organisation name or partner number',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: runSearch,
                      ),
                    ),
                    onSubmitted: (_) => runSearch(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : rows.isEmpty
                            ? const Center(
                                child: Text('Search for an organisation business partner.'),
                              )
                            : ListView.builder(
                                itemCount: rows.length,
                                itemBuilder: (_, index) {
                                  final row = rows[index];
                                  final name = [row['name2'], row['name3'], row['name1']]
                                      .where((v) => (v ?? '').toString().trim().isNotEmpty)
                                      .join(' ');
                                  return ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.business_outlined),
                                    ),
                                    title: Text(name.isEmpty ? 'Business Partner' : name),
                                    subtitle: Text(
                                      '${row['number'] ?? ''} • ${row['type'] ?? ''}',
                                    ),
                                    onTap: () => Navigator.pop(dialogContext, row),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final formKey = GlobalKey<FormState>();
    final code = TextEditingController(text: existing?['code']?.toString() ?? '');
    final name = TextEditingController(text: existing?['name']?.toString() ?? '');
    final days = TextEditingController(
      text: existing?['settlement_terms_days']?.toString() ?? '30',
    );
    final notes = TextEditingController(text: existing?['notes']?.toString() ?? '');
    String partnerId = existing?['partner_id']?.toString() ?? '';
    String partnerLabel = existing?['name']?.toString() ?? '';
    String mode = existing?['integration_mode']?.toString() ?? 'MANUAL';
    String status = existing?['status']?.toString() ?? 'ACTIVE';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add underwriter' : 'Edit underwriter'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
                      title: Text(partnerLabel.isEmpty
                          ? 'Select an organisation business partner'
                          : partnerLabel),
                      subtitle: Text(partnerId.isEmpty ? 'Required' : partnerId),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final selected = await _selectOrganisation();
                        if (selected == null) return;
                        final selectedName = [
                          selected['name2'],
                          selected['name3'],
                          selected['name1'],
                        ].where((v) => (v ?? '').toString().trim().isNotEmpty).join(' ');
                        setDialogState(() {
                          partnerId = selected['id'].toString();
                          partnerLabel = selectedName;
                          if (name.text.trim().isEmpty) name.text = selectedName;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    _field(code, 'Underwriter code'),
                    _field(name, 'Underwriter name'),
                    DropdownButtonFormField<String>(
                      value: mode,
                      decoration: const InputDecoration(
                        labelText: 'Integration mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MANUAL', child: Text('Manual')), 
                        DropdownMenuItem(value: 'API', child: Text('API')),
                      ],
                      onChanged: (value) => setDialogState(() => mode = value ?? mode),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                        DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                      ],
                      onChanged: (value) => setDialogState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: days,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Settlement terms (days)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (partnerId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select an organisation business partner.')),
                  );
                  return;
                }
                if (formKey.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      final response = await _api.post('/v2/funeral-underwriting/underwriters', body: {
        if (existing?['id'] != null) 'id': existing!['id'],
        'partnerId': partnerId,
        'code': code.text.trim().toUpperCase(),
        'name': name.text.trim(),
        'status': status,
        'integrationMode': mode,
        'settlementTermsDays': int.parse(days.text),
        'notes': notes.text.trim(),
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.body);
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save underwriter: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Funeral Cover Underwriter Configuration')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add underwriter'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _underwriters.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No underwriters are configured. Add the organisations that provide third-party funeral cover.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _underwriters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = _underwriters[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
                          title: Text(row['name']?.toString() ?? ''),
                          subtitle: Text(
                            '${row['code'] ?? ''} • ${row['integration_mode'] ?? 'MANUAL'}\n'
                            '${row['settlement_terms_days'] ?? 0} day settlement',
                          ),
                          isThreeLine: true,
                          trailing: Chip(label: Text(row['status']?.toString() ?? 'ACTIVE')),
                          onTap: () => _edit(row),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  static Widget _field(TextEditingController controller, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          validator: _required,
        ),
      );

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
