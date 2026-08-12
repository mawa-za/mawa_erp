import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/app_dropdown.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import '../widgets/membership_plan_dropdown.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

/// Identity-first membership creation wizard.
///
/// The user cannot select a plan or create a new partner until the identity
/// search has completed. This mirrors the MAWA Pay onboarding flow and avoids
/// creating duplicate partner records.
class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _identityFormKey = GlobalKey<FormState>();
  final _detailsFormKey = GlobalKey<FormState>();
  final _identityNumberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();

  int _step = 0;
  bool _searching = false;
  bool _saving = false;
  bool _partnerNotFound = false;
  String? _identityType;
  Partner? _partner;
  MembershipPlan? _plan;
  DateTime _dateJoined = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime? _dateOfBirth;
  String? _error;

  bool get _isSaId => (_identityType ?? '').trim().toUpperCase() == 'SA-ID';
  String _upper(String value) => value.trim().toUpperCase();
  String _fmt(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  @override
  void dispose() {
    _identityNumberController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
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
    try {
      var candidate = DateTime(2000 + yy, mm, dd);
      if (candidate.year != 2000 + yy || candidate.month != mm || candidate.day != dd) return null;
      if (candidate.isAfter(now)) candidate = DateTime(1900 + yy, mm, dd);
      if (candidate.month != mm || candidate.day != dd || candidate.isAfter(now)) return null;
      return candidate;
    } catch (_) {
      return null;
    }
  }

  Future<void> _searchPartner() async {
    if (!_identityFormKey.currentState!.validate()) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final identity = await PartnerService().getIdentity(
        _identityType!.trim(),
        _identityNumberController.text.trim(),
      );
      Partner? found;
      if (identity?.partner != null && identity!.partner!.trim().isNotEmpty) {
        found = await PartnerService().getPartnerById(identity.partner!.trim());
      }
      if (found != null && found.type.toUpperCase() != 'INDIVIDUAL') {
        throw AppException('The identity belongs to a non-individual partner and cannot be used for membership creation.');
      }
      if (!mounted) return;
      setState(() {
        _partner = found;
        _partnerNotFound = found == null;
        _step = 1;
        if (_isSaId) {
          _dateOfBirth = _dateOfBirthFromSaId(_identityNumberController.text);
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<Partner> _createPartner() {
    return PartnerService().createPartner({
      'type': 'INDIVIDUAL',
      'partnerType': 'INDIVIDUAL',
      'name1': _upper(_lastNameController.text),
      'name2': _upper(_firstNameController.text),
      'name3': _upper(_middleNameController.text),
      'identityType': _identityType!.trim(),
      'identityNumber': _identityNumberController.text.trim(),
      'birthDate': _dateOfBirth?.toIso8601String(),
      'status': 'ACTIVE',
    });
  }

  Future<void> _createMembership() async {
    if (!_detailsFormKey.currentState!.validate()) return;
    if (_plan == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final member = _partner ?? await _createPartner();
      final membershipId = await MembershipService().createMembership({
        'memberId': member.id,
        'planId': _plan!.id,
        'startDate': _fmt(_startDate),
        'joinDate': _fmt(_dateJoined),
        'status': 'ACTIVE',
      });
      if (!mounted) return;
      Navigator.of(context).pop(membershipId);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(DateTime current, ValueChanged<DateTime> onSelected) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) onSelected(picked);
  }

  Future<void> _pickBirthDate(FormFieldState<DateTime> field) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _dateOfBirth = picked);
    field.didChange(picked);
  }

  void _restartSearch() {
    setState(() {
      _step = 0;
      _partner = null;
      _partnerNotFound = false;
      _plan = null;
      _error = null;
      _dateOfBirth = null;
      _firstNameController.clear();
      _middleNameController.clear();
      _lastNameController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 760),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
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

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
        child: Row(
          children: [
            CircleAvatar(
              child: Icon(_step == 0 ? Icons.badge_outlined : Icons.card_membership_outlined),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Membership', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  Text('Step ${_step + 1} of 2 • ${_step == 0 ? 'Search partner identity' : 'Confirm partner and plan'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ],
        ),
      );

  Widget _identityStep() => Form(
        key: _identityFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Search for the person before creating a membership.', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            AppDropdownField(
              field: 'ID-TYPE',
              label: 'ID Type',
              icon: Icons.badge_outlined,
              value: _identityType,
              onChanged: (value) => setState(() { _identityType = value; _dateOfBirth = null; }),
              validator: (value) => (value ?? '').trim().isEmpty ? 'ID Type is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _identityNumberController,
              textCapitalization: TextCapitalization.characters,
              keyboardType: _isSaId ? TextInputType.number : TextInputType.text,
              inputFormatters: _isSaId ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)] : null,
              decoration: const InputDecoration(labelText: 'ID Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.numbers)),
              onChanged: (_) {
                if (!_isSaId && _dateOfBirth != null) setState(() => _dateOfBirth = null);
              },
              validator: (value) {
                final number = (value ?? '').trim();
                if (number.isEmpty) return 'ID Number is required';
                if (_isSaId && (number.length != 13 || _dateOfBirthFromSaId(number) == null)) return 'Enter a valid 13-digit SA ID';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _searching ? null : _searchPartner,
              icon: _searching
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              label: const Text('SEARCH PARTNER'),
            ),
          ],
        ),
      );

  Widget _detailsStep() => Form(
        key: _detailsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _identitySummary(),
            const SizedBox(height: 18),
            if (_partner != null)
              _partnerSummary(_partner!)
            else if (_partnerNotFound)
              _newPartnerFields(),
            const SizedBox(height: 22),
            MembershipPlanDropdown(
              value: _plan?.id,
              onChanged: (plan) => setState(() => _plan = plan),
              validator: (value) => value == null ? 'Please select a membership plan' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _dateField('Date Joined', _dateJoined, (v) => setState(() => _dateJoined = v))),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Policy Start Date', _startDate, (v) => setState(() => _startDate = v))),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _saving ? null : _restartSearch, icon: const Icon(Icons.arrow_back), label: const Text('SEARCH AGAIN'))),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _createMembership,
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_partner == null ? 'CREATE PARTNER & MEMBERSHIP' : 'CREATE MEMBERSHIP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _identitySummary() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.verified_user_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text('${_identityType ?? 'ID'} • ${_identityNumberController.text.trim()}', style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _partnerSummary(Partner partner) => Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Partner found', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(partner.fullName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            if (partner.number.isNotEmpty) Text('Partner #: ${partner.number}'),
            Text('${partner.idType ?? _identityType ?? 'ID'}: ${partner.identityNumber.isNotEmpty ? partner.identityNumber : _identityNumberController.text.trim()}'),
          ]),
        ),
      );

  Widget _newPartnerFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
            child: const Text('No partner was found. Capture the person details below; the searched identity will be used for the new partner.'),
          ),
          const SizedBox(height: 14),
          TextFormField(controller: _firstNameController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()), validator: _required),
          const SizedBox(height: 12),
          TextFormField(controller: _middleNameController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Middle Name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _lastNameController, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()), validator: _required),
          if (_isSaId && _dateOfBirth != null) ...[
            const SizedBox(height: 10),
            Text('Date of birth from SA ID: ${_fmt(_dateOfBirth!)}', style: TextStyle(color: Colors.grey[700])),
          ] else if (!_isSaId) ...[
            const SizedBox(height: 12),
            FormField<DateTime>(
              initialValue: _dateOfBirth,
              validator: (value) => value == null ? 'Date of Birth is required' : null,
              builder: (field) => InkWell(
                onTap: () => _pickBirthDate(field),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    border: const OutlineInputBorder(),
                    suffixIcon: const Icon(Icons.edit_calendar_outlined),
                    errorText: field.errorText,
                  ),
                  child: Text(_dateOfBirth == null ? 'Select date' : _fmt(_dateOfBirth!)),
                ),
              ),
            ),
          ],
        ],
      );

  Widget _dateField(String label, DateTime value, ValueChanged<DateTime> onSelected) => InkWell(
        onTap: () => _pickDate(value, onSelected),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today_outlined)),
          child: Text(_fmt(value)),
        ),
      );

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;
}
