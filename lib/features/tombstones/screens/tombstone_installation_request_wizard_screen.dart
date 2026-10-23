import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/files/download_bytes.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../funeral/presentation/widgets/family_representative_selector_dialog.dart';
import '../services/tombstone_service.dart';
import 'tombstone_order_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

/// Saves the request before claims; creates the tombstone order only in step seven.
class TombstoneInstallationRequestWizardScreen extends StatefulWidget {
  final String? requestId;
  const TombstoneInstallationRequestWizardScreen({super.key, this.requestId});
  @override
  State<TombstoneInstallationRequestWizardScreen> createState() => _TombstoneInstallationRequestWizardScreenState();
}

class _ItemInput {
  final description = TextEditingController();
  String itemType = 'TOMBSTONE';
  final amount = TextEditingController(text: '0');
  final quantity = TextEditingController(text: '1');
  void dispose() { description.dispose(); amount.dispose(); quantity.dispose(); }
  Map<String, dynamic> toJson() => {
    'description': description.text.trim(), 'itemType': itemType,
    'quantity': double.tryParse(quantity.text) ?? 1,
    'unitPriceCents': ((double.tryParse(amount.text) ?? 0) * 100).round(),
  };
}

class _TombstoneInstallationRequestWizardScreenState extends State<TombstoneInstallationRequestWizardScreen> {
  final _service = TombstoneService();
  final _deceasedName = TextEditingController();
  final _identity = TextEditingController();
  final _deceasedId = TextEditingController();
  final _deathCertificate = TextEditingController();
  final _causeOfDeath = TextEditingController();
  final _customer = TextEditingController();
  final _representativeName = TextEditingController();
  final _representativeContact = TextEditingController();
  final _cemetery = TextEditingController();
  final _cemeteryArea = TextEditingController();
  final _grave = TextEditingController();
  final _salesArea = TextEditingController();
  final _notes = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _items = <_ItemInput>[_ItemInput()];
  final _stepLabels = const ['Deceased', 'Cover', 'Representative', 'Tombstone', 'Claims', 'Preview', 'Generate'];
  final _chosenCovers = <String>{};
  List<Map<String, dynamic>> _covers = [];
  List<Map<String, dynamic>> _claims = [];
  String? _requestId;
  String? _orderId;
  String? _reference;
  String? _status;
  DateTime? _dateOfDeath;
  DateTime? _installationDate;
  String? _error;
  bool _busy = false;
  int _maxCovers = 3;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _requestId = widget.requestId;
    _loadConfiguration();
    if (_requestId != null) _restore();
  }
  Future<void> _loadConfiguration() async {
    try {
      final config = await _service.installationRequestConfiguration();
      if (mounted) setState(() => _maxCovers = (config['maxSelectedCovers'] as num?)?.toInt() ?? 3);
    } catch (_) {
      // Backend still validates the configured maximum if settings cannot be loaded.
    }
  }
  @override
  void dispose() {
    for (final c in [_deceasedName, _identity, _deceasedId, _deathCertificate, _causeOfDeath,
      _customer, _representativeName, _representativeContact, _cemetery, _cemeteryArea, _grave,
      _salesArea, _notes, _discount]) { c.dispose(); }
    for (final i in _items) { i.dispose(); }
    super.dispose();
  }

  String? _date(DateTime? value) => value?.toIso8601String().split('T').first;
  DateTime? _parseDate(dynamic value) => value == null ? null : DateTime.tryParse(value.toString());
  String _coverKey(Map<String, dynamic> cover) => '${cover['tenantId']}:${cover['membershipId']}';
  String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
  int get _discountCents => ((double.tryParse(_discount.text) ?? 0) * 100).round();
  int get _approvedCents => _claims.where((c) => c['status']?.toString() == 'APPROVED')
      .fold<int>(0, (total, c) => total + ((c['approvedAmountCents'] as num?)?.toInt() ?? 0));
  int get _totalCents => _items.fold<int>(0, (total, item) => total +
    (((double.tryParse(item.amount.text) ?? 0) * 100).round() * (double.tryParse(item.quantity.text) ?? 1)).round());
  String _money(int cents) => 'R ${(cents / 100).toStringAsFixed(2)}';
  bool get _isEditable => _status == null || _status == 'DRAFT';

  void _apply(Map<String, dynamic> data) {
    _requestId = data['id']?.toString();
    _reference = data['request_no']?.toString();
    _status = data['status']?.toString();
    _orderId = data['tombstone_order_id']?.toString();
    if (_orderId?.isEmpty ?? false) _orderId = null;
    _claims = (data['claims'] as List? ?? []).map((v) => Map<String, dynamic>.from(v as Map)).toList();
    if (data['deceased_name'] != null) _deceasedName.text = data['deceased_name'].toString();
    if (data['deceased_identity_number'] != null) _identity.text = data['deceased_identity_number'].toString();
    if (data['deceased_partner_id'] != null) _deceasedId.text = data['deceased_partner_id'].toString();
    if (data['date_of_death'] != null) _dateOfDeath = _parseDate(data['date_of_death']);
    if (data['death_certificate_no'] != null) _deathCertificate.text = data['death_certificate_no'].toString();
    if (data['cause_of_death'] != null) _causeOfDeath.text = data['cause_of_death'].toString();
    if (data['customer_partner_id'] != null) _customer.text = data['customer_partner_id'].toString();
    if (data['family_representative_name'] != null) _representativeName.text = data['family_representative_name'].toString();
    if (data['family_representative_contact'] != null) _representativeContact.text = data['family_representative_contact'].toString();
    if (data['cemetery_name'] != null) _cemetery.text = data['cemetery_name'].toString();
    if (data['cemetery_area'] != null) _cemeteryArea.text = data['cemetery_area'].toString();
    if (data['grave_number'] != null) _grave.text = data['grave_number'].toString();
    if (data['sales_area'] != null) _salesArea.text = data['sales_area'].toString();
    if (data['notes'] != null) _notes.text = data['notes'].toString();
    if (data['expected_installation_date'] != null) _installationDate = _parseDate(data['expected_installation_date']);
    if (data['discount_cents'] is num) _discount.text = ((data['discount_cents'] as num) / 100).toStringAsFixed(2);
    final savedItems = (data['items'] as List? ?? []);
    if (savedItems.isNotEmpty) {
      for (final i in _items) { i.dispose(); }
      _items.clear();
      for (final raw in savedItems) {
        final item = Map<String, dynamic>.from(raw as Map);
        final input = _ItemInput();
        input.description.text = item['description']?.toString() ?? '';
        input.itemType = item['itemType']?.toString() ?? 'TOMBSTONE';
        input.quantity.text = item['quantity']?.toString() ?? '1';
        input.amount.text = ((item['unitPriceCents'] as num? ?? 0) / 100).toStringAsFixed(2);
        _items.add(input);
      }
    }
    final savedCovers = (data['selectedCovers'] as List? ?? []);
    if (savedCovers.isNotEmpty) {
      _covers = savedCovers.map((v) => Map<String, dynamic>.from(v as Map)).toList();
      _chosenCovers.addAll(_covers.map(_coverKey));
    }
    if (_orderId != null) {
      _step = 6;
    } else if (_claims.isNotEmpty) {
      _step = 4;
    }
  }

  Future<void> _restore() async {
    await _run(() async {
      final response = await _service.installationRequest(_requestId!);
      if (mounted) setState(() => _apply(response));
    });
  }
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await operation(); }
    catch (e) { if (mounted) setState(() => _error = friendlyErrorMessage(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _lookup() async {
    if (_identity.text.trim().isEmpty) { setState(() => _error = 'Enter the deceased identity number.'); return; }
    await _run(() async {
      final result = await _service.lookupTombstoneCover(_identity.text.trim(), eventDate: _dateOfDeath);
      if (mounted) setState(() { _covers = result; _chosenCovers.clear(); });
    });
  }

  Map<String, dynamic> _payload() {
    final selections = _covers.where((item) => _chosenCovers.contains(_coverKey(item))).toList();
    return {
      'customerPartnerId': _customer.text.trim(),
      'deceasedPartnerId': _deceasedId.text.trim(),
      'deceasedName': _deceasedName.text.trim(),
      'deceasedIdentityNumber': _blank(_identity.text),
      'dateOfDeath': _date(_dateOfDeath),
      'causeOfDeath': _blank(_causeOfDeath.text),
      'deathCertificateNo': _blank(_deathCertificate.text),
      'familyRepresentativePartnerId': _blank(_customer.text),
      'familyRepresentativeName': _blank(_representativeName.text),
      'familyRepresentativeContact': _blank(_representativeContact.text),
      'cemeteryName': _blank(_cemetery.text),
      'cemeteryArea': _blank(_cemeteryArea.text),
      'graveNumber': _blank(_grave.text),
      'salesArea': _blank(_salesArea.text),
      'expectedInstallationDate': _date(_installationDate),
      'notes': _blank(_notes.text),
      'discountCents': ((double.tryParse(_discount.text) ?? 0) * 100).round(),
      'items': _items.map((e) => e.toJson()).toList(),
      'selectedCovers': selections.map((c) => {
        'tenantId': c['tenantId'], 'membershipId': c['membershipId'],
        'deceasedPartnerId': c['deceasedPartnerId'], 'deceasedType': c['deceasedType'],
        'membershipNumber': c['membershipNumber'], 'burialSocietyName': c['burialSocietyName'],
        'sourceTenantName': c['sourceTenantName'], 'tombstoneAmountCents': c['tombstoneAmountCents'],
      }).toList(),
    };
  }

  Future<void> _save() async {
    if (_deceasedName.text.trim().isEmpty || _dateOfDeath == null || _deceasedId.text.trim().isEmpty) {
      setState(() => _error = 'Complete deceased name, partner and date of death.'); return;
    }
    if (_customer.text.trim().isEmpty) { setState(() => _error = 'Select a family representative.'); return; }
    if (_chosenCovers.isEmpty) { setState(() => _error = 'Select at least one Tombstone benefit.'); return; }
    if (_items.any((i) => (double.tryParse(i.quantity.text) ?? 0) <= 0 ||
        (double.tryParse(i.amount.text) ?? -1) < 0)) {
      setState(() => _error = 'Enter valid positive quantities and non-negative item prices.'); return;
    }
    if (_items.any((i) => i.description.text.trim().isEmpty)) {
      setState(() => _error = 'Complete the description for every tombstone item.'); return;
    }
    await _run(() async {
      final response = _requestId == null
          ? await _service.createInstallationRequest(_payload())
          : await _service.updateInstallationRequest(_requestId!, _payload());
      if (mounted) setState(() { _requestId = response['id']?.toString(); _reference = response['request_no']?.toString(); _status = response['status']?.toString(); });
    });
  }
  Future<void> _initiate() async {
    if (_requestId == null) { await _save(); if (_requestId == null) return; }
    await _run(() async {
      final response = await _service.initiateInstallationClaims(_requestId!);
      if (mounted) setState(() { _claims = (response['claims'] as List? ?? []).map((v) => Map<String, dynamic>.from(v as Map)).toList(); _status = response['status']?.toString(); });
    });
  }
  Future<void> _submit(String claimId) async {
    await _run(() async {
      await _service.submitInstallationClaim(_requestId!, claimId);
      final response = await _service.installationRequest(_requestId!);
      if (mounted) setState(() => _claims = (response['claims'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList());
    });
  }
  Future<void> _download(String claimId) async {
    await _run(() async {
      final bytes = await _service.tombstoneClaimForm(_requestId!, claimId);
      await downloadBytes(bytes: Uint8List.fromList(bytes), fileName: 'tombstone-claim-$claimId.pdf', mimeType: 'application/pdf');
    });
  }
  Future<void> _applyFunding() async {
    if (_requestId == null || _orderId == null) return;
    await _run(() async {
      final result = await _service.applyInstallationFunding(_requestId!);
      if (mounted) {
        setState(() => _claims = (result['claims'] as List? ?? [])
            .map((c) => Map<String, dynamic>.from(c as Map)).toList());
      }
    });
  }
  Future<void> _generate() async {
    if (_requestId == null || _claims.isEmpty) { setState(() => _error = 'Initiate Tombstone Claims first.'); return; }
    await _run(() async {
      final response = await _service.generateInstallationOrder(_requestId!);
      if (mounted) setState(() { _orderId = response['tombstone_order_id']?.toString(); _status = response['status']?.toString(); });
    });
  }
  Future<void> _pickDate({required bool installation}) async {
    final now = DateTime.now();
    final initial = installation ? (_installationDate ?? now) : (_dateOfDeath ?? now);
    final selected = await showDatePicker(context: context, initialDate: initial,
      firstDate: DateTime(1900), lastDate: installation ? DateTime(2100) : now);
    if (selected != null && mounted) {
      setState(() {
        if (installation) {
          _installationDate = selected;
        } else {
          _dateOfDeath = selected;
        }
      });
    }
  }
  Future<void> _selectDeceasedPartner() async {
    final selection = await showDialog<FamilyRepresentativeSelection>(context: context,
      builder: (_) => const FamilyRepresentativeSelectorDialog());
    if (selection != null && mounted) {
      setState(() {
        _deceasedId.text = selection.partner.id;
        _deceasedName.text = selection.partner.fullName;
        if (selection.partner.identityNumber.isNotEmpty) {
          _identity.text = selection.partner.identityNumber;
        }
      });
    }
  }
  Future<void> _selectRepresentative() async {
    final result = await showDialog<FamilyRepresentativeSelection>(context: context,
      builder: (_) => const FamilyRepresentativeSelectorDialog());
    if (result != null && mounted) {
      setState(() {
        _customer.text = result.partner.id;
        _representativeName.text = result.partner.fullName;
        _representativeContact.text = result.contactDetails;
      });
    }
  }
  Widget _field(TextEditingController controller, String label, {bool isRequired = false, int lines = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(
      enabled: _isEditable,
      controller: controller, maxLines: lines,
      decoration: InputDecoration(labelText: '$label${isRequired ? ' *' : ''}', border: const OutlineInputBorder()),
    ));
  Widget _hint(String message) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(message, style: Theme.of(context).textTheme.bodyMedium));

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Identify the deceased using an existing partner or membership. Mortuary admission is not required.'),
          _field(_identity, 'Deceased identity number'),
          _field(_deceasedName, 'Deceased full name', isRequired: true),
          _field(_deceasedId, 'Deceased partner ID', isRequired: true),
          OutlinedButton.icon(onPressed: _isEditable ? _lookup : null, icon: const Icon(Icons.search), label: const Text('Find membership covers by identity')),
          OutlinedButton.icon(onPressed: _isEditable ? _selectDeceasedPartner : null,
            icon: const Icon(Icons.person_search), label: const Text('Select or capture deceased partner')),
          ListTile(title: const Text('Date of death *'), subtitle: Text(_date(_dateOfDeath) ?? 'Select date'),
            trailing: const Icon(Icons.calendar_month), onTap: _isEditable ? () => _pickDate(installation: false) : null),
          _field(_deathCertificate, 'Death certificate number'),
          _field(_causeOfDeath, 'Cause of death'),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Select each eligible Tombstone cover. Funeral Claims remain separate; no Grocery Claim will be created.'),
          OutlinedButton.icon(onPressed: _isEditable ? _lookup : null, icon: const Icon(Icons.search), label: const Text('Refresh cover lookup')),
          if (_covers.isEmpty) const ListTile(title: Text('No eligible Tombstone covers loaded'),
            subtitle: Text('Search by the deceased identity number on the previous step.')),
          ..._covers.map((cover) => CheckboxListTile(
            value: _chosenCovers.contains(_coverKey(cover)),
            onChanged: _isEditable ? (checked) => setState(() {
              final key = _coverKey(cover);
              if (checked == true && (_maxCovers <= 0 || _chosenCovers.length < _maxCovers)) {
                _chosenCovers.add(key);
                // A source tenant's partner ID is not a local deceased partner ID.
                if (_deceasedId.text.trim().isEmpty &&
                    (cover['tenantId']?.toString() ?? '').isEmpty) {
                  _deceasedId.text = cover['deceasedPartnerId']?.toString() ?? '';
                }
              } else if (checked != true) { _chosenCovers.remove(key); }
            }) : null,
            title: Text('${cover['membershipNumber'] ?? cover['membershipId']} • ${cover['burialSocietyName'] ?? ''}'),
            subtitle: Text('${cover['sourceTenantName'] ?? cover['tenantId'] ?? ''} • Tombstone ${_money((cover['tombstoneAmountCents'] as num?)?.toInt() ?? 0)}'),
          )),
          Text(_maxCovers > 0 ? '${_chosenCovers.length} of $_maxCovers covers selected'
              : '${_chosenCovers.length} covers selected (no configured limit)'),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Select or create a family representative using the existing partner workflow.'),
          OutlinedButton.icon(onPressed: _isEditable ? _selectRepresentative : null,
            icon: const Icon(Icons.person_search), label: const Text('Select family representative')),
          if (_customer.text.isNotEmpty) Text('Partner: ${_representativeName.text} • ${_customer.text}'),
          _field(_representativeContact, 'Representative contact details'),
        ]);
      case 3:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Capture the cemetery, planned installation and tombstone products or services.'),
          _field(_cemetery, 'Cemetery'), _field(_cemeteryArea, 'Cemetery area'), _field(_grave, 'Grave number'),
          _field(_salesArea, 'Sales area'),
          ListTile(title: const Text('Expected installation date'), subtitle: Text(_date(_installationDate) ?? 'Not scheduled'),
            trailing: const Icon(Icons.calendar_month), onTap: _isEditable ? () => _pickDate(installation: true) : null),
          ..._items.asMap().entries.map((entry) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
            Row(children: [Expanded(child: Text('Item ${entry.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold))),
              if (_items.length > 1 && _isEditable) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() { final removed = _items.removeAt(entry.key); removed.dispose(); }))]),
            DropdownButtonFormField<String>(initialValue: entry.value.itemType,
              decoration: const InputDecoration(labelText: 'Line type'),
              items: const [DropdownMenuItem(value: 'TOMBSTONE', child: Text('Tombstone product')),
                DropdownMenuItem(value: 'INSTALLATION', child: Text('Installation service')),
                DropdownMenuItem(value: 'EXTRA', child: Text('Additional service or extra'))],
              onChanged: _isEditable ? (value) => setState(() => entry.value.itemType = value ?? 'TOMBSTONE') : null),
            const SizedBox(height: 12),
            _field(entry.value.description, 'Product or service description', isRequired: true),
            _field(entry.value.quantity, 'Quantity'), _field(entry.value.amount, 'Unit price (R)'),
          ])))),
          OutlinedButton.icon(onPressed: _isEditable ? () => setState(() => _items.add(_ItemInput())) : null,
            icon: const Icon(Icons.add), label: const Text('Add product or service')),
          _field(_discount, 'Overall discount (R)'), _field(_notes, 'Special instructions', lines: 3),
          Text('Estimated order total: ${_money(_totalCents - ((double.tryParse(_discount.text) ?? 0) * 100).round())}'),
        ]);
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Save the request, initiate TOMBSTONE claims, print forms, attach supporting documents and submit each claim for approval.'),
          if (_requestId == null || _status == 'DRAFT') ...[
            FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save request')),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _busy ? null : _initiate, icon: const Icon(Icons.description_outlined), label: const Text('Initiate Tombstone Claims')),
          ],
          if (_claims.isEmpty) const ListTile(title: Text('No claims initiated')),
          ..._claims.map((claim) {
            final claimId = claim['membership_claim_id']?.toString() ?? '';
            return Card(child: Column(children: [
              ListTile(title: Text('${claim['claim_no']} • ${claim['status'] ?? ''}'),
                subtitle: Text('Benefit: ${_money((claim['claimAmountCents'] as num?)?.toInt() ?? 0)}')),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child:
                AttachmentSection(key: ValueKey(claimId), objectId: claimId)),
              Wrap(spacing: 8, children: [
                OutlinedButton.icon(onPressed: _busy ? null : () => _download(claimId),
                  icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Claim Form')),
                if (claim['status']?.toString() == 'DRAFT')
                  FilledButton(onPressed: _busy ? null : () => _submit(claimId), child: const Text('Submit for approval')),
              ]),
            ]));
          }),
        ]);
      case 5:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Preview the selected cover, tombstone order and remaining customer balance. Only approved claims count as confirmed funding.'),
          ListTile(title: Text('Request ${_reference ?? '(not yet saved)'}'), subtitle: Text('Deceased: ${_deceasedName.text}')),
          ListTile(title: const Text('Order estimate'), trailing: Text(_money(_totalCents - ((double.tryParse(_discount.text) ?? 0) * 100).round()))),
          ..._claims.map((c) => ListTile(title: Text('${c['claim_no']}'), subtitle: Text('${c['status']}'),
            trailing: Text(_money((c['approvedAmountCents'] as num?)?.toInt() ?? 0)))),
          ListTile(title: const Text('Approved benefits (available for allocation)'),
            trailing: Text(_money(_approvedCents))),
          ListTile(title: const Text('Estimated customer balance after approved cover'),
            trailing: Text(_money((_totalCents - _discountCents - _approvedCents).clamp(0, 999999999999).toInt()))),
          const Text('Claim approvals and funding allocations remain subject to the normal MAWA workflow.'),
        ]);
      case 6:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('The final step generates the operational Tombstone Order and its invoice exactly once.'),
          if (_orderId == null)
            FilledButton.icon(onPressed: _busy || _claims.isEmpty ? null : _generate,
              icon: const Icon(Icons.receipt_long), label: const Text('Generate Tombstone Order & Invoice')),
          if (_orderId != null) ...[
            const ListTile(leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Order generated'), subtitle: Text('Manage production and installation in Tombstone Management.')),
            FilledButton.icon(onPressed: _busy ? null : _applyFunding,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Apply approved Tombstone benefits')),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => TombstoneOrderDetailScreen(orderId: _orderId!))),
              child: const Text('Open Tombstone Order')),
          ],
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_reference == null ? 'New Tombstone Installation Request' : 'Installation Request $_reference')),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(12),
          child: Row(children: List.generate(_stepLabels.length, (index) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(label: Text('${index + 1}. ${_stepLabels[index]}'), selected: _step == index,
              onSelected: (_) => setState(() => _step = index)),
          )))),
        if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(title: Text(_error!), trailing: IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close)))),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950), child: _content(),
        )))),
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          OutlinedButton(onPressed: _step > 0 ? () => setState(() => _step--) : null, child: const Text('Back')),
          const Spacer(),
          if (_status == 'DRAFT' && _step != 4)
            OutlinedButton(onPressed: _busy ? null : _save, child: const Text('Save draft')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _step < 6 ? () => setState(() => _step++) : null, child: const Text('Next')),
        ])),
      ]),
    );
  }
}
