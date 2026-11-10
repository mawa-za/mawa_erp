import 'package:flutter/material.dart';
import '../bank_transaction_service.dart';
import '../../../core/utils/app_date_utils.dart';

/// Shared bank deposit lookup for cashier deposits and ERP EFT payment forms.
class BankDepositIdField extends StatefulWidget {
  final TextEditingController controller;
  final bool? isRequired;
  const BankDepositIdField({super.key, required this.controller, this.isRequired});

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
    final selected = await showDialog<String>(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, update) {
        Future<void> search() async {
          update(() { loading = true; error = null; });
          try {
            final page = await BankTransactionService().search(search: searchController.text, creditsOnly: true);
            if (context.mounted) update(() => results = page.content);
          } catch (e) {
            if (context.mounted) update(() => error = e.toString());
          } finally {
            if (context.mounted) update(() => loading = false);
          }
        }
        return AlertDialog(
          title: const Text('Find bank Deposit ID'),
          content: SizedBox(width: 650, height: 410, child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: searchController, onSubmitted: (_) => search(),
                decoration: const InputDecoration(labelText: 'Deposit ID, bank reference or account'))),
              IconButton(onPressed: loading ? null : search, icon: const Icon(Icons.search), tooltip: 'Search'),
            ]),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
            Expanded(child: ListView.builder(itemCount: results.length, itemBuilder: (context, i) {
              final t = results[i];
              return ListTile(
                enabled: t.availableCents > 0,
                title: Text('${t.depositId}  •  R ${(t.amountCents / 100).toStringAsFixed(2)}'),
                subtitle: Text('${AppDateUtils.displayDate(t.date)}  •  ${t.reference}  •  Available R ${(t.availableCents / 100).toStringAsFixed(2)}'),
                trailing: Text(t.status),
                onTap: t.availableCents > 0 ? () => Navigator.pop(context, t.depositId) : null,
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
    textCapitalization: TextCapitalization.characters,
    decoration: InputDecoration(labelText: 'Bank Deposit ID${_isRequired ? ' *' : ''}',
      hintText: 'DEP-00000123', helperText: _policyError ?? (_policyLoading && widget.isRequired == null
          ? 'Loading bank deposit policy...' : _isRequired
            ? 'Select an imported credit from Bank Transactions'
            : 'Optional during transition. Leave blank to verify later.'),
      suffixIcon: IconButton(onPressed: _lookup, icon: const Icon(Icons.search), tooltip: 'Search bank transactions')),
    validator: (value) {
      if (!_isRequired && (value == null || value.trim().isEmpty)) return null;
      return BankTransactionService.depositIdAccepted(value, isRequired: _isRequired)
          ? null : 'Select a valid bank Deposit ID';
    },
  );
}
