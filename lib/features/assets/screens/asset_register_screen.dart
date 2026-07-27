import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../services/asset_register_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class AssetRegisterScreen extends StatefulWidget {
  const AssetRegisterScreen({super.key});

  @override
  State<AssetRegisterScreen> createState() => _AssetRegisterScreenState();
}

class _AssetRegisterScreenState extends State<AssetRegisterScreen> {
  final AssetRegisterService _service = AssetRegisterService();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _assets = const [];
  Map<String, dynamic> _dashboard = const {};
  bool _loading = true;
  String? _error;
  String _status = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.dashboard(),
        _service.list(query: _search.text, status: _status),
      ]);
      if (mounted) {
        setState(() {
          _dashboard = Map<String, dynamic>.from(results[0] as Map);
          _assets = List<Map<String, dynamic>>.from(results[1] as List);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? asset]) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AssetDialog(service: _service, asset: asset),
    );
    if (changed == true) await _load();
  }

  Future<void> _assign(Map<String, dynamic> asset) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _AssetAssignmentDialog(service: _service, asset: asset),
    );
    if (changed == true) await _load();
  }

  Future<void> _disposeAsset(Map<String, dynamic> asset) async {
    final proceeds = TextEditingController();
    final notes = TextEditingController();
    DateTime date = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Dispose ${asset['asset_no'] ?? 'Asset'}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                      initialDate: date,
                    );
                    if (selected != null) setDialogState(() => date = selected);
                  },
                  icon: const Icon(Icons.event),
                  label: Text(DateFormat('yyyy-MM-dd').format(date)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proceeds,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Disposal Proceeds'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Disposal Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Dispose')),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await _service.dispose(
          asset['id'].toString(),
          disposalDate: DateFormat('yyyy-MM-dd').format(date),
          proceeds: double.tryParse(proceeds.text) ?? 0,
          notes: notes.text,
        );
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
    proceeds.dispose();
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'en_ZA', symbol: 'R ');
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Asset Register'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('New Asset'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Total Assets', _dashboard['total_assets'], Icons.inventory_2_outlined),
                _metric('Active', _dashboard['active_assets'], Icons.check_circle_outline),
                _metric('Disposed', _dashboard['disposed_assets'], Icons.delete_sweep_outlined),
                _metric('Current Value', currency.format(_asDouble(_dashboard['current_value'])), Icons.account_balance_wallet_outlined),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                labelText: 'Search asset number, name, barcode or serial number',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(onPressed: _load, icon: const Icon(Icons.arrow_forward)),
              ),
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              scrollDirection: Axis.horizontal,
              children: ['ALL', 'ACTIVE', 'IN_REPAIR', 'LOST', 'DISPOSED']
                  .map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(status.replaceAll('_', ' ')),
                          selected: _status == status,
                          onSelected: (_) {
                            setState(() => _status = status);
                            _load();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(child: _body(currency)),
        ],
      ),
    );
  }

  String _initial(dynamic value) {
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  Widget _body(NumberFormat currency) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    }
    if (_assets.isEmpty) return const Center(child: Text('No assets found.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        itemCount: _assets.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final asset = _assets[index];
          final status = (asset['status'] ?? '').toString();
          return Card(
            elevation: 0,
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Text(_initial(asset['name']))),
              title: Text('${asset['asset_no']} • ${asset['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text([
                  if ((asset['category'] ?? '').toString().isNotEmpty) 'Category: ${asset['category']}',
                  if ((asset['barcode'] ?? '').toString().isNotEmpty) 'Barcode: ${asset['barcode']}',
                  if ((asset['serial_no'] ?? '').toString().isNotEmpty) 'Serial: ${asset['serial_no']}',
                  if ((asset['custodian_name'] ?? '').toString().trim().isNotEmpty) 'Custodian: ${asset['custodian_name']}',
                  'Value: ${currency.format(_asDouble(asset['current_value']))}',
                ].join(' • ')),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _edit(asset);
                  if (value == 'assign') _assign(asset);
                  if (value == 'dispose') _disposeAsset(asset);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit asset')),
                  if (status != 'DISPOSED') const PopupMenuItem(value: 'assign', child: Text('Assign / transfer')),
                  if (status != 'DISPOSED') const PopupMenuItem(value: 'dispose', child: Text('Dispose asset')),
                ],
              ),
              onTap: () => _edit(asset),
            ),
          );
        },
      ),
    );
  }

  Widget _metric(String label, dynamic value, IconData icon) => Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade200)),
        child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12)), Text((value ?? 0).toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]))]),
      );

  static double _asDouble(dynamic value) => value is num ? value.toDouble() : double.tryParse((value ?? '0').toString()) ?? 0;
}

class _AssetDialog extends StatefulWidget {
  final AssetRegisterService service;
  final Map<String, dynamic>? asset;
  const _AssetDialog({required this.service, this.asset});
  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  final _key = GlobalKey<FormState>();
  late final Map<String, TextEditingController> c;
  bool _saving = false;
  String _status = 'ACTIVE';
  String _condition = 'GOOD';
  DateTime? _acquisitionDate;
  DateTime? _warrantyDate;

  @override
  void initState() {
    super.initState();
    final a = widget.asset ?? const <String, dynamic>{};
    c = {
      for (final key in ['asset_no','barcode','name','description','category','serial_no','acquisition_cost','current_value','useful_life_months','residual_value','location','custodian_partner_id','notes'])
        key: TextEditingController(text: (a[key] ?? '').toString()),
    };
    _status = (a['status'] ?? 'ACTIVE').toString();
    _condition = (a['condition_status'] ?? 'GOOD').toString();
    _acquisitionDate = DateTime.tryParse((a['acquisition_date'] ?? '').toString());
    _warrantyDate = DateTime.tryParse((a['warranty_expiry_date'] ?? '').toString());
  }

  @override
  void dispose() {
    for (final controller in c.values) controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    final payload = {
      'assetNo': c['asset_no']!.text.trim(),
      'barcode': c['barcode']!.text.trim(),
      'name': c['name']!.text.trim(),
      'description': c['description']!.text.trim(),
      'category': c['category']!.text.trim(),
      'serialNo': c['serial_no']!.text.trim(),
      'acquisitionDate': _acquisitionDate == null ? null : DateFormat('yyyy-MM-dd').format(_acquisitionDate!),
      'acquisitionCost': double.tryParse(c['acquisition_cost']!.text) ?? 0,
      'currentValue': double.tryParse(c['current_value']!.text) ?? 0,
      'depreciationMethod': 'STRAIGHT_LINE',
      'usefulLifeMonths': int.tryParse(c['useful_life_months']!.text),
      'residualValue': double.tryParse(c['residual_value']!.text) ?? 0,
      'location': c['location']!.text.trim(),
      'custodianPartnerId': c['custodian_partner_id']!.text.trim(),
      'status': _status,
      'conditionStatus': _condition,
      'warrantyExpiryDate': _warrantyDate == null ? null : DateFormat('yyyy-MM-dd').format(_warrantyDate!),
      'notes': c['notes']!.text.trim(),
    };
    try {
      if (widget.asset == null) {
        await widget.service.create(payload);
      } else {
        await widget.service.update(widget.asset!['id'].toString(), payload);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.asset == null ? 'New Asset' : 'Edit Asset'),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(children: [
              Row(children: [Expanded(child: _field('asset_no', 'Asset Number', required: widget.asset != null)), const SizedBox(width: 12), Expanded(child: _field('barcode', 'Barcode'))]),
              const SizedBox(height: 12),
              _field('name', 'Asset Name', required: true),
              const SizedBox(height: 12),
              _field('description', 'Description', lines: 2),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _field('category', 'Category')), const SizedBox(width: 12), Expanded(child: _field('serial_no', 'Serial Number'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _number('acquisition_cost', 'Acquisition Cost')), const SizedBox(width: 12), Expanded(child: _number('current_value', 'Current Value')), const SizedBox(width: 12), Expanded(child: _number('residual_value', 'Residual Value'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _number('useful_life_months', 'Useful Life (Months)', decimal: false)), const SizedBox(width: 12), Expanded(child: _field('location', 'Location'))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: _dateButton('Acquisition Date', _acquisitionDate, (v) => setState(() => _acquisitionDate = v))), const SizedBox(width: 12), Expanded(child: _dateButton('Warranty Expiry', _warrantyDate, (v) => setState(() => _warrantyDate = v)))]),
              const SizedBox(height: 12),
              Row(children: [Expanded(child: DropdownButtonFormField<String>(value: _status, decoration: const InputDecoration(labelText: 'Status'), items: ['ACTIVE','IN_REPAIR','LOST','DISPOSED'].map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' ')))).toList(), onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'))), const SizedBox(width: 12), Expanded(child: DropdownButtonFormField<String>(value: _condition, decoration: const InputDecoration(labelText: 'Condition'), items: ['NEW','GOOD','FAIR','POOR','DAMAGED'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _condition = v ?? 'GOOD')))]),
              const SizedBox(height: 12),
              _field('notes', 'Notes', lines: 3),
            ]),
          ),
        ),
      ),
      actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: Text(_saving ? 'Saving...' : 'Save'))],
    );
  }

  Widget _field(String key, String label, {bool required = false, int lines = 1}) => TextFormField(controller: c[key], maxLines: lines, decoration: InputDecoration(labelText: label), validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null);
  Widget _number(String key, String label, {bool decimal = true}) => TextFormField(controller: c[key], keyboardType: TextInputType.numberWithOptions(decimal: decimal), decoration: InputDecoration(labelText: label));
  Widget _dateButton(String label, DateTime? date, ValueChanged<DateTime?> changed) => OutlinedButton.icon(onPressed: () async { final value = await showDatePicker(context: context, firstDate: DateTime(1950), lastDate: DateTime(2100), initialDate: date ?? DateTime.now()); if (value != null) changed(value); }, icon: const Icon(Icons.event), label: Text(date == null ? label : '$label: ${DateFormat('yyyy-MM-dd').format(date)}'));
}

class _AssetAssignmentDialog extends StatefulWidget {
  final AssetRegisterService service;
  final Map<String, dynamic> asset;
  const _AssetAssignmentDialog({required this.service, required this.asset});
  @override
  State<_AssetAssignmentDialog> createState() => _AssetAssignmentDialogState();
}

class _AssetAssignmentDialogState extends State<_AssetAssignmentDialog> {
  Partner? _partner;
  late final TextEditingController _location;
  final TextEditingController _notes = TextEditingController();
  bool _saving = false;
  @override
  void initState() { super.initState(); _location = TextEditingController(text: (widget.asset['location'] ?? '').toString()); }
  @override
  void dispose() { _location.dispose(); _notes.dispose(); super.dispose(); }
  Future<void> _pick() async {
    final query = TextEditingController();
    List<Partner> rows = const [];
    final selected = await showDialog<Partner>(context: context, builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(title: const Text('Select Custodian'), content: SizedBox(width: 560, height: 420, child: Column(children: [TextField(controller: query, onSubmitted: (_) async { rows = await PartnerService().getPartners(query: query.text); setDialogState(() {}); }, decoration: const InputDecoration(labelText: 'Search partner', suffixIcon: Icon(Icons.search))), const SizedBox(height: 12), Expanded(child: ListView.builder(itemCount: rows.length, itemBuilder: (_, i) => ListTile(title: Text(rows[i].fullName), subtitle: Text(rows[i].number), onTap: () => Navigator.pop(context, rows[i]))))])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))])));
    query.dispose();
    if (selected != null) setState(() => _partner = selected);
  }
  Future<void> _save() async { setState(() => _saving = true); try { await widget.service.assign(widget.asset['id'].toString(), partnerId: _partner?.id ?? widget.asset['custodian_partner_id']?.toString(), location: _location.text, notes: _notes.text); if (mounted) Navigator.pop(context, true); } catch (e) { if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e)))); } } }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Assign / Transfer Asset'), content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(contentPadding: EdgeInsets.zero, title: Text(_partner?.fullName ?? (widget.asset['custodian_name'] ?? 'No custodian').toString()), subtitle: const Text('Asset custodian'), trailing: OutlinedButton(onPressed: _pick, child: const Text('Select'))), TextField(controller: _location, decoration: const InputDecoration(labelText: 'Location')), const SizedBox(height: 12), TextField(controller: _notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Transfer Notes'))])), actions: [TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Assign'))]);
}
