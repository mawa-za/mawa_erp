import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../core/files/download_bytes.dart';
import '../../../core/widgets/attachment_section.dart';
import '../../funeral/presentation/widgets/family_representative_selector_dialog.dart';
import '../../partners/models/partner.dart';
import '../../../core/models/field_option.dart';
import '../../../core/models/product_lookup.dart';
import '../../../core/services/field_service.dart';
import '../../../core/services/product_lookup_service.dart';
import 'deceased_partner_lookup_dialog.dart';
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
  final amount = TextEditingController(text: '0');
  final inscription = TextEditingController();
  final material = TextEditingController();
  final colour = TextEditingController();
  final dimensions = TextEditingController();
  String? productId;
  String itemType;

  _ItemInput() : itemType = 'TOMBSTONE';

  _ItemInput.fromProduct(ProductLookup product, {required this.itemType}) {
    productId = product.id.isEmpty ? null : product.id;
    description.text = product.description;
    amount.text = (product.priceCents / 100).toStringAsFixed(2);
  }

  void dispose() {
    description.dispose(); amount.dispose(); inscription.dispose();
    material.dispose(); colour.dispose(); dimensions.dispose();
  }
  Map<String, dynamic> toJson() => {
    if (productId != null) 'productId': productId,
    'description': description.text.trim(), 'itemType': itemType,
    if (itemType == 'TOMBSTONE') ...{
      'material': material.text.trim(),
      'colour': colour.text.trim(),
      'dimensions': dimensions.text.trim(),
    },
    'inscriptionText': itemType == 'TOMBSTONE' && inscription.text.trim().isNotEmpty
        ? inscription.text.trim() : null,
    'quantity': 1,
    'unitPriceCents': ((double.tryParse(amount.text) ?? 0) * 100).round(),
  };
}

class _TombstoneInstallationRequestWizardScreenState extends State<TombstoneInstallationRequestWizardScreen> {
  final _service = TombstoneService();
  final _fieldService = FieldService();
  final _productService = ProductLookupService();
  List<FieldOption> _installationAreas = [];
  List<FieldOption> _cemeteryOptions = [];
  List<FieldOption> _cemeteryAreaOptions = [];
  List<ProductLookup> _tombstoneProducts = [];
  List<ProductLookup> _extraProducts = [];
  bool _catalogLoading = true;
  String? _catalogError;
  final _deceasedName = TextEditingController();
  final _identity = TextEditingController();
  final _deceasedId = TextEditingController(); // Internal link, never shown for manual entry.
  final _customer = TextEditingController();
  final _representativeName = TextEditingController();
  final _representativeContact = TextEditingController();
  final _cemetery = TextEditingController();
  final _cemeteryArea = TextEditingController();
  final _grave = TextEditingController();
  final _salesArea = TextEditingController();
  final _directions = TextEditingController();
  final _notes = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _items = <_ItemInput>[];
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
    _loadStep4Options();
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
  Future<void> _loadStep4Options() async {
    // Options are tenant-maintained; a missing cemetery list does not block
    // installations in villages or at other family-provided locations.
    try {
      final results = await Future.wait<dynamic>([
        _fieldService.getOptionsByField('SALES-AREA').catchError((_) => <FieldOption>[]),
        _fieldService.getOptionsByField('CEMETERY').catchError((_) => <FieldOption>[]),
        _fieldService.getOptionsByField('CEMETERY-AREA').catchError((_) => <FieldOption>[]),
        _productService.getProducts(type: 'TOMBSTONE', forceRefresh: true, strictType: true),
        _productService.getProducts(forceRefresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        _installationAreas = results[0] as List<FieldOption>;
        _cemeteryOptions = results[1] as List<FieldOption>;
        _cemeteryAreaOptions = results[2] as List<FieldOption>;
        _tombstoneProducts = (results[3] as List<ProductLookup>)
            .where((product) => product.id.isNotEmpty).toList();
        _extraProducts = (results[4] as List<ProductLookup>)
            .where((product) => product.id.isNotEmpty && !_tombstoneProducts.any((t) => t.id == product.id))
            .toList();
        _catalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _catalogError = friendlyErrorMessage(e); _catalogLoading = false; });
    }
  }

  @override
  void dispose() {
    for (final c in [_deceasedName, _identity, _deceasedId,
      _customer, _representativeName, _representativeContact, _cemetery, _cemeteryArea, _grave,
      _salesArea, _directions, _notes, _discount]) { c.dispose(); }
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
    ((double.tryParse(item.amount.text) ?? 0) * 100).round());
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
    if (data['customer_partner_id'] != null) _customer.text = data['customer_partner_id'].toString();
    if (data['family_representative_name'] != null) _representativeName.text = data['family_representative_name'].toString();
    if (data['family_representative_contact'] != null) _representativeContact.text = data['family_representative_contact'].toString();
    if (data['cemetery_name'] != null) _cemetery.text = data['cemetery_name'].toString();
    if (data['cemetery_area'] != null) _cemeteryArea.text = data['cemetery_area'].toString();
    if (data['grave_number'] != null) _grave.text = data['grave_number'].toString();
    if (data['sales_area'] != null) _salesArea.text = data['sales_area'].toString();
    if (data['installation_directions'] != null) _directions.text = data['installation_directions'].toString();
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
        input.inscription.text = item['inscriptionText']?.toString() ?? '';
        input.material.text = item['material']?.toString() ?? '';
        input.colour.text = item['colour']?.toString() ?? '';
        input.dimensions.text = item['dimensions']?.toString() ?? '';
        input.itemType = item['itemType']?.toString() ?? 'TOMBSTONE';
        input.productId = item['productId']?.toString();
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
    if (_identity.text.trim().isEmpty) { setState(() => _error = 'Enter the deceased identity number to search for a membership benefit.'); return; }
    if (_dateOfDeath == null) { setState(() => _error = 'Enter the date of death to check historical membership benefits.'); return; }
    await _run(() async {
      final result = await _service.lookupTombstoneCover(_identity.text.trim(), eventDate: _dateOfDeath);
      if (mounted) setState(() { _covers = result; _chosenCovers.clear(); });
    });
  }

  Map<String, dynamic> _payload() {
    final selections = _covers.where((item) => _chosenCovers.contains(_coverKey(item))).toList();
    return {
      'customerPartnerId': _customer.text.trim(),
      'deceasedPartnerId': _blank(_deceasedId.text),
      'deceasedName': _deceasedName.text.trim(),
      'deceasedIdentityNumber': _blank(_identity.text),
      'dateOfDeath': _date(_dateOfDeath),
      'familyRepresentativePartnerId': _blank(_customer.text),
      'familyRepresentativeName': _blank(_representativeName.text),
      'familyRepresentativeContact': _blank(_representativeContact.text),
      'cemeteryName': _blank(_cemetery.text),
      'cemeteryArea': _blank(_cemeteryArea.text),
      'graveNumber': _blank(_grave.text),
      'salesArea': _blank(_salesArea.text),
      'installationDirections': _blank(_directions.text),
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

  // These are order/invoice and production prerequisites. Drafts may remain
  // incomplete; claim initiation and final generation may not.
  String? _requiredOrderDetailsError() {
    if (_deceasedName.text.trim().isEmpty) return 'Enter the deceased full name (Step 1).';
    if (_chosenCovers.isNotEmpty && _dateOfDeath == null) {
      return 'Date of death is required when claiming membership cover (Step 1).';
    }
    if (_customer.text.trim().isEmpty) return 'Select or capture the invoice customer / family representative (Step 3).';
    if (_representativeName.text.trim().isEmpty) return 'Enter the family representative name (Step 3).';
    if (_representativeContact.text.trim().isEmpty) return 'Enter the family representative contact details for invoicing and installation (Step 3).';
    final packages = _items.where((item) => item.itemType == 'TOMBSTONE').toList();
    if (packages.length != 1) return 'Select exactly one Tombstone package (Step 4).';
    final package = packages.single;
    if (package.productId == null || package.productId!.trim().isEmpty) {
      return 'Select a configured Tombstone product to invoice (Step 4).';
    }
    if (package.description.text.trim().isEmpty) return 'The Tombstone package needs an invoice description (Step 4).';
    if ((double.tryParse(package.amount.text) ?? 0) <= 0) return 'The Tombstone package must have a positive configured price (Step 4).';
    if (package.inscription.text.trim().isEmpty) return 'Enter the exact inscription / engraving text supplied by the family (Step 4).';
    if (package.material.text.trim().isEmpty) return 'Enter the tombstone material for production (Step 4).';
    if (package.colour.text.trim().isEmpty) return 'Enter the tombstone colour for production (Step 4).';
    if (package.dimensions.text.trim().isEmpty) return 'Enter the tombstone dimensions for production (Step 4).';
    if (_salesArea.text.trim().isEmpty) return 'Select an Installation Area (Step 4).';
    if (_directions.text.trim().isEmpty) return 'Enter directions to the installation site (Step 4).';
    for (final item in _items) {
      if (item.productId == null || item.productId!.trim().isEmpty || item.description.text.trim().isEmpty) {
        return 'Each selected product or extra needs its catalogue ID and invoice description (Step 4).';
      }
      if (double.tryParse(item.amount.text) == null || double.parse(item.amount.text) < 0) {
        return 'Each selected product or extra needs a valid price (Step 4).';
      }
    }
    final discount = double.tryParse(_discount.text);
    if (discount == null || discount < 0 || _discountCents > _totalCents) {
      return 'Enter a valid discount that does not exceed the order total (Step 4).';
    }
    return null;
  }

  void _showOrderDetailsError(String message) {
    setState(() {
      _error = message;
      if (message.contains('Step 1')) {
        _step = 0;
      } else if (message.contains('Step 3')) {
        _step = 2;
      } else if (message.contains('Step 4')) {
        _step = 3;
      }
    });
  }

  bool _validateStep(int step) {
    if (step == 0 && _deceasedName.text.trim().isEmpty) {
      _showOrderDetailsError('Enter the deceased full name (Step 1).'); return false;
    }
    if (step == 1 && _chosenCovers.isNotEmpty && _dateOfDeath == null) {
      _showOrderDetailsError('Date of death is required when claiming membership cover (Step 1).'); return false;
    }
    if (step == 2) {
      if (_customer.text.trim().isEmpty) {
        _showOrderDetailsError('Select or capture the invoice customer / family representative (Step 3).'); return false;
      }
      if (_representativeName.text.trim().isEmpty || _representativeContact.text.trim().isEmpty) {
        _showOrderDetailsError('Family representative name and contact details are required (Step 3).'); return false;
      }
    }
    if (step == 3) {
      final error = _requiredOrderDetailsError();
      if (error != null) { _showOrderDetailsError(error); return false; }
    }
    return true;
  }

  void _goToStep(int destination) {
    if (destination > _step) {
      for (var i = 0; i < destination; i++) {
        if (!_validateStep(i)) return;
      }
    }
    setState(() { _error = null; _step = destination; });
  }

  Future<void> _save() async {
    if (_deceasedName.text.trim().isEmpty) {
      setState(() => _error = 'Enter the deceased full name supplied by the family.'); return;
    }
    if (_chosenCovers.isNotEmpty && _dateOfDeath == null) {
      setState(() => _error = 'Date of death is required only when claiming membership cover.'); return;
    }
    if (_customer.text.trim().isEmpty) { setState(() => _error = 'Select or capture the family representative.'); return; }
    if (_items.where((i) => i.itemType == 'TOMBSTONE').length != 1) {
      setState(() => _error = 'Select one Tombstone package for the deceased.'); return;
    }
    if (_items.any((i) => (double.tryParse(i.amount.text) ?? -1) < 0)) {
      setState(() => _error = 'Tombstone package or extra contains an invalid price.'); return;
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
    final missing = _requiredOrderDetailsError();
    if (missing != null) { _showOrderDetailsError(missing); return; }
    if (_chosenCovers.isEmpty) {
      setState(() => _error = 'No claim is needed for a customer-funded installation.');
      return;
    }
    // Persist any changed engraving, pricing or installation details before
    // locking the request by initiating claims.
    if (_isEditable) await _save();
    if (_requestId == null || _error != null) return;
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
    final missing = _requiredOrderDetailsError();
    if (missing != null) { _showOrderDetailsError(missing); return; }
    // Finalise draft edits before the backend creates an order and invoice.
    if (_isEditable) await _save();
    if (_requestId == null || _error != null) {
      if (_requestId == null && _error == null) {
        setState(() => _error = 'Save the installation request first.');
      }
      return;
    }
    if (_chosenCovers.isNotEmpty && _claims.isEmpty) {
      setState(() => _error = 'Initiate Tombstone Claims for the selected cover first.'); return;
    }
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
    final selection = await showDialog<Partner>(
      context: context,
      builder: (_) => DeceasedPartnerLookupDialog(
        initialQuery: _identity.text.trim().isNotEmpty
            ? _identity.text.trim()
            : _deceasedName.text.trim(),
      ),
    );
    if (selection != null && mounted) {
      setState(() {
        _deceasedId.text = selection.id;
        _deceasedName.text = selection.fullName;
        if (selection.identityNumber.isNotEmpty) {
          _identity.text = selection.identityNumber;
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
  Widget _field(TextEditingController controller, String label,
      {bool isRequired = false, int lines = 1, ValueChanged<String>? onChanged}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: TextField(
      enabled: _isEditable,
      controller: controller, maxLines: lines,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: '$label${isRequired ? ' *' : ''}', border: const OutlineInputBorder()),
    ));
  Widget _hint(String message) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Text(message, style: Theme.of(context).textTheme.bodyMedium));

  // Keep the wizard fluid across the available width. On desktop, related
  // sections sit side by side; narrow tablet/mobile viewports stack them.
  Widget _adaptiveSections({required Widget left, required Widget right}) =>
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 1000) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            left,
            const SizedBox(height: 20),
            right,
          ]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: left),
          const SizedBox(width: 28),
          Expanded(child: right),
        ]);
      });

  // Cemetery and cemetery section are tenant-managed dropdowns; the grave
  // number stays free text. Keep old draft values visible even if removed from
  // reference data, instead of silently clearing an existing location.
  Widget _locationDropdown(TextEditingController controller, String title,
      List<FieldOption> options, {bool storeCode = false}) {
    final values = <String, String>{};
    for (final option in options) {
      final value = storeCode ? option.code.trim() :
          (option.description.trim().isNotEmpty ? option.description.trim() : option.code.trim());
      if (value.isNotEmpty) values[value] = option.description.trim().isEmpty ? option.code : option.description;
    }
    final current = controller.text.trim();
    if (current.isNotEmpty && !values.containsKey(current)) {
      values[current] = '$current (previously selected)';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DropdownButtonFormField<String>(
        key: ValueKey('$title:$current:${values.keys.join('|')}'),
        initialValue: current.isEmpty ? null : current,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: title,
          hintText: options.isEmpty ? 'No options configured' : 'Select $title',
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(value: '', child: Text('Not specified')),
          ...values.entries.map((e) => DropdownMenuItem<String>(
            value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))),
        ],
        onChanged: !_isEditable ? null : (value) => setState(() => controller.text = value ?? ''),
      ),
    );
  }

  _ItemInput? get _package {
    for (final item in _items) {
      if (item.itemType == 'TOMBSTONE') return item;
    }
    return null;
  }

  void _choosePackage(ProductLookup product) {
    if (!_isEditable) return;
    setState(() {
      final current = _package;
      if (current?.productId == product.id) return;
      final inscription = current?.inscription.text ?? '';
      _items.removeWhere((item) => item.itemType == 'TOMBSTONE');
      current?.dispose();
      final selected = _ItemInput.fromProduct(product, itemType: 'TOMBSTONE');
      selected.inscription.text = inscription;
      _items.insert(0, selected);
    });
  }

  Future<void> _addExtra() async {
    if (_extraProducts.isEmpty) return;
    final product = await showDialog<ProductLookup>(context: context, builder: (dialogContext) {
      String query = '';
      return StatefulBuilder(builder: (context, updateDialog) {
        final filtered = _extraProducts.where((product) =>
          !_items.any((item) => item.productId == product.id) &&
          '${product.code} ${product.description}'.toLowerCase().contains(query.toLowerCase())).toList();
        return AlertDialog(
          title: const Text('Add an optional extra'),
          content: SizedBox(width: 560, height: 430, child: Column(children: [
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
                hintText: 'Search products or services'),
              onChanged: (text) => updateDialog(() => query = text)),
            Expanded(child: ListView.builder(itemCount: filtered.length, itemBuilder: (_, index) {
              final item = filtered[index];
              return ListTile(title: Text(item.description),
                subtitle: Text(item.code), trailing: Text(_money(item.priceCents)),
                onTap: () => Navigator.of(dialogContext).pop(item));
            })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel'))],
        );
      });
    });
    if (product == null || !mounted) return;
    if (_items.any((item) => item.productId == product.id)) return;
    setState(() => _items.add(_ItemInput.fromProduct(product, itemType: 'EXTRA')));
  }

  Widget _packageStep() {
    final package = _package;
    final extras = _items.where((item) => item.itemType != 'TOMBSTONE').toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _hint('Select one tombstone package for the deceased, then add optional extras. Quantities are fixed at one installation.'),
      _adaptiveSections(
        left: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Select Tombstone Package', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_catalogLoading) const LinearProgressIndicator(),
          if (_catalogError != null) Text(_catalogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_catalogLoading && _tombstoneProducts.isEmpty)
            const ListTile(leading: Icon(Icons.inventory_2_outlined),
              title: Text('No Tombstone products configured'),
              subtitle: Text('Configure Tombstone products and prices in Product Maintenance before creating an installation order.')),
          ..._tombstoneProducts.map((product) {
            final selected = package?.productId == product.id && product.id.isNotEmpty;
            return Card(child: ListTile(
              leading: Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? Theme.of(context).colorScheme.primary : null),
              title: Text(product.description),
              subtitle: product.code.isEmpty ? null : Text(product.code),
              trailing: Text(_money(product.priceCents)),
              selected: selected,
              onTap: _isEditable ? () => _choosePackage(product) : null,
            ));
          }),
          if (package != null && !_tombstoneProducts.any((p) => p.id == package.productId))
            Card(child: ListTile(leading: const Icon(Icons.check_circle),
              title: Text(package.description.text),
              subtitle: const Text('Saved package (not in current product catalogue)'),
              trailing: Text(_money(((double.tryParse(package.amount.text) ?? 0) * 100).round())))),
          if (package != null) ...[
            _field(package.inscription, 'Exact inscription / engraving wording', isRequired: true, lines: 4),
            _hint('Confirm spelling, dates and wording with the family. The exact text will be sent to production.'),
            _adaptiveSections(
              left: _field(package.material, 'Tombstone material', isRequired: true),
              right: _field(package.colour, 'Tombstone colour', isRequired: true),
            ),
            _field(package.dimensions, 'Tombstone dimensions', isRequired: true),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: Text('Optional Extras', style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(onPressed: _isEditable && _extraProducts.isNotEmpty ? _addExtra : null,
              icon: const Icon(Icons.add), label: const Text('Add extra')),
          ]),
          if (extras.isEmpty) const ListTile(title: Text('No extras selected')),
          ...extras.map((extra) => ListTile(
            title: Text(extra.description.text),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_money(((double.tryParse(extra.amount.text) ?? 0) * 100).round())),
              if (_isEditable) IconButton(icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() { _items.remove(extra); extra.dispose(); })),
            ]),
          )),
        ]),
        right: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Installation Location', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _locationDropdown(_salesArea, 'Installation area *', _installationAreas, storeCode: true),
          _locationDropdown(_cemetery, 'Cemetery (optional)', _cemeteryOptions),
          _locationDropdown(_cemeteryArea, 'Cemetery section (optional)', _cemeteryAreaOptions),
          _field(_grave, 'Grave number (if available)'),
          _field(_directions, 'Directions to installation site', isRequired: true, lines: 4),
          ListTile(title: const Text('Expected installation date'),
            subtitle: Text(_date(_installationDate) ?? 'Not scheduled'),
            trailing: const Icon(Icons.calendar_month),
            onTap: _isEditable ? () => _pickDate(installation: true) : null),
          const SizedBox(height: 8),
          _field(_discount, 'Overall discount (R)'),
          _field(_notes, 'Additional instructions', lines: 3),
          const Divider(height: 36),
          ListTile(title: const Text('Tombstone package'),
            trailing: Text(_money(package == null ? 0 : ((double.tryParse(package.amount.text) ?? 0) * 100).round()))),
          ListTile(title: const Text('Extras'),
            trailing: Text(_money(extras.fold<int>(0, (sum, e) => sum + ((double.tryParse(e.amount.text) ?? 0) * 100).round())))),
          ListTile(title: const Text('Estimated installation total'),
            trailing: Text(_money((_totalCents - _discountCents).clamp(0, 999999999999).toInt()))),
        ]),
      ),
    ]);
  }

  Widget _content() {
    switch (_step) {
      case 0:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint("Capture details from the family's tombstone information form. We do not need to have conducted the funeral. No death certificate or mortuary admission is required."),
          _adaptiveSections(
            left: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _field(_deceasedName, 'Deceased full name', isRequired: true,
                onChanged: (_) {
                  if (_deceasedId.text.isNotEmpty) setState(() => _deceasedId.clear());
                }),
              _field(_identity, 'Deceased identity number (if available)',
                onChanged: (_) {
                  if (_deceasedId.text.isNotEmpty) setState(() => _deceasedId.clear());
                }),
            ]),
            right: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(onPressed: _isEditable ? _selectDeceasedPartner : null,
                icon: const Icon(Icons.person_search), label: const Text('Link existing deceased partner (optional)')),
              if (_deceasedId.text.trim().isNotEmpty)
                ListTile(title: const Text('Existing MAWA deceased record linked'),
                  trailing: _isEditable ? IconButton(onPressed: () => setState(() => _deceasedId.clear()),
                    tooltip: 'Unlink deceased', icon: const Icon(Icons.close)) : null),
              ListTile(title: const Text('Date of death (required only for a membership claim)'),
                subtitle: Text(_date(_dateOfDeath) ?? 'Not supplied by family'),
                trailing: const Icon(Icons.calendar_month), onTap: _isEditable ? () => _pickDate(installation: false) : null),
            ]),
          ),
        ]);
      case 1:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Membership cover is optional. For a private installation paid by the family, leave all covers unselected. If claiming a Tombstone benefit, enter the deceased identity and date of death first.'),
          _adaptiveSections(
            left: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(onPressed: _isEditable ? _lookup : null, icon: const Icon(Icons.search), label: const Text('Find eligible Tombstone benefits')),
              if (_covers.isEmpty) const ListTile(title: Text('No Tombstone cover selected'),
                subtitle: Text('You may continue with a customer-funded installation; no membership claim or grocery claim will be created.')),
            ]),
            right: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (_covers.isNotEmpty) Text('Available membership covers', style: Theme.of(context).textTheme.titleMedium),
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
            ]),
          ),
        ]);
      case 2:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint('Select or create a family representative using the existing partner workflow.'),
          _adaptiveSections(
            left: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              OutlinedButton.icon(onPressed: _isEditable ? _selectRepresentative : null,
                icon: const Icon(Icons.person_search), label: const Text('Select family representative')),
              if (_customer.text.isNotEmpty) Text('Partner: ${_representativeName.text} • ${_customer.text}'),
            ]),
            right: _field(_representativeContact, 'Representative contact details for invoice and installation', isRequired: true),
          ),
        ]);
      case 3:
        return _packageStep();
      case 4:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _hint(_chosenCovers.isEmpty
            ? 'No membership cover selected: save the family-supplied installation details and proceed to the order preview. No claim is required.'
            : 'Save the request, initiate TOMBSTONE claims, and submit the claim form and applicable supporting family information for approval. A death certificate is not requested for installation.'),
          if (_requestId == null || _status == 'DRAFT') ...[
            FilledButton.icon(onPressed: _busy ? null : _save, icon: const Icon(Icons.save_outlined), label: const Text('Save request')),
            const SizedBox(height: 12),
            if (_chosenCovers.isNotEmpty)
              FilledButton.icon(onPressed: _busy ? null : _initiate, icon: const Icon(Icons.description_outlined), label: const Text('Initiate Tombstone Claims')),
          ],
          if (_claims.isEmpty) ListTile(title: Text(_chosenCovers.isEmpty ? 'No membership claim required' : 'No Tombstone Claims initiated')),
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
          _hint('Preview the tombstone order and customer balance. Only approved membership claims count as funding; a family-funded request has no claim.'),
          ListTile(title: Text('Request ${_reference ?? '(not yet saved)'}'), subtitle: Text('Deceased: ${_deceasedName.text}')),
          ListTile(title: const Text('Invoice customer / family representative'),
            subtitle: Text('${_representativeName.text} • ${_representativeContact.text}')),
          if (_package != null) ...[
            ListTile(title: const Text('Tombstone package'),
              subtitle: Text(_package!.description.text)),
            ListTile(title: const Text('Engraving wording'),
              subtitle: Text(_package!.inscription.text)),
            ListTile(title: const Text('Production specification'),
              subtitle: Text('${_package!.material.text} • ${_package!.colour.text} • ${_package!.dimensions.text}')),
          ],
          ListTile(title: const Text('Installation Area / Directions'),
            subtitle: Text('${_salesArea.text} • ${_directions.text}')),
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
            FilledButton.icon(onPressed: _busy || _requestId == null || (_chosenCovers.isNotEmpty && _claims.isEmpty) ? null : _generate,
              icon: const Icon(Icons.receipt_long), label: const Text('Generate Tombstone Order & Invoice')),
          if (_orderId != null) ...[
            const ListTile(leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Order generated'), subtitle: Text('Manage production and installation in Tombstone Management.')),
            if (_claims.isNotEmpty)
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
              onSelected: (_) => _goToStep(index)),
          )))),
        if (_error != null) Card(color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(title: Text(_error!), trailing: IconButton(onPressed: () => setState(() => _error = null), icon: const Icon(Icons.close)))),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: LayoutBuilder(builder: (context, viewport) => SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: viewport.maxWidth >= 1000 ? 32 : (viewport.maxWidth >= 600 ? 24 : 16),
            vertical: 20,
          ),
          child: SizedBox(
            width: viewport.maxWidth - (viewport.maxWidth >= 1000 ? 64 : (viewport.maxWidth >= 600 ? 48 : 32)),
            child: _content(),
          ),
        ))),
        Padding(padding: const EdgeInsets.all(12), child: Row(children: [
          OutlinedButton(onPressed: _step > 0 ? () => setState(() => _step--) : null, child: const Text('Back')),
          const Spacer(),
          if (_status == 'DRAFT' && _step != 4)
            OutlinedButton(onPressed: _busy ? null : _save, child: const Text('Save draft')),
          const SizedBox(width: 12),
          FilledButton(onPressed: _step < 6 ? () => _goToStep(_step + 1) : null,
            child: const Text('Next')),
        ])),
      ]),
    );
  }
}
