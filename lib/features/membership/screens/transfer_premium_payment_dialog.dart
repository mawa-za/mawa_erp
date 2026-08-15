import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/membership.dart';
import '../services/membership_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PremiumPaymentTransferInput {
  final String targetMembershipId;
  final String targetPeriodYYYYMM;
  final String reason;

  const PremiumPaymentTransferInput({
    required this.targetMembershipId,
    required this.targetPeriodYYYYMM,
    required this.reason,
  });
}

class TransferPremiumPaymentDialog extends StatefulWidget {
  final String currentMembershipId;
  final String sourcePeriodYYYYMM;
  final int amountCents;

  const TransferPremiumPaymentDialog({
    super.key,
    required this.currentMembershipId,
    required this.sourcePeriodYYYYMM,
    required this.amountCents,
  });

  @override
  State<TransferPremiumPaymentDialog> createState() =>
      _TransferPremiumPaymentDialogState();
}

class _TransferPremiumPaymentDialogState
    extends State<TransferPremiumPaymentDialog> {
  final _searchController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _searching = false;
  bool _loadingPremiums = false;
  String? _error;
  Membership? _selectedMembership;
  List<Membership> _results = const [];
  List<Map<String, dynamic>> _periods = const [];
  String? _selectedPeriod;

  @override
  void dispose() {
    _searchController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter a membership number, member name or identity number.');
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _selectedMembership = null;
      _periods = const [];
      _selectedPeriod = null;
    });
    try {
      final page = await MembershipService().getMemberships(
        query: query,
        page: 0,
        size: 12,
      );
      if (!mounted) return;
      setState(() {
        _results = page.content
            .where((membership) => membership.id != widget.currentMembershipId)
            .toList();
        if (_results.isEmpty) {
          _error = 'No other membership matched the search.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectMembership(Membership membership) async {
    setState(() {
      _selectedMembership = membership;
      _loadingPremiums = true;
      _error = null;
      _periods = const [];
      _selectedPeriod = null;
    });
    try {
      final unpaid = await MembershipService().getUnpaidPremiums(membership.id);
      final eligible = unpaid.where((premium) {
        final balance = _asInt(premium['balanceCents']);
        return balance >= widget.amountCents;
      }).toList()
        ..sort((a, b) => _period(a).compareTo(_period(b)));
      if (!mounted) return;
      setState(() {
        _periods = eligible;
        if (eligible.any((premium) => _period(premium) == widget.sourcePeriodYYYYMM)) {
          _selectedPeriod = widget.sourcePeriodYYYYMM;
        } else if (eligible.isNotEmpty) {
          _selectedPeriod = _period(eligible.first);
        } else {
          _error = 'This membership has no outstanding premium month with enough balance for the full payment.';
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingPremiums = false);
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _period(Map<String, dynamic> premium) =>
      (premium['periodYYYYMM'] ?? premium['membershipPeriod'] ?? '').toString();

  String _periodLabel(String period) {
    if (period.length != 6) return period;
    final year = int.tryParse(period.substring(0, 4));
    final month = int.tryParse(period.substring(4, 6));
    if (year == null || month == null || month < 1 || month > 12) return period;
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }

  String _membershipSubtitle(Membership membership) {
    final parts = <String>[
      if (membership.memberName.trim().isNotEmpty) membership.memberName.trim(),
      if (membership.memberIdentityNumber.trim().isNotEmpty)
        membership.memberIdentityNumber.trim(),
      if (membership.status.trim().isNotEmpty) membership.status.trim(),
    ];
    return parts.join(' • ');
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (_selectedMembership == null || _selectedPeriod == null) {
      setState(() => _error = 'Select the destination membership and premium month.');
      return;
    }
    if (reason.isEmpty) {
      setState(() => _error = 'Enter a reason for the transfer.');
      return;
    }
    Navigator.pop(
      context,
      PremiumPaymentTransferInput(
        targetMembershipId: _selectedMembership!.id,
        targetPeriodYYYYMM: _selectedPeriod!,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.amountCents / 100.0;
    return AlertDialog(
      title: const Text('Transfer premium payment'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reassign the existing manual payment of R ${amount.toStringAsFixed(2)} to the correct membership. The original receipt and cash-up trail are retained.',
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        labelText: 'Search destination membership',
                        hintText: 'Membership no, member name or identity no',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('SEARCH'),
                  ),
                ],
              ),
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 190),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final membership = _results[index];
                      final selected = _selectedMembership?.id == membership.id;
                      return ListTile(
                        selected: selected,
                        leading: Icon(selected
                            ? Icons.check_circle
                            : Icons.card_membership_outlined),
                        title: Text(membership.membershipNo),
                        subtitle: Text(_membershipSubtitle(membership)),
                        onTap: () => _selectMembership(membership),
                      );
                    },
                  ),
                ),
              ],
              if (_selectedMembership != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPeriod,
                  decoration: const InputDecoration(
                    labelText: 'Destination premium month',
                    border: OutlineInputBorder(),
                  ),
                  items: _periods.map((premium) {
                    final period = _period(premium);
                    final balance = _asInt(premium['balanceCents']) / 100.0;
                    return DropdownMenuItem(
                      value: period,
                      child: Text(
                        '${_periodLabel(period)} • Balance R ${balance.toStringAsFixed(2)}',
                      ),
                    );
                  }).toList(),
                  onChanged: _loadingPremiums
                      ? null
                      : (value) => setState(() => _selectedPeriod = value),
                ),
                if (_loadingPremiums) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for transfer *',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton.icon(
          onPressed: _loadingPremiums ? null : _submit,
          icon: const Icon(Icons.swap_horiz),
          label: const Text('TRANSFER PAYMENT'),
        ),
      ],
    );
  }
}
