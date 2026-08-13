import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../models/dependent.dart';
import '../services/membership_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import 'package:mawa_erp/core/widgets/searchable_dropdown_form_field.dart';

class AddDependentScreen extends StatefulWidget {
  final String membershipId;
  const AddDependentScreen({super.key, required this.membershipId});

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _identityFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();
  final _identityNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _reason = TextEditingController();
  String? _identityType;
  Partner? _partner;
  bool _notFound = false;
  bool _searching = false;
  bool _saving = false;
  int _step = 0;
  DependentType _relationship = DependentType.OTHER;
  String? _error;

  bool get _isSaId => (_identityType ?? '').trim().toUpperCase() == 'SA-ID';


  DateTime? _dateOfBirthFromSaId(String idNumber) {
    final digits = idNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return null;
    final yy = int.tryParse(digits.substring(0, 2));
    final mm = int.tryParse(digits.substring(2, 4));
    final dd = int.tryParse(digits.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    final now = DateTime.now();
    var candidate = DateTime(2000 + yy, mm, dd);
    if (candidate.year != 2000 + yy || candidate.month != mm || candidate.day != dd) return null;
    if (candidate.isAfter(now)) candidate = DateTime(1900 + yy, mm, dd);
    if (candidate.month != mm || candidate.day != dd || candidate.isAfter(now)) return null;
    return candidate;
  }

  @override
  void dispose() {
    for (final controller in [_identityNumber, _firstName, _middleName, _lastName, _reason]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    if (!_identityFormKey.currentState!.validate()) return;
    setState(() { _searching = true; _error = null; });
    try {
      final identity = await PartnerService().getIdentity(_identityType!.trim(), _identityNumber.text.trim());
      Partner? found;
      if (identity?.partner != null && identity!.partner!.trim().isNotEmpty) {
        found = await PartnerService().getPartnerById(identity.partner!.trim());
      }
      if (!mounted) return;
      if (found != null && found.type.toUpperCase() != 'INDIVIDUAL') {
        throw AppException('The identity belongs to a non-individual partner and cannot be added as a dependent.');
      }
      setState(() { _partner = found; _notFound = found == null; _step = 1; });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<Partner> _createPartner() => PartnerService().createPartner({
        'type': 'INDIVIDUAL',
        'partnerType': 'INDIVIDUAL',
        'name1': _lastName.text.trim().toUpperCase(),
        'name2': _firstName.text.trim().toUpperCase(),
        'name3': _middleName.text.trim().toUpperCase(),
        'identityType': _identityType!.trim(),
        'identityNumber': _identityNumber.text.trim(),
        'birthDate': _isSaId ? _dateOfBirthFromSaId(_identityNumber.text.trim())?.toIso8601String() : null,
        'status': 'ACTIVE',
      });

  Future<void> _save() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final partner = _partner ?? await _createPartner();
      final change = await MembershipService().addDependent(widget.membershipId, {
        'dependentPartnerId': partner.id,
        'dependentType': _relationship.name,
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      final pending = change.status == 'PENDING_APPROVAL';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(pending ? 'Dependent addition submitted for approval' : 'Dependent added successfully'),
        backgroundColor: pending ? Colors.orange[800] : Colors.green[700],
      ));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() => setState(() { _step = 0; _partner = null; _notFound = false; _error = null; });

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _header(),
            const Divider(height: 1),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: _step == 0 ? _identityStep() : _detailsStep())),
          ]),
        ),
      );

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        child: Row(children: [
          const CircleAvatar(child: Icon(Icons.person_add_alt_1_outlined)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Dependent', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
            Text('Step ${_step + 1} of 2 • ${_step == 0 ? 'Search identity' : 'Dependent details'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ])),
          IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
      );

  Widget _identityStep() => Form(
        key: _identityFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Search for the partner before continuing.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          AppDropdownField(field: 'ID-TYPE', label: 'ID Type', icon: Icons.badge_outlined, value: _identityType, onChanged: (v) => setState(() => _identityType = v), validator: (v) => (v ?? '').trim().isEmpty ? 'ID Type is required' : null),
          const SizedBox(height: 14),
          TextFormField(
            controller: _identityNumber,
            keyboardType: _isSaId ? TextInputType.number : TextInputType.text,
            inputFormatters: _isSaId ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)] : null,
            decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'ID Number is required';
              if (_isSaId && (value.length != 13 || _dateOfBirthFromSaId(value) == null)) return 'Enter a valid 13-digit SA ID';
              return null;
            },
          ),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _searching ? null : _search, icon: _searching ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search), label: const Text('SEARCH PARTNER')),
        ]),
      );

  Widget _detailsStep() => Form(
        key: _detailsFormKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _identitySummary(),
          const SizedBox(height: 14),
          if (_partner != null) _partnerSummary(_partner!) else if (_notFound) _newPartnerFields(),
          const SizedBox(height: 18),
          SearchableDropdownFormField<DependentType>(
            value: _relationship,
            decoration: const InputDecoration(labelText: 'Relationship Type', border: OutlineInputBorder()),
            items: DependentType.values.where((v) => v != DependentType.ANY && v != DependentType.MAIN_MEMBER).map((v) => DropdownMenuItem(value: v, child: Text(v.label))).toList(),
            onChanged: (v) => setState(() => _relationship = v ?? DependentType.OTHER),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder()), validator: _required),
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _back, icon: const Icon(Icons.arrow_back), label: const Text('SEARCH AGAIN'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_partner == null ? 'CREATE & ADD' : 'ADD DEPENDENT'))),
          ]),
        ]),
      );

  Widget _identitySummary() => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)), child: Text('${_identityType ?? 'ID'} • ${_identityNumber.text.trim()}', style: const TextStyle(fontWeight: FontWeight.w700)));

  Widget _partnerSummary(Partner p) => Card(elevation: 0, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Partner found', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text(p.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), if (p.number.isNotEmpty) Text('Partner #: ${p.number}')] )));

  Widget _newPartnerFields() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.withOpacity(.08), borderRadius: BorderRadius.circular(12)), child: const Text('No partner found. Capture the dependent details below.')),
        const SizedBox(height: 14),
        TextFormField(controller: _firstName, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()), validator: _required),
        const SizedBox(height: 12),
        TextFormField(controller: _middleName, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Middle Name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextFormField(controller: _lastName, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()), validator: _required),
      ]);

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;
}
