import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/widgets/app_dropdown.dart';
import '../../../partners/models/partner.dart';
import '../../../partners/partner_service.dart';

class FamilyRepresentativeSelection {
  final Partner partner;
  final String contactDetails;

  const FamilyRepresentativeSelection({
    required this.partner,
    required this.contactDetails,
  });
}

class FamilyRepresentativeSelectorDialog extends StatefulWidget {
  const FamilyRepresentativeSelectorDialog({super.key});

  @override
  State<FamilyRepresentativeSelectorDialog> createState() =>
      _FamilyRepresentativeSelectorDialogState();
}

class _FamilyRepresentativeSelectorDialogState
    extends State<FamilyRepresentativeSelectorDialog> {
  final _identityFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();
  final _identityNumber = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _contactDetails = TextEditingController();

  String? _identityType;
  Partner? _partner;
  bool _notFound = false;
  bool _withoutIdentity = false;
  bool _searching = false;
  bool _saving = false;
  int _step = 0;
  String? _error;

  bool get _isSaId =>
      (_identityType ?? '').trim().toUpperCase() == 'SA-ID';

  @override
  void dispose() {
    _identityNumber.dispose();
    _firstName.dispose();
    _middleName.dispose();
    _lastName.dispose();
    _contactDetails.dispose();
    super.dispose();
  }

  DateTime? _dateOfBirthFromSaId(String idNumber) {
    final digits = idNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 13) return null;
    final yy = int.tryParse(digits.substring(0, 2));
    final mm = int.tryParse(digits.substring(2, 4));
    final dd = int.tryParse(digits.substring(4, 6));
    if (yy == null || mm == null || dd == null) return null;
    final now = DateTime.now();
    var candidate = DateTime(2000 + yy, mm, dd);
    if (candidate.year != 2000 + yy ||
        candidate.month != mm ||
        candidate.day != dd) {
      return null;
    }
    if (candidate.isAfter(now)) candidate = DateTime(1900 + yy, mm, dd);
    if (candidate.month != mm || candidate.day != dd || candidate.isAfter(now)) {
      return null;
    }
    return candidate;
  }

  Future<void> _search() async {
    if (_withoutIdentity) {
      setState(() {
        _partner = null;
        _notFound = true;
        _step = 1;
        _error = null;
      });
      return;
    }
    if (!_identityFormKey.currentState!.validate()) return;

    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final identity = await PartnerService().getIdentity(
        _identityType!.trim(),
        _identityNumber.text.trim(),
      );
      Partner? found;
      if (identity?.partner != null && identity!.partner!.trim().isNotEmpty) {
        found = await PartnerService().getPartnerById(identity.partner!.trim());
      }
      if (found != null && found.type.toUpperCase() != 'INDIVIDUAL') {
        throw AppException(
          'The identity belongs to a non-individual partner and cannot be selected as a family representative.',
        );
      }

      if (found != null) {
        final contacts = await PartnerService().getPartnerContacts(found.id);
        if (contacts.isNotEmpty) {
          _contactDetails.text = contacts
              .where((contact) => contact.value.trim().isNotEmpty)
              .map((contact) => contact.value.trim())
              .toSet()
              .join(' / ');
        }
      }

      if (!mounted) return;
      setState(() {
        _partner = found;
        _notFound = found == null;
        _step = 1;
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<Partner> _createPartner() {
    final payload = <String, dynamic>{
      'type': 'INDIVIDUAL',
      'partnerType': 'INDIVIDUAL',
      'partnerRole': 'CUSTOMER',
      'name1': _lastName.text.trim().toUpperCase(),
      'name2': _firstName.text.trim().toUpperCase(),
      'name3': _middleName.text.trim().toUpperCase(),
      'status': 'ACTIVE',
    };
    if (!_withoutIdentity) {
      payload['identityType'] = _identityType!.trim();
      payload['identityNumber'] = _identityNumber.text.trim();
      if (_isSaId) {
        payload['birthDate'] = _dateOfBirthFromSaId(
          _identityNumber.text.trim(),
        )?.toIso8601String();
      }
    }
    return PartnerService().createPartner(payload);
  }

  Future<void> _select() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final partner = _partner ?? await _createPartner();
      if (!mounted) return;
      Navigator.pop(
        context,
        FamilyRepresentativeSelection(
          partner: partner,
          contactDetails: _contactDetails.text.trim(),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    setState(() {
      _step = 0;
      _partner = null;
      _notFound = false;
      _error = null;
    });
  }

  String? _required(String? value) =>
      (value ?? '').trim().isEmpty ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.family_restroom)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Family Representative',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Step ${_step + 1} of 2 • ${_step == 0 ? 'Search identity' : 'Representative details'}',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _step == 0 ? _identityStep() : _detailsStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityStep() {
    return Form(
      key: _identityFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _withoutIdentity
                ? 'Capture the representative details without an identity number.'
                : 'Search for the partner before continuing.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _withoutIdentity,
            title: const Text(
              'Family representative does not have an identity number',
            ),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (value) => setState(() {
              _withoutIdentity = value ?? false;
              if (_withoutIdentity) {
                _identityNumber.clear();
                _error = null;
              }
            }),
          ),
          const SizedBox(height: 10),
          IgnorePointer(
            ignoring: _withoutIdentity,
            child: Opacity(
              opacity: _withoutIdentity ? .45 : 1,
              child: AppDropdownField(
                field: 'ID-TYPE',
                label: 'ID Type',
                icon: Icons.badge_outlined,
                value: _identityType,
                onChanged: (value) => setState(() => _identityType = value),
                validator: (value) => _withoutIdentity ||
                        (value ?? '').trim().isNotEmpty
                    ? null
                    : 'ID Type is required',
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _identityNumber,
            enabled: !_withoutIdentity,
            keyboardType: _isSaId ? TextInputType.number : TextInputType.text,
            inputFormatters: _isSaId
                ? [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ]
                : null,
            decoration: const InputDecoration(
              labelText: 'ID Number',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
            validator: (value) {
              if (_withoutIdentity) return null;
              final entered = (value ?? '').trim();
              if (entered.isEmpty) return 'ID Number is required';
              if (_isSaId &&
                  (entered.length != 13 ||
                      _dateOfBirthFromSaId(entered) == null)) {
                return 'Enter a valid 13-digit SA ID';
              }
              return null;
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _searching ? null : _search,
            icon: _searching
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_withoutIdentity ? 'CONTINUE' : 'SEARCH PARTNER'),
          ),
        ],
      ),
    );
  }

  Widget _detailsStep() {
    return Form(
      key: _detailsFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _withoutIdentity
                  ? 'No identity number'
                  : '${_identityType ?? 'ID'} • ${_identityNumber.text.trim()}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          if (_partner != null)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partner found',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _partner!.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (_partner!.number.isNotEmpty)
                      Text('Partner #: ${_partner!.number}'),
                  ],
                ),
              ),
            )
          else if (_notFound) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No partner found. Capture the representative details below. The new partner will be created with the CUSTOMER role.',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _firstName,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'First Name',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _middleName,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Middle Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastName,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Last Name',
                border: OutlineInputBorder(),
              ),
              validator: _required,
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _contactDetails,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Contact Details *',
              hintText: 'Cellphone, alternate contact, email or other details',
              border: OutlineInputBorder(),
            ),
            validator: _required,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _back,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('SEARCH AGAIN'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _select,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_partner == null ? 'CREATE & SELECT' : 'SELECT'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
