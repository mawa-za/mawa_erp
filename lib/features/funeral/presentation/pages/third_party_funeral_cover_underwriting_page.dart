import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/api_client.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class ThirdPartyFuneralCoverUnderwritingPage extends StatefulWidget {
  const ThirdPartyFuneralCoverUnderwritingPage({super.key});

  @override
  State<ThirdPartyFuneralCoverUnderwritingPage> createState() =>
      _ThirdPartyFuneralCoverUnderwritingPageState();
}

class _ThirdPartyFuneralCoverUnderwritingPageState
    extends State<ThirdPartyFuneralCoverUnderwritingPage> {
  final _api = ApiClient();
  List<Map<String, dynamic>> _underwriters = [];
  List<Map<String, dynamic>> _covers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        _api.get('/v2/funeral-underwriting/underwriters'),
        _api.get('/v2/funeral-underwriting/covers'),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        throw AppException(responses.firstWhere((r) => r.statusCode != 200).body);
      }
      if (!mounted) return;
      setState(() {
        _underwriters = (jsonDecode(responses[0].body) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => (e['status'] ?? '').toString().toUpperCase() == 'ACTIVE')
            .toList();
        _covers = (jsonDecode(responses[1].body) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to load funeral cover underwriting: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, dynamic>?> _selectCoveredParty() async {
    final search = TextEditingController();
    List<Map<String, dynamic>> rows = [];
    bool loading = false;
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> runSearch() async {
            setDialogState(() => loading = true);
            try {
              final response = await _api.get(
                '/v2/funeral-underwriting/eligible-parties',
                queryParameters: {'query': search.text.trim()},
              );
              if (response.statusCode != 200) throw AppException(response.body);
              setDialogState(() {
                rows = (jsonDecode(response.body) as List)
                    .map((e) => Map<String, dynamic>.from(e as Map))
                    .toList();
              });
            } finally {
              setDialogState(() => loading = false);
            }
          }

          return AlertDialog(
            title: const Row(children: [CircleAvatar(child: Icon(Icons.person_search_outlined)), SizedBox(width: 12), Text('Select Member or Dependent')]),
            content: SizedBox(
              width: 680,
              height: 470,
              child: Column(
                children: [
                  TextField(
                    controller: search,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Name, ID number, partner or membership number',
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
                            ? const Center(child: Text('Search for a member or dependent to underwrite.'))
                            : ListView.separated(
                                itemCount: rows.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (_, index) {
                                  final row = rows[index];
                                  return ListTile(
                                    leading: CircleAvatar(
                                      child: Icon(
                                        row['coveredPartyType'] == 'DEPENDENT'
                                            ? Icons.group_outlined
                                            : Icons.person_outline,
                                      ),
                                    ),
                                    title: Text(row['coveredPartyName']?.toString() ?? ''),
                                    subtitle: Text(
                                      '${row['coveredPartyType'] ?? ''} • Membership ${row['membershipNo'] ?? ''}\n'
                                      '${row['identityNumber'] ?? ''}',
                                    ),
                                    isThreeLine: true,
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

  Future<void> _captureCover() async {
    if (_underwriters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configure and activate an underwriter before capturing cover.'),
        ),
      );
      return;
    }
    final key = GlobalKey<FormState>();
    String underwriterId = _underwriters.first['id'].toString();
    Map<String, dynamic>? party;
    final policyNo = TextEditingController();
    final amount = TextEditingController();
    final effectiveFrom = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final effectiveTo = TextEditingController();
    final notes = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Row(children: [CircleAvatar(child: Icon(Icons.policy_outlined)), SizedBox(width: 12), Text('Underwrite Funeral Cover')]),
          content: SizedBox(
            width: 660,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person_search_outlined)),
                      title: Text(party?['coveredPartyName']?.toString() ??
                          'Select member or dependent'),
                      subtitle: party == null
                          ? const Text('Required')
                          : Text(
                              '${party!['coveredPartyType']} • Membership ${party!['membershipNo']}\n'
                              '${party!['identityNumber'] ?? ''}',
                            ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final selected = await _selectCoveredParty();
                        if (selected != null) setDialogState(() => party = selected);
                      },
                    ),
                    const SizedBox(height: 8),
                    SearchableDropdownFormField<String>(
                      value: underwriterId,
                      decoration: const InputDecoration(
                        labelText: 'Underwriter',
                        border: OutlineInputBorder(),
                      ),
                      items: _underwriters
                          .map((item) => DropdownMenuItem(
                                value: item['id'].toString(),
                                child: Text(item['name']?.toString() ?? item['code'].toString()),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => underwriterId = value ?? underwriterId),
                    ),
                    const SizedBox(height: 12),
                    _field(policyNo, 'External policy number'),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Cover amount (R)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        return parsed == null || parsed <= 0
                            ? 'Enter an amount greater than zero'
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(effectiveFrom, 'Effective from'),
                    _dateField(effectiveTo, 'Effective to', required: false),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Underwriting notes',
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
                if (party == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Select a member or dependent.')),
                  );
                  return;
                }
                if (key.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit for underwriting'),
            ),
          ],
        ),
      ),
    );
    if (save != true || party == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await _api.post('/v2/funeral-underwriting/covers', body: {
        'underwriterId': underwriterId,
        'externalPolicyNo': policyNo.text.trim(),
        'membershipId': party!['membershipId'],
        'coveredPartnerId': party!['coveredPartnerId'],
        'coveredPartyType': party!['coveredPartyType'],
        'membershipDependentId': party!['membershipDependentId'],
        'coverAmountCents': (double.parse(amount.text) * 100).round(),
        'effectiveFrom': effectiveFrom.text,
        'effectiveTo': effectiveTo.text.trim().isEmpty ? null : effectiveTo.text,
        'underwritingNotes': notes.text.trim(),
        'requestedBy': prefs.getString('userId') ?? 'unknown',
        'beneficiaries': const [],
      });
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw AppException(response.body);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Funeral cover submitted for underwriting.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Unable to submit underwriting: $error'))),
        );
      }
    }
  }

  Future<void> _decide(Map<String, dynamic> row, String status) async {
    final current = (row['status'] ?? '').toString().toUpperCase();
    if (current.startsWith('PENDING_')) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final response = await _api.post(
        '/v2/funeral-underwriting/covers/${row['id']}/decision',
        body: {
          'status': status,
          'requestedBy': prefs.getString('userId') ?? 'unknown',
          'notes': 'Requested from Funeral Cover Underwriting',
        },
      );
      if (response.statusCode != 200) throw AppException(response.body);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$status request submitted for approval.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Unable to update underwriting decision: $error'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Funeral Cover Underwriting')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _captureCover,
        icon: const Icon(Icons.add),
        label: const Text('Underwrite member'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _covers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No funeral covers have been submitted for underwriting. Select a member or dependent to begin.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                    itemCount: _covers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = _covers[index];
                      final cents = (row['cover_amount_cents'] as num?)?.toInt() ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.policy_outlined)),
                          title: Text(row['covered_party_name']?.toString() ??
                              row['holder_name']?.toString() ?? ''),
                          subtitle: Text(
                            '${row['covered_party_type'] ?? ''} • Membership ${row['membership_no'] ?? ''}\n'
                            '${row['underwriter_name'] ?? ''} • ${row['external_policy_no'] ?? ''}\n'
                            'R ${(cents / 100).toStringAsFixed(2)} • ${row['status'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: (row['status'] ?? '').toString().toUpperCase().startsWith('PENDING_')
                              ? const Tooltip(message: 'Approval pending', child: Icon(Icons.hourglass_top_rounded, color: Colors.orange))
                              : PopupMenuButton<String>(
                                  onSelected: (status) => _decide(row, status),
                                  itemBuilder: (_) {
                                    final current = (row['status'] ?? '').toString().toUpperCase();
                                    return [
                                      if (current != 'ACTIVE') const PopupMenuItem(value: 'ACTIVE', child: Text('Request Activation')),
                                      if (current != 'SUSPENDED') const PopupMenuItem(value: 'SUSPENDED', child: Text('Request Suspension')),
                                      if (current != 'CANCELLED') const PopupMenuItem(value: 'CANCELLED', child: Text('Request Cancellation')),
                                    ];
                                  },
                                ),
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

  Widget _dateField(
    TextEditingController controller,
    String label, {
    bool required = true,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          validator: required ? _required : null,
          onTap: () async {
            final selected = await showDatePicker(
              context: context,
              initialDate: DateTime.tryParse(controller.text) ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (selected != null) {
              controller.text = selected.toIso8601String().substring(0, 10);
            }
          },
        ),
      );

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
