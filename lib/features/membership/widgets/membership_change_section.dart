import 'package:flutter/material.dart';
import '../models/membership_change.dart';
import '../models/dependent.dart';
import '../models/membership_detail.dart';
import '../models/membership.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import '../widgets/membership_plan_dropdown.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class MembershipChangeSection extends StatefulWidget {
  final MembershipDetail membership;
  final VoidCallback onChanged;
  final bool readOnly;
  const MembershipChangeSection({
    super.key,
    required this.membership,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<MembershipChangeSection> createState() => _MembershipChangeSectionState();
}

class _MembershipChangeSectionState extends State<MembershipChangeSection> {
  bool _loading = true;
  List<MembershipChange> _changes = const [];
  List<MembershipChangeAudit> _audit = const [];
  List<Dependent> _dependents = const [];
  MembershipChangeConfiguration _configuration = const MembershipChangeConfiguration(3);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        MembershipService().getMembershipChanges(widget.membership.id),
        MembershipService().getMembershipChangeAudit(widget.membership.id),
        MembershipService().getMembershipChangeConfiguration(),
        MembershipService().getMembershipDependents(widget.membership.id),
      ]);
      if (!mounted) return;
      setState(() {
        _changes = results[0] as List<MembershipChange>;
        _audit = results[1] as List<MembershipChangeAudit>;
        _configuration = results[2] as MembershipChangeConfiguration;
        _dependents = results[3] as List<Dependent>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasOpenChange => _changes.any((item) => item.isOpen);

  Future<Dependent?> _selectDependent() async {
    final activeDependents = _dependents
        .where((dependent) => dependent.active && dependent.membershipStatus == 'ACTIVE')
        .toList();
    if (activeDependents.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This membership has no active dependents available for transfer.')),
        );
      }
      return null;
    }
    return showDialog<Dependent>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Dependent'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: activeDependents.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final dependent = activeDependents[index];
              final identity = dependent.identity?.number ?? '';
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(dependent.fullName),
                subtitle: Text([
                  dependent.dependentType.replaceAll('_', ' '),
                  if (dependent.number.isNotEmpty) dependent.number,
                  if (identity.isNotEmpty) identity,
                ].join(' • ')),
                onTap: () => Navigator.pop(context, dependent),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL'))],
      ),
    );
  }

  Future<void> _requestTransfer() async {
    final dependent = await _selectDependent();
    if (dependent == null || !mounted) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Transfer Membership'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transfer ${widget.membership.membershipNo} to ${dependent.fullName}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reason,
              maxLines: 3,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            FilledButton(
              onPressed: reason.text.trim().isEmpty ? null : () => Navigator.pop(context, true),
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) { reason.dispose(); return; }
    try {
      await MembershipService().requestMembershipTransfer(widget.membership.id, dependent.dependentPartnerId, reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership transfer submitted for approval')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$e')), backgroundColor: Colors.red));
    } finally { reason.dispose(); }
  }

  Future<void> _requestPlanChange() async {
    MembershipPlan? selected;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upgrade or Downgrade Plan'),
          content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
            MembershipPlanDropdown(
              value: widget.membership.planId,
              onChanged: (plan) => setDialogState(() => selected = plan),
            ),
            const SizedBox(height: 12),
            Text('On final approval the new premium applies immediately. Downgrades also switch benefits immediately. Upgrades keep the existing benefits for ${_configuration.planChangeWaitingPeriodMonths} month(s), then the upgraded benefits start. Claims use the benefits effective on the date of death.'),
            const SizedBox(height: 12),
            TextField(controller: reason, maxLines: 3, onChanged: (_) => setDialogState(() {}), decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder())),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            FilledButton(
              onPressed: selected == null || selected!.id == widget.membership.planId || reason.text.trim().isEmpty
                  ? null : () => Navigator.pop(context, true),
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null) { reason.dispose(); return; }
    try {
      await MembershipService().requestMembershipPlanChange(widget.membership.id, selected!.id, reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan change submitted for approval')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$e')), backgroundColor: Colors.red));
    } finally { reason.dispose(); }
  }

  Future<void> _requestPremiumAmountChange() async {
    final amount = TextEditingController(text: widget.membership.premium.toStringAsFixed(2));
    final reason = TextEditingController();
    final request = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Membership Premium Amount'),
          content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Current recurring premium: R ${widget.membership.premium.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(labelText: 'New premium amount *', prefixText: 'R ', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 3,
              onChanged: (_) => setDialogState(() {}),
              decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('The recurring premium changes only after final approval.'),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
            FilledButton(
              onPressed: () {
                final value = double.tryParse(amount.text.trim().replaceAll(',', '.'));
                final cents = value == null ? 0 : (value * 100).round();
                if (cents <= 0 || cents == widget.membership.premiumCents || reason.text.trim().isEmpty) return;
                Navigator.pop(context, {'premiumCents': cents, 'reason': reason.text.trim()});
              },
              child: const Text('SUBMIT FOR APPROVAL'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    reason.dispose();
    if (request == null || !mounted) return;
    try {
      await MembershipService().requestMembershipPremiumAmountChange(
          widget.membership.id, request['premiumCents'] as int, request['reason'] as String);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Membership premium amount change submitted for approval')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('$e')), backgroundColor: Colors.red));
    }
  }

  Future<void> _requestMerge() async {
    final search = TextEditingController();
    final reason = TextEditingController();
    Membership? source;
    List<Membership> results = const [];
    bool searching = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Merge Membership'),
        content: SizedBox(width: 620, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Primary membership: ${widget.membership.membershipNo}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: search,
            decoration: InputDecoration(
              labelText: 'Find source membership',
              hintText: 'Membership number, member name or identity number',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: searching ? null : () async {
                if (search.text.trim().isEmpty) return;
                setDialogState(() => searching = true);
                try {
                  final page = await MembershipService().getMemberships(query: search.text.trim(), size: 20);
                  setDialogState(() => results = page.content.where((m) => m.id != widget.membership.id && m.status.toUpperCase() != 'MERGED').toList());
                } finally { setDialogState(() => searching = false); }
              }),
            ),
          ),
          if (searching) const LinearProgressIndicator(),
          if (results.isNotEmpty) SizedBox(height: 180, child: ListView.builder(
            itemCount: results.length,
            itemBuilder: (_, index) {
              final item = results[index];
              return RadioListTile<Membership>(
                value: item, groupValue: source,
                onChanged: (value) => setDialogState(() => source = value),
                title: Text(item.membershipNo),
                subtitle: Text([item.memberName, item.memberIdentityNumber, item.status].where((e) => e.isNotEmpty).join(' • ')),
              );
            },
          )),
          if (source != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('${source!.membershipNo} will become read-only. Its payments, claims and dependants will be consolidated into ${widget.membership.membershipNo} after approval.'),
          ),
          const SizedBox(height: 12),
          TextField(controller: reason, maxLines: 3, onChanged: (_) => setDialogState(() {}), decoration: const InputDecoration(labelText: 'Reason *', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          FilledButton(onPressed: source == null || reason.text.trim().isEmpty ? null : () => Navigator.pop(context, true), child: const Text('SUBMIT FOR APPROVAL')),
        ],
      )),
    );
    if (confirmed != true || source == null) { search.dispose(); reason.dispose(); return; }
    try {
      await MembershipService().requestMembershipMerge(widget.membership.id, source!.id, reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership merge submitted for approval')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('$e')), backgroundColor: Colors.red));
    } finally { search.dispose(); reason.dispose(); }
  }


  IconData _changeIcon(String changeType) {
    switch (changeType) {
      case 'TRANSFER':
        return Icons.swap_horiz;
      case 'PLAN_CHANGE':
        return Icons.upgrade;
      case 'PREMIUM_AMOUNT_CHANGE':
        return Icons.price_change_outlined;
      case 'ADD_DEPENDENT':
        return Icons.person_add_outlined;
      case 'REMOVE_DEPENDENT':
        return Icons.person_remove_outlined;
      case 'REPLACE_DEPENDENT':
        return Icons.find_replace_outlined;
      case 'MERGE':
        return Icons.merge_outlined;
      default:
        return Icons.edit_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!widget.readOnly)
        Wrap(spacing: 12, runSpacing: 12, children: [
          OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestTransfer, icon: const Icon(Icons.swap_horiz), label: const Text('TRANSFER MEMBERSHIP')),
          OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestPlanChange, icon: const Icon(Icons.upgrade), label: const Text('CHANGE PLAN')),
          OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestPremiumAmountChange, icon: const Icon(Icons.price_change_outlined), label: const Text('EDIT PREMIUM AMOUNT')),
          OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestMerge, icon: const Icon(Icons.merge_outlined), label: const Text('MERGE MEMBERSHIP')),
        ]),
      if (!widget.readOnly && _hasOpenChange) ...[
        const SizedBox(height: 8),
        const Text('A pending or scheduled membership change must be completed before another change can be requested.', style: TextStyle(color: Colors.orange)),
      ],
      const SizedBox(height: 16),
      if (_changes.isEmpty)
        const ListTile(leading: Icon(Icons.history), title: Text('No membership changes recorded'))
      else
        ..._changes.map((item) => Card(
          elevation: 0,
          child: ListTile(
            leading: Icon(_changeIcon(item.changeType)),
            title: Text(item.displayTitle),
            subtitle: Text(
              '${item.displayChange}\n'
              '${item.status.replaceAll('_', ' ')}${item.effectiveDate == null ? '' : ' • Effective ${item.effectiveDate}'}\n'
              '${item.reason}',
            ),
            trailing: item.approvalRequestId.isEmpty ? null : const Icon(Icons.approval_outlined),
          ),
        )),
      if (_audit.isNotEmpty) ExpansionTile(
        title: const Text('Audit Trail'),
        children: _audit.map((item) => ListTile(
          dense: true,
          leading: const Icon(Icons.history, size: 18),
          title: Text(item.eventType.replaceAll('_', ' ')),
          subtitle: Text('${item.details}\n${item.performedAt ?? ''} • ${item.performedBy}'),
        )).toList(),
      ),
    ]);
  }
}
