import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import '../bank_transaction_service.dart';
import '../widgets/bank_deposit_id_field.dart';

/// Reconciliation worklist: it never changes a payment or cashup approval/posting.
/// Allocation is only committed by the backend after amount and availability checks.
class PendingBankVerificationScreen extends StatefulWidget {
  const PendingBankVerificationScreen({super.key});
  @override
  State<PendingBankVerificationScreen> createState() => _PendingBankVerificationScreenState();
}

class _PendingBankVerificationScreenState extends State<PendingBankVerificationScreen> {
  final _service = BankTransactionService();
  final _search = TextEditingController();
  String _type = 'PAYMENT_BATCH';
  List<Map<String, dynamic>> _records = [];
  bool _loading = false;
  bool _last = true;
  bool _canReconcile = false;
  int _page = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPermissions() async {
    try {
      final allowed = await _service.canReconcile();
      if (mounted) setState(() => _canReconcile = allowed);
    } catch (_) {
      if (mounted) setState(() => _canReconcile = false);
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final next = more ? _page + 1 : 0;
      final result = await _service.pendingVerification(type: _type, search: _search.text, page: next);
      if (!mounted) return;
      setState(() {
        _page = next;
        _last = result['last'] == true;
        final rows = (result['content'] as List? ?? [])
          .whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
        _records = more ? [..._records, ...rows] : rows;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _link(Map<String, dynamic> record) async {
    if (!_canReconcile) return;
    final depositId = TextEditingController();
    String? validation;
    bool submitting = false;
    final id = record['objectId']?.toString() ?? '';
    final docNo = record['documentNo']?.toString() ?? id;
    final amountCents = (record['amountCents'] as num?)?.toInt() ?? 0;
    final date = AppDateUtils.parse(record['date']);
    // Suggestions are advisory only; the operator must confirm the actual bank credit.
    final suggestions = _service.search(creditsOnly: true, amountCents: amountCents,
      fromDate: date?.subtract(const Duration(days: 7)),
      toDate: date?.add(const Duration(days: 7)));
    final linked = await showDialog<bool>(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (dialogContext, update) => AlertDialog(
        title: const Text('Verify historical bank deposit'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Record $docNo — R ${(amountCents / 100).toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          const Text('Select an imported bank credit. Confirm the payer, date, reference and amount before linking. This does not change the payment or cashup approval.'),
          const SizedBox(height: 14),
          BankDepositIdField(controller: depositId, isRequired: true),
          const SizedBox(height: 10),
          const Align(alignment: Alignment.centerLeft, child: Text('Suggested bank credits (same amount, ±7 days):')),
          SizedBox(height: 170, child: FutureBuilder<BankTransactionsPage>(future: suggestions,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) return const Text('Suggestions unavailable; use Find bank Deposit ID above.');
              final options = snapshot.data?.content.where((e) => e.availableCents >= amountCents).toList() ?? [];
              if (options.isEmpty) return const Center(child: Text('No exact-amount candidates. Search manually.'));
              return ListView(children: options.map((bank) => ListTile(
                dense: true,
                title: Text('${bank.depositId}  •  ${bank.reference}'),
                subtitle: Text('${AppDateUtils.displayDate(bank.date)}  •  Account ${bank.accountNumber}'),
                onTap: () => update(() => depositId.text = bank.depositId),
              )).toList());
            })),
          if (validation != null) Text(validation!, style: const TextStyle(color: Colors.red)),
        ])),
        actions: [
          TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel')),
          FilledButton(onPressed: submitting ? null : () async {
            if (!BankTransactionService.depositIdAccepted(depositId.text, isRequired: true)) {
              update(() => validation = 'Select a valid Deposit ID');
              return;
            }
            update(() { submitting = true; validation = null; });
            try {
              await _service.reconcile(type: _type, objectId: id, depositId: depositId.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (e) {
              if (dialogContext.mounted) update(() => validation = e.toString());
            } finally {
              if (dialogContext.mounted) update(() => submitting = false);
            }
          }, child: const Text('Confirm & Link')),
        ],
      ));
    });
    depositId.dispose();
    if (linked == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Bank transaction linked; previous posting and approval unchanged.')));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pending Bank Verification'), actions: [
      IconButton(onPressed: _loading ? null : () => _load(),
        icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
    ]),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      const Align(alignment: Alignment.centerLeft, child: Text(
        'EFT receipts and cashup deposits captured without Deposit IDs. '
        'Verification is tracked separately from financial approval.')),
      const SizedBox(height: 12),
      Wrap(spacing: 12, runSpacing: 12, children: [
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'PAYMENT_BATCH', label: Text('EFT Payments')),
          ButtonSegment(value: 'CASHUP_DEPOSIT', label: Text('Cashup Deposits')),
        ], selected: {_type}, onSelectionChanged: (selected) {
          setState(() => _type = selected.first);
          _load();
        }),
        SizedBox(width: 320, child: TextField(controller: _search,
          onSubmitted: (_) => _load(),
          decoration: const InputDecoration(labelText: 'Search payment number / membership / reference',
            prefixIcon: Icon(Icons.search)))),
        FilledButton.icon(onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.search), label: const Text('Search')),
      ]),
      if (!_canReconcile)
        const Align(alignment: Alignment.centerLeft, child: Text(
          'You can view pending records. To link funds, ask an administrator for the Reconcile bank deposits permission.')),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      Expanded(child: _records.isEmpty
        ? Center(child: Text(_loading ? 'Loading...' : 'No pending records match these filters.'))
        : ListView.builder(itemCount: _records.length, itemBuilder: (context, i) {
          final item = _records[i];
          final cents = (item['amountCents'] as num?)?.toInt() ?? 0;
          return Card(child: ListTile(
            title: Text('${item['documentNo'] ?? ''}  •  R ${(cents / 100).toStringAsFixed(2)}'),
            subtitle: Text('${AppDateUtils.displayDate(item['date'])}  |  ${item['reference'] ?? ''}\n${item['status'] == 'VERIFICATION_EXCEPTION' ? 'Verification exception: ${item['verificationNote'] ?? 'Review and retry'}' : 'Pending bank verification'}'),
            isThreeLine: true,
            trailing: OutlinedButton.icon(onPressed: _canReconcile ? () => _link(item) : null,
              icon: const Icon(Icons.link), label: const Text('Link Deposit ID')),
          ));
        })),
      if (!_last) OutlinedButton(onPressed: _loading ? null : () => _load(more: true),
        child: const Text('Load more')),
    ])),
  );
}
