import 'package:flutter/material.dart';
import '../models/membership_change.dart';
import '../models/membership_detail.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import '../../partners/models/partner.dart';
import '../../partners/partner_service.dart';
import '../widgets/membership_plan_dropdown.dart';

class MembershipChangeSection extends StatefulWidget {
  final MembershipDetail membership;
  final VoidCallback onChanged;
  const MembershipChangeSection({super.key, required this.membership, required this.onChanged});

  @override
  State<MembershipChangeSection> createState() => _MembershipChangeSectionState();
}

class _MembershipChangeSectionState extends State<MembershipChangeSection> {
  bool _loading = true;
  List<MembershipChange> _changes = const [];
  List<MembershipChangeAudit> _audit = const [];
  MembershipChangeConfiguration _configuration = const MembershipChangeConfiguration(3);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        MembershipService().getMembershipChanges(widget.membership.id),
        MembershipService().getMembershipChangeAudit(widget.membership.id),
        MembershipService().getMembershipChangeConfiguration(),
      ]);
      if (!mounted) return;
      setState(() {
        _changes = results[0] as List<MembershipChange>;
        _audit = results[1] as List<MembershipChangeAudit>;
        _configuration = results[2] as MembershipChangeConfiguration;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasOpenChange => _changes.any((item) => item.isOpen);

  Future<Partner?> _selectPartner() async {
    final query = TextEditingController();
    List<Partner> rows = [];
    bool loading = false;
    final result = await showDialog<Partner>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select New Member'),
          content: SizedBox(
            width: 560,
            height: 430,
            child: Column(
              children: [
                TextField(
                  controller: query,
                  decoration: InputDecoration(
                    labelText: 'Search partner',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        setDialogState(() => loading = true);
                        rows = await PartnerService().getPartners(query: query.text.trim());
                        setDialogState(() => loading = false);
                      },
                    ),
                  ),
                  onSubmitted: (_) async {
                    setDialogState(() => loading = true);
                    rows = await PartnerService().getPartners(query: query.text.trim());
                    setDialogState(() => loading = false);
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (_, index) {
                            final partner = rows[index];
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                              title: Text(partner.fullName),
                              subtitle: Text('${partner.number} • ${partner.identityNumber}'),
                              onTap: () => Navigator.pop(context, partner),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL'))],
        ),
      ),
    );
    query.dispose();
    return result;
  }

  Future<void> _requestTransfer() async {
    final partner = await _selectPartner();
    if (partner == null || !mounted) return;
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Transfer Membership'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Transfer ${widget.membership.membershipNo} to ${partner.fullName}?'),
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
      await MembershipService().requestMembershipTransfer(widget.membership.id, partner.id, reason.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Membership transfer submitted for approval')));
      await _load();
      widget.onChanged();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
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
            Text('Approved changes take effect after ${_configuration.planChangeWaitingPeriodMonths} month(s). Claims use the plan valid on the date of death.'),
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    } finally { reason.dispose(); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestTransfer, icon: const Icon(Icons.swap_horiz), label: const Text('TRANSFER MEMBERSHIP')),
        OutlinedButton.icon(onPressed: _hasOpenChange ? null : _requestPlanChange, icon: const Icon(Icons.upgrade), label: const Text('CHANGE PLAN')),
      ]),
      if (_hasOpenChange) ...[
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
            leading: Icon(item.isTransfer ? Icons.swap_horiz : Icons.upgrade),
            title: Text(item.isTransfer ? 'Membership Transfer' : 'Plan Change'),
            subtitle: Text(
              '${item.isTransfer ? '${item.oldMemberName} → ${item.newMemberName}' : '${item.oldPlanName} → ${item.newPlanName}'}\n'
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
