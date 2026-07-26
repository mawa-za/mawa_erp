import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

class ClaimTypeConfigurationScreen extends StatefulWidget {
  const ClaimTypeConfigurationScreen({super.key});

  @override
  State<ClaimTypeConfigurationScreen> createState() =>
      _ClaimTypeConfigurationScreenState();
}

class _ClaimTypeConfigurationScreenState
    extends State<ClaimTypeConfigurationScreen> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final response = await ApiClient().get('/v2/claim-type-configuration');
    if (response.statusCode != 200) throw Exception(response.body);
    if (!mounted) return;
    setState(() {
      _rows = (jsonDecode(response.body) as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final payload = _rows.asMap().entries.map((entry) {
        final row = entry.value;
        return {
          'claimType': row['claim_type'] ?? row['claimType'],
          'enabled': row['enabled'] == true || row['enabled'] == 1,
          'displayOrder': entry.key + 1,
        };
      }).toList();
      final response = await ApiClient().put(
        '/v2/claim-type-configuration',
        body: payload,
      );
      if (response.statusCode != 200) throw Exception(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Claim type configuration saved.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Claim Type Configuration')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Choose which claim types users may select when processing a claim.',
                ),
                const SizedBox(height: 12),
                ..._rows.map(
                  (row) => Card(
                    child: SwitchListTile(
                      title: Text(
                        (row['claim_type'] ?? row['claimType'])
                            .toString()
                            .replaceAll('_', ' '),
                      ),
                      value: row['enabled'] == true || row['enabled'] == 1,
                      onChanged: (value) =>
                          setState(() => row['enabled'] = value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Configuration'),
                ),
              ],
            ),
    );
  }
}
