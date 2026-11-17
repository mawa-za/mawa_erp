import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/app_error.dart';
import '../models/membership.dart';
import '../models/premium.dart';
import '../services/membership_service.dart';

/// One row per generated premium. Changes are staged in the UI, never applied directly.
class _PremiumEditRow {
  final Membership membership;
  final Premium premium;
  final TextEditingController amount;
  bool selected = false;

  _PremiumEditRow(this.membership, this.premium)
      : amount = TextEditingController(
          text: (premium.amountCents / 100).toStringAsFixed(2),
        );

  bool get canEdit => premium.status.toUpperCase() != 'CANCELLED' &&
      premium.status.toUpperCase() != 'REVERSED' &&
      membership.status.toUpperCase() != 'LAPSED' &&
      membership.status.toUpperCase() != 'MERGED';

  void dispose() => amount.dispose();
}

class BulkMembershipPremiumEditsScreen extends StatefulWidget {
  const BulkMembershipPremiumEditsScreen({super.key});

  @override
  State<BulkMembershipPremiumEditsScreen> createState() =>
      _BulkMembershipPremiumEditsScreenState();
}

class _BulkMembershipPremiumEditsScreenState
    extends State<BulkMembershipPremiumEditsScreen> {
  final _service = MembershipService();
  final _search = TextEditingController();
  final _reason = TextEditingController();
  final _commonAmount = TextEditingController();
  final _periodFrom = TextEditingController();
  final _periodTo = TextEditingController();
  final Map<String, Membership> _memberships = {};
  final List<_PremiumEditRow> _rows = [];
  List<Membership> _results = [];
  bool _loading = false;
  bool _submitting = false;
  bool _allowed = false;
  bool _accessLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _search.dispose();
    _reason.dispose();
    _commonAmount.dispose();
    _periodFrom.dispose();
    _periodTo.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final permissions = await _service.getBulkPremiumEditAccess();
      if (!mounted) return;
      setState(() {
        _allowed = permissions['edit'] == true && permissions['workcenter'] == true;
        _accessLoading = false;
      });
    } catch (error) {
      if (mounted) setState(() { _error = friendlyErrorMessage(error); _accessLoading = false; });
    }
  }

  Future<void> _findMembers() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _service.getMemberships(
        query: _search.text.trim(),
        status: 'ALL', size: 30, sort: ['membershipNo,desc'],
      );
      if (mounted) setState(() => _results = result.content);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember(Membership member) async {
    if (_memberships.containsKey(member.id) || _loading) return;
    if (_memberships.length >= 20) {
      _message('Work on up to 20 memberships at a time.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final premiums = await _service.getMembershipPremiums(member.id, oldId: member.oldId);
      if (!mounted) return;
      final existingIds = _rows.map((row) => row.premium.id).toSet();
      final fresh = premiums
          .where((premium) => !existingIds.contains(premium.id))
          .map((premium) => _PremiumEditRow(member, premium)).toList();
      setState(() {
        _memberships[member.id] = member;
        _rows.addAll(fresh);
        _rows.sort((a, b) {
          final result = a.membership.membershipNo.compareTo(b.membership.membershipNo);
          return result != 0 ? result : b.premium.periodYYYYMM.compareTo(a.premium.periodYYYYMM);
        });
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeMember(String membershipId) {
    setState(() {
      _memberships.remove(membershipId);
      final toRemove = _rows.where((r) => r.membership.id == membershipId).toList();
      _rows.removeWhere((r) => r.membership.id == membershipId);
      for (final row in toRemove) { row.dispose(); }
    });
  }

  /// Money inputs are parsed as decimal strings to avoid floating-point cents drift.
  int? _cents(String input) {
    final value = input.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    final whole = int.tryParse(parts.first);
    if (whole == null) return null;
    final cents = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
    final result = whole * 100 + cents;
    return result > 0 ? result : null;
  }

  void _applyAmount() {
    final cents = _cents(_commonAmount.text);
    if (cents == null) { _message('Enter a positive amount, with up to two decimal places.'); return; }
    setState(() {
      for (final row in _rows.where((r) => r.selected)) {
        row.amount.text = (cents / 100).toStringAsFixed(2);
      }
    });
  }

  List<_PremiumEditRow> get _filteredRows {
    final from = _periodFrom.text.trim();
    final to = _periodTo.text.trim();
    return _rows.where((row) {
      final p = row.premium.periodYYYYMM;
      return (from.isEmpty || p.compareTo(from) >= 0) &&
          (to.isEmpty || p.compareTo(to) <= 0);
    }).toList();
  }

  List<_PremiumEditRow> get _selected => _rows.where((r) => r.selected).toList();

  String _money(int cents) => (cents / 100).toStringAsFixed(2);

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final selected = _selected;
    if (selected.isEmpty) { _message('Select at least one premium period.'); return; }
    if (selected.length > 100) { _message('Select at most 100 premium periods per batch.'); return; }
    if (_reason.text.trim().isEmpty || _reason.text.trim().length > 1000) {
      _message('Enter a reason of up to 1000 characters.'); return;
    }
    final lines = <Map<String, dynamic>>[];
    var before = 0;
    var after = 0;
    for (final row in selected) {
      final proposed = _cents(row.amount.text);
      if (proposed == null) { _message('Enter a valid amount for ${row.membership.membershipNo}, ${row.premium.periodYYYYMM}.'); return; }
      if (proposed == row.premium.amountCents) { _message('The new amount must differ for ${row.membership.membershipNo}, ${row.premium.periodYYYYMM}.'); return; }
      if (proposed < row.premium.paidAmountCents) { _message('The amount for ${row.membership.membershipNo} cannot be less than its paid amount.'); return; }
      before += row.premium.amountCents;
      after += proposed;
      lines.add({
        'membershipId': row.membership.id,
        'premiumId': row.premium.id,
        'expectedAmountCents': row.premium.amountCents,
        'expectedPaidAmountCents': row.premium.paidAmountCents,
        'amountCents': proposed,
      });
    }
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Submit bulk premium edits for approval?'),
      content: SizedBox(width: 600, child: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
        children: [
          Text('${selected.length} premium period${selected.length == 1 ? '' : 's'} across ${selected.map((r) => r.membership.id).toSet().length} memberships.'),
          const SizedBox(height: 8),
          Text('Current total: ${_money(before)}'),
          Text('Proposed total: ${_money(after)}'),
          const SizedBox(height: 12),
          Text('Reason: ${_reason.text.trim()}'),
          const SizedBox(height: 12),
          const Text('Each row goes to the existing membership premium approval workflow. No premium amount changes until approved.', style: TextStyle(fontWeight: FontWeight.w600)),
          const Divider(),
          ...selected.take(12).map((r) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('${r.membership.membershipNo} · ${r.premium.periodYYYYMM}: ${_money(r.premium.amountCents)} → ${r.amount.text.trim()}'),
          )),
          if (selected.length > 12) Text('… and ${selected.length - 12} further rows'),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit for approval')),
      ],
    ));
    if (confirmed != true || !mounted) return;
    setState(() => _submitting = true);
    try {
      final response = await _service.submitBulkPremiumEdits(reason: _reason.text.trim(), lines: lines);
      if (!mounted) return;
      final count = response['submittedCount'] ?? lines.length;
      final batchId = response['batchId']?.toString() ?? '';
      for (final row in _rows) { row.dispose(); }
      setState(() {
        _rows.clear(); _memberships.clear(); _reason.clear();
        _results = [];
      });
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: const Text('Approval requests submitted'),
        content: SelectableText('$count premium edits were submitted for approval.\nBatch reference: $batchId\n\nTrack each request in Approvals.'),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
    } catch (error) {
      _message(friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCount = _selected.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Membership Premium Edits')),
      body: _accessLoading ? const Center(child: CircularProgressIndicator()) : !_allowed ? Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_error ?? 'You need both the Bulk Membership Premium Edits workcenter and the Correct premiums and payments permission.', textAlign: TextAlign.center),
      )) : ListView(padding: const EdgeInsets.all(20), children: [
        Text('Prepare premium corrections', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        const Text('Search memberships, select generated premium periods, and stage corrected amounts. Approval is required for each period.'),
        const SizedBox(height: 16),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('1. Find memberships', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextField(controller: _search, onSubmitted: (_) => _findMembers(),
                decoration: const InputDecoration(labelText: 'Membership number or search term', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: _loading ? null : _findMembers,
                icon: const Icon(Icons.search), label: const Text('Search')),
            ]),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
            if (_results.isNotEmpty) SizedBox(height: 180, child: ListView.builder(
              itemCount: _results.length, itemBuilder: (context, index) {
                final member = _results[index];
                return ListTile(dense: true,
                  title: Text('${member.membershipNo} · ${member.memberName}'),
                  subtitle: Text('Status: ${member.status}'),
                  trailing: _memberships.containsKey(member.id)
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : OutlinedButton(onPressed: _loading ? null : () => _addMember(member), child: const Text('Add')),
                );
              },
            )),
            if (_memberships.isNotEmpty) Wrap(spacing: 6, runSpacing: 6, children: [
              for (final member in _memberships.values)
                InputChip(label: Text(member.membershipNo), onDeleted: _submitting ? null : () => _removeMember(member.id)),
            ]),
          ],
        ))),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('2. Select premium periods ($selectedCount selected)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 160, child: TextField(controller: _periodFrom, onChanged: (_) => setState(() {}),
                maxLength: 6, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'From YYYYMM', border: OutlineInputBorder(), counterText: ''))),
              SizedBox(width: 160, child: TextField(controller: _periodTo, onChanged: (_) => setState(() {}),
                maxLength: 6, keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'To YYYYMM', border: OutlineInputBorder(), counterText: ''))),
              OutlinedButton(onPressed: _submitting ? null : () => setState(() {
                final visible = _filteredRows.where((r) => r.canEdit).toList();
                final room = 100 - _selected.length;
                for (final row in visible.where((r) => !r.selected).take(room)) { row.selected = true; }
              }), child: const Text('Select visible (max 100)')),
              TextButton(onPressed: _submitting ? null : () => setState(() {
                for (final row in _rows) { row.selected = false; }
              }), child: const Text('Clear selection')),
            ]),
            if (_rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Add one or more memberships to load generated premium periods.')))
            else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
              columns: const [
                DataColumn(label: Text('Select')), DataColumn(label: Text('Membership')),
                DataColumn(label: Text('Period')), DataColumn(label: Text('Status')),
                DataColumn(label: Text('Current')), DataColumn(label: Text('Paid')),
                DataColumn(label: Text('New amount')),
              ],
              rows: _filteredRows.map((row) => DataRow(cells: [
                DataCell(Checkbox(value: row.selected, onChanged: !row.canEdit || _submitting ? null : (value) {
                  if (value == true && !row.selected && selectedCount >= 100) {
                    _message('Maximum 100 periods per batch.'); return;
                  }
                  setState(() => row.selected = value ?? false);
                })),
                DataCell(Text(row.membership.membershipNo)),
                DataCell(Text(row.premium.periodYYYYMM)),
                DataCell(Text(row.premium.status)),
                DataCell(Text(_money(row.premium.amountCents))),
                DataCell(Text(_money(row.premium.paidAmountCents))),
                DataCell(SizedBox(width: 125, child: TextField(
                  controller: row.amount, enabled: row.selected && row.canEdit && !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                ))),
              ])).toList(),
            )),
          ],
        ))),
        if (selectedCount > 0) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('3. Apply changes and review', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SizedBox(width: 210, child: TextField(controller: _commonAmount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Common new amount', border: OutlineInputBorder()))),
              OutlinedButton(onPressed: _submitting ? null : _applyAmount, child: const Text('Apply to selected')),
            ]),
            const SizedBox(height: 12),
            TextField(controller: _reason, maxLength: 1000, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Reason for edits (required)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_submitting ? 'Submitting…' : 'Review $selectedCount edits and submit for approval')),
          ],
        ))),
      ]),
    );
  }
}
