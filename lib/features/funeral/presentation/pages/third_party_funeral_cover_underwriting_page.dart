import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/api_client.dart';

class ThirdPartyFuneralCoverUnderwritingPage extends StatefulWidget {
  const ThirdPartyFuneralCoverUnderwritingPage({super.key});

  @override
  State<ThirdPartyFuneralCoverUnderwritingPage> createState() =>
      _ThirdPartyFuneralCoverUnderwritingPageState();
}

class _ThirdPartyFuneralCoverUnderwritingPageState
    extends State<ThirdPartyFuneralCoverUnderwritingPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late final TabController _tabController;
  List<Map<String, dynamic>> _underwriters = [];
  List<Map<String, dynamic>> _covers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final responses = await Future.wait([
        _api.get('/v2/funeral-underwriting/underwriters'),
        _api.get('/v2/funeral-underwriting/covers'),
      ]);
      for (final response in responses) {
        if (response.statusCode != 200) throw Exception(response.body);
      }
      if (!mounted) return;
      setState(() {
        _underwriters = (jsonDecode(responses[0].body) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
        _covers = (jsonDecode(responses[1].body) as List)
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load underwriting configuration: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addUnderwriter() async {
    final key = GlobalKey<FormState>();
    final partnerId = TextEditingController();
    final code = TextEditingController();
    final name = TextEditingController();
    final settlementDays = TextEditingController(text: '30');
    final notes = TextEditingController();
    String integrationMode = 'MANUAL';

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add funeral cover underwriter'),
          content: SizedBox(
            width: 560,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Create the external organisation responsible for underwriting and settling third-party funeral cover.',
                    ),
                    const SizedBox(height: 16),
                    _textField(partnerId, 'Partner ID', helper: 'Select or copy the organisation partner ID.'),
                    _textField(code, 'Underwriter code'),
                    _textField(name, 'Underwriter name'),
                    DropdownButtonFormField<String>(
                      value: integrationMode,
                      decoration: const InputDecoration(
                        labelText: 'Integration mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'MANUAL', child: Text('Manual')),
                        DropdownMenuItem(value: 'API', child: Text('API')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => integrationMode = value ?? 'MANUAL'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: settlementDays,
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
                if (key.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save underwriter'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    await _post(
      '/v2/funeral-underwriting/underwriters',
      {
        'partnerId': partnerId.text.trim(),
        'code': code.text.trim().toUpperCase(),
        'name': name.text.trim(),
        'status': 'ACTIVE',
        'integrationMode': integrationMode,
        'settlementTermsDays': int.parse(settlementDays.text),
        'notes': notes.text.trim(),
      },
      'Underwriter saved',
    );
  }

  Future<void> _addCover() async {
    if (_underwriters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an underwriter before capturing funeral cover.')),
      );
      _tabController.animateTo(0);
      return;
    }

    final key = GlobalKey<FormState>();
    String underwriterId = _underwriters.first['id'].toString();
    final policyNo = TextEditingController();
    final membershipId = TextEditingController();
    final holderName = TextEditingController();
    final holderIdentity = TextEditingController();
    final deceasedName = TextEditingController();
    final deceasedIdentity = TextEditingController();
    final amount = TextEditingController();
    final effectiveFrom = TextEditingController(
      text: DateTime.now().toIso8601String().substring(0, 10),
    );
    final effectiveTo = TextEditingController();
    final notes = TextEditingController();

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Capture third-party funeral cover'),
          content: SizedBox(
            width: 620,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: underwriterId,
                      decoration: const InputDecoration(
                        labelText: 'Underwriter',
                        border: OutlineInputBorder(),
                      ),
                      items: _underwriters
                          .map(
                            (item) => DropdownMenuItem(
                              value: item['id'].toString(),
                              child: Text(item['name']?.toString() ?? item['code'].toString()),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => underwriterId = value ?? underwriterId),
                    ),
                    const SizedBox(height: 12),
                    _textField(policyNo, 'External policy number'),
                    _textField(
                      membershipId,
                      'Linked membership ID',
                      required: false,
                      helper: 'Optional when the external cover is not yet linked to a MAWA membership.',
                    ),
                    _textField(holderName, 'Policy holder name'),
                    _textField(holderIdentity, 'Policy holder identity number'),
                    _textField(deceasedName, 'Deceased name', required: false),
                    _textField(deceasedIdentity, 'Deceased identity number', required: false),
                    TextFormField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                      decoration: const InputDecoration(
                        labelText: 'Cover amount (R)',
                        helperText: 'Enter the approved or requested external cover amount.',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final parsed = double.tryParse(value ?? '');
                        return parsed == null || parsed <= 0 ? 'Enter an amount greater than zero' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _dateField(context, effectiveFrom, 'Effective from'),
                    _dateField(context, effectiveTo, 'Effective to', required: false),
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
                if (key.currentState!.validate()) Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit for underwriting'),
            ),
          ],
        ),
      ),
    );

    if (save != true) return;
    final amountCents = (double.parse(amount.text) * 100).round();
    await _post(
      '/v2/funeral-underwriting/covers',
      {
        'underwriterId': underwriterId,
        'externalPolicyNo': policyNo.text.trim(),
        'membershipId': membershipId.text.trim().isEmpty ? null : membershipId.text.trim(),
        'holderName': holderName.text.trim(),
        'holderIdentity': holderIdentity.text.trim(),
        'deceasedName': deceasedName.text.trim().isEmpty ? null : deceasedName.text.trim(),
        'deceasedIdentity':
            deceasedIdentity.text.trim().isEmpty ? null : deceasedIdentity.text.trim(),
        'coverAmountCents': amountCents,
        'effectiveFrom': effectiveFrom.text,
        'effectiveTo': effectiveTo.text.trim().isEmpty ? null : effectiveTo.text,
        'status': 'PENDING_UNDERWRITING',
        'underwritingNotes': notes.text.trim(),
        'beneficiaries': const [],
      },
      'Third-party cover submitted for underwriting',
    );
  }

  Future<void> _decide(String id, String status) async {
    await _post(
      '/v2/funeral-underwriting/covers/$id/decision',
      {'status': status},
      'Underwriting status updated',
    );
  }

  Future<void> _post(String path, Map<String, dynamic> body, String successMessage) async {
    try {
      final response = await _api.post(path, body: body);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(response.body);
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operation failed: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Third Party Funeral Cover Underwriting'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Underwriters', icon: Icon(Icons.business_outlined)),
            Tab(text: 'Covers', icon: Icon(Icons.verified_user_outlined)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () => _tabController.index == 0 ? _addUnderwriter() : _addCover(),
        icon: const Icon(Icons.add),
        label: AnimatedBuilder(
          animation: _tabController,
          builder: (_, __) => Text(
            _tabController.index == 0 ? 'Add underwriter' : 'Capture cover',
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_underwritersTab(), _coversTab()],
            ),
    );
  }

  Widget _underwritersTab() {
    if (_underwriters.isEmpty) {
      return _emptyState(
        icon: Icons.business_outlined,
        title: 'No funeral cover underwriters',
        message: 'Add the external organisations that issue and settle third-party funeral cover.',
        action: 'Add underwriter',
        onPressed: _addUnderwriter,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _underwriters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _underwriters[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.business)),
            title: Text(item['name']?.toString() ?? ''),
            subtitle: Text(
              '${item['code'] ?? ''} • ${item['integration_mode'] ?? 'MANUAL'} • '
              '${item['settlement_terms_days'] ?? 0} day settlement',
            ),
            trailing: Chip(label: Text(item['status']?.toString() ?? 'ACTIVE')),
          ),
        );
      },
    );
  }

  Widget _coversTab() {
    if (_covers.isEmpty) {
      return _emptyState(
        icon: Icons.verified_user_outlined,
        title: 'No third-party funeral covers',
        message: 'Capture an external policy to start underwriting and approval.',
        action: 'Capture cover',
        onPressed: _addCover,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _covers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _covers[index];
        final cents = (item['cover_amount_cents'] as num?)?.toInt() ?? 0;
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.policy_outlined)),
            title: Text('${item['external_policy_no'] ?? ''} • ${item['holder_name'] ?? ''}'),
            subtitle: Text(
              '${item['underwriter_name'] ?? ''}\n'
              'R ${(cents / 100).toStringAsFixed(2)} • ${item['status'] ?? ''}',
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              tooltip: 'Underwriting decision',
              onSelected: (value) => _decide(item['id'].toString(), value),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'APPROVED', child: Text('Approve')),
                PopupMenuItem(value: 'DECLINED', child: Text('Decline')),
                PopupMenuItem(value: 'SUSPENDED', child: Text('Suspend')),
                PopupMenuItem(value: 'ACTIVE', child: Text('Activate')),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String message,
    required String action,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: onPressed, icon: const Icon(Icons.add), label: Text(action)),
          ],
        ),
      ),
    );
  }

  static Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = true,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
        ),
        validator: required ? _required : null,
      ),
    );
  }

  static Widget _dateField(
    BuildContext context,
    TextEditingController controller,
    String label, {
    bool required = true,
  }) {
    return Padding(
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
          if (selected != null) controller.text = selected.toIso8601String().substring(0, 10);
        },
      ),
    );
  }

  static String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}
