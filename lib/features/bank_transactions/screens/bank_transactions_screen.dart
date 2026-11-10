import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bank_transaction_service.dart';
import '../../../core/utils/app_date_utils.dart';
import 'pending_bank_verification_screen.dart';

class BankTransactionsScreen extends StatefulWidget {
  const BankTransactionsScreen({super.key});
  @override State<BankTransactionsScreen> createState() => _BankTransactionsScreenState();
}

class _BankTransactionsScreenState extends State<BankTransactionsScreen> {
  final _service = BankTransactionService();
  final _search = TextEditingController();
  final _amount = TextEditingController();
  List<BankTransaction> _transactions = [];
  bool _loading = false;
  bool _last = true;
  bool _creditsOnly = false;
  int _page = 0;
  DateTime? _from;
  DateTime? _to;
  String? _error;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _search.dispose(); _amount.dispose(); super.dispose(); }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final enteredAmount = double.tryParse(_amount.text.trim());
      final result = await _service.search(search: _search.text, creditsOnly: _creditsOnly,
        amountCents: enteredAmount == null ? null : (enteredAmount * 100).round(),
        fromDate: _from, toDate: _to, page: more ? _page + 1 : 0);
      if (!mounted) return;
      setState(() {
        _page = more ? _page + 1 : 0;
        _transactions = more ? [..._transactions, ...result.content] : result.content;
        _last = result.last;
      });
    } catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(context: context, initialDate: (start ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (picked != null) { setState(() { if (start) { _from = picked; } else { _to = picked; } }); _load(); }
  }

  Future<void> _showAllocations(BankTransaction item) async {
    try {
      final allocations = await _service.allocations(item.depositId);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text('Deposit ${item.depositId}'),
        content: SizedBox(width: 540, height: 320,
          child: allocations.isEmpty ? const Center(child: Text('No payments or cashups linked yet.'))
            : ListView(children: allocations.map((a) => ListTile(
              leading: Icon(a['releasedAt'] == null ? Icons.link : Icons.link_off),
              title: Text('${a['type']}  •  R ${((a['amountCents'] as num? ?? 0) / 100).toStringAsFixed(2)}'),
              subtitle: Text('Record ${a['objectId']}\nBy ${a['createdBy'] ?? '-'} • ${AppDateUtils.displayDateTime(a['createdAt'], fallback: '-')}'),
              trailing: a['releasedAt'] == null ? const Text('Active') : const Text('Released'),
            )).toList())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bank Transactions'), actions: [
      TextButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const PendingBankVerificationScreen())),
        icon: const Icon(Icons.rule_folder_outlined), label: const Text('Pending Bank Verification')),
      IconButton(onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
    ]),
    body: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        SizedBox(width: 290, child: TextField(controller: _search, onSubmitted: (_) => _load(),
          decoration: const InputDecoration(labelText: 'Deposit ID / reference / account', prefixIcon: Icon(Icons.search)))),
        SizedBox(width: 140, child: TextField(controller: _amount, onSubmitted: (_) => _load(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Exact amount (R)'))),
        OutlinedButton(onPressed: () => _pickDate(true), child: Text(_from == null ? 'From date' : AppDateUtils.displayDate(_from))),
        OutlinedButton(onPressed: () => _pickDate(false), child: Text(_to == null ? 'To date' : AppDateUtils.displayDate(_to))),
        FilterChip(label: const Text('Credits only'), selected: _creditsOnly, onSelected: (value) { setState(() => _creditsOnly = value); _load(); }),
        FilledButton.icon(onPressed: _loading ? null : () => _load(), icon: const Icon(Icons.search), label: const Text('Search')),
      ]),
      const SizedBox(height: 14),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
      Expanded(child: _transactions.isEmpty
        ? Center(child: Text(_loading ? 'Loading transactions...' : 'No matching bank transactions.'))
        : ListView.builder(itemCount: _transactions.length, itemBuilder: (context, index) {
          final item = _transactions[index];
          return Card(child: ListTile(
            onTap: () => _showAllocations(item),
            leading: Icon(item.amountCents >= 0 ? Icons.south_west : Icons.north_east,
              color: item.amountCents >= 0 ? Colors.green : Colors.red),
            title: Text('${item.depositId}   •   R ${(item.amountCents / 100).toStringAsFixed(2)}'),
            subtitle: Text(
              '${AppDateUtils.displayDate(item.date)}  |  ${item.reference}\nAccount ${item.accountNumber}  |  ${item.status}  |  Available R ${(item.availableCents / 100).toStringAsFixed(2)}',
              maxLines: 3,
            ),
            trailing: IconButton(icon: const Icon(Icons.copy), tooltip: 'Copy Deposit ID',
              onPressed: item.amountCents <= 0 ? null : () async {
              await Clipboard.setData(ClipboardData(text: item.depositId));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.depositId} copied')));
            }),
          ));
        })),
      if (!_last) OutlinedButton(onPressed: _loading ? null : () => _load(more: true), child: const Text('Load more')),
    ])),
  );
}
