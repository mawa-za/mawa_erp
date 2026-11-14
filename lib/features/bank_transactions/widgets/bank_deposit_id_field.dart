import 'package:flutter/material.dart';
import '../bank_transaction_service.dart';
import '../../../core/utils/app_date_utils.dart';

/// Shared bank deposit lookup for cashier deposits and ERP EFT payment forms.
/// A Deposit ID must be selected from a matched, available bank credit;
/// operators cannot paste or type arbitrary IDs into payment forms.
class BankDepositIdField extends StatefulWidget {
  final TextEditingController controller;
  final bool? isRequired;
  /// Injectable solely to permit deterministic widget tests without network I/O.
  final Future<BankTransactionsPage> Function(String query)? lookupCredits;
  const BankDepositIdField({super.key, required this.controller, this.isRequired,
    this.lookupCredits});

  @override
  State<BankDepositIdField> createState() => _BankDepositIdFieldState();
}

class _BankDepositIdFieldState extends State<BankDepositIdField> {
  bool _policyRequired = true;
  bool _policyLoading = true;
  String? _policyError;

  bool get _isRequired => widget.isRequired ?? _policyRequired;

  @override
  void initState() {
    super.initState();
    if (widget.isRequired == null) _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    try {
      final requiredNow = await BankTransactionService().requireDepositIdNow();
      if (mounted) setState(() { _policyRequired = requiredNow; _policyLoading = false; });
    } catch (_) {
      if (mounted) setState(() {
        // Fail closed in the UI if the backend policy cannot be retrieved.
        _policyRequired = true;
        _policyLoading = false;
        _policyError = 'Could not load bank verification policy. Retry before capturing payment.';
      });
    }
  }

  Future<void> _lookup() async {
    final searchController = TextEditingController();
    List<BankTransaction> results = [];
    String? error;
    bool loading = false;
    bool searched = false;
    // Ignore a delayed response if the user has edited the search query.
    int generation = 0;
    final selected = await showDialog<String>(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, update) {
        final canSearch = BankTransactionService.canSearchDepositCredits(searchController.text);
        Future<void> search() async {
          final query = searchController.text.trim();
          if (!BankTransactionService.canSearchDepositCredits(query) || loading) return;
          final request = ++generation;
          update(() { loading = true; error = null; results = []; searched = false; });
          try {
            final page = await (widget.lookupCredits?.call(query)
                ?? BankTransactionService().lookupAvailableCredits(query));
            if (context.mounted && request == generation) update(() {
              results = page.content.where((t) => t.isCredit
                && t.depositId != null && t.availableCents > 0).toList();
              searched = true;
            });
          } catch (e) {
            if (context.mounted && request == generation) update(() {
              error = e.toString();
              searched = true;
            });
          } finally {
            if (context.mounted && request == generation) update(() => loading = false);
          }
        }
        return AlertDialog(
          title: const Text('Find bank Deposit ID'),
          content: SizedBox(width: 650, height: 410, child: Column(children: [
            Row(children: [
              Expanded(child: TextField(
                controller: searchController,
                autofocus: true,
                onChanged: (_) {
                  ++generation;
                  update(() { results = []; error = null; searched = false; loading = false; });
                },
                onSubmitted: (_) => search(),
                decoration: const InputDecoration(
                  labelText: 'Deposit ID, bank reference or account',
                  helperText: 'Enter at least 5 characters to search',
                ),
              )),
              IconButton(
                onPressed: canSearch && !loading ? search : null,
                icon: const Icon(Icons.search), tooltip: 'Search available credits',
              ),
            ]),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            if (!canSearch) const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Type at least 5 characters to find matching bank credits.'),
            ),
            if (canSearch && searched && results.isEmpty && error == null)
              const Padding(padding: EdgeInsets.all(12), child: Text('No matching available credits found.')),
            Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (context, i) {
              final t = results[i];
              return ListTile(
                title: Text('${t.displayId}  •  R ${(t.amountCents / 100).toStringAsFixed(2)}'),
                subtitle: Text('${AppDateUtils.displayDate(t.date)}  •  ${t.reference}  •  Available R ${(t.availableCents / 100).toStringAsFixed(2)}'),
                trailing: Text(t.status),
                onTap: () => Navigator.pop(context, t.depositId!),
              );
            })),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
        );
      });
    });
    searchController.dispose();
    if (selected != null && mounted) widget.controller.text = selected;
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    readOnly: true,
    showCursor: false,
    enableInteractiveSelection: false,
    onTap: _lookup,
    decoration: InputDecoration(labelText: 'Bank Deposit ID${_isRequired ? ' *' : ''}',
      hintText: 'Select a bank credit', helperText: _policyError ?? (_policyLoading && widget.isRequired == null
          ? 'Loading bank deposit policy...' : _isRequired
            ? 'Search and select an imported bank credit (minimum 5 characters)'
            : 'Optional during transition. Leave blank to verify later.'),
      suffixIcon: IconButton(onPressed: _lookup, icon: const Icon(Icons.search),
        tooltip: 'Find bank credit')),
    validator: (value) {
      if (!_isRequired && (value == null || value.trim().isEmpty)) return null;
      return BankTransactionService.depositIdAccepted(value, isRequired: _isRequired)
          ? null : 'Select a valid bank Deposit ID';
    },
  );
}
