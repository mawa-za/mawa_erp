import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/files/download_bytes.dart';
import '../../invoicing/screens/invoice_detail_screen.dart';
import '../../partners/models/partner.dart';
import '../../partners/screens/partner_create_screen.dart';
import '../../settings/services/pos_printing_service.dart';
import '../services/layby_service.dart';

class LaybyManagementScreen extends StatefulWidget {
  const LaybyManagementScreen({super.key, this.initialLaybyId});

  final String? initialLaybyId;

  @override
  State<LaybyManagementScreen> createState() => _LaybyManagementScreenState();
}

class _LaybyManagementScreenState extends State<LaybyManagementScreen> {
  final LaybyService _service = LaybyService();
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String _status = '';
  String? _error;
  bool _initialLaybyOpened = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _service.list(status: _status, query: _search.text);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
      final initialId = widget.initialLaybyId?.trim();
      if (!_initialLaybyOpened && initialId != null && initialId.isNotEmpty) {
        _initialLaybyOpened = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _open({'id': initialId});
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _create() async {
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LaybyCreateDialog(service: _service),
    );
    if (created == null || !mounted) return;
    await _load();
    await _open(created);
  }

  Future<void> _open(Map<String, dynamic> row) async {
    final id = _text(row['id']);
    if (id.isEmpty) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _LaybyDetailDialog(service: _service, laybyId: id),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Laybys')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 420,
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      labelText: 'Search layby, customer, ID/contact, product or sales order',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('All statuses')),
                      DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                      DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                      DropdownMenuItem(value: 'IN_ARREARS', child: Text('In arrears')),
                      DropdownMenuItem(value: 'PAID_UP', child: Text('Paid up')),
                      DropdownMenuItem(value: 'CANCELLATION_PENDING', child: Text('Cancellation pending')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                      DropdownMenuItem(value: 'FULFILLED', child: Text('Fulfilled')),
                    ],
                    onChanged: (value) {
                      setState(() => _status = value ?? '');
                      _load();
                    },
                  ),
                ),
                OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
                FilledButton.icon(onPressed: _create, icon: const Icon(Icons.add_shopping_cart), label: const Text('New Layby')),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(child: Text('No laybys found.'))
                      : Card(
                          clipBehavior: Clip.antiAlias,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                showCheckboxColumn: false,
                                columns: const [
                                  DataColumn(label: Text('Layby')),
                                  DataColumn(label: Text('Customer')),
                                  DataColumn(label: Text('Sales Order')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Total'), numeric: true),
                                  DataColumn(label: Text('Paid'), numeric: true),
                                  DataColumn(label: Text('Outstanding'), numeric: true),
                                  DataColumn(label: Text('Next Due')),
                                  DataColumn(label: Text('Attention')),
                                  DataColumn(label: Text('Created')),
                                ],
                                rows: _rows.map((row) => DataRow(
                                  onSelectChanged: (_) => _open(row),
                                  cells: [
                                    DataCell(Text(_text(row['layby_no']), style: const TextStyle(fontWeight: FontWeight.w700))),
                                    DataCell(Text(_text(row['customer_name']))),
                                    DataCell(Text(_text(row['sales_order_no']))),
                                    DataCell(_StatusChip(_text(row['status']))),
                                    DataCell(Text(_money(row['total_cents']))),
                                    DataCell(Text(_money(row['paid_cents']))),
                                    DataCell(Text(_money(row['balance_cents']))),
                                    DataCell(Text(_date(row['next_due_date']))),
                                    DataCell(Text(
                                      _bool(row['default_eligible'])
                                          ? 'Default eligible'
                                          : (_int(row['overdue_cents'], 0) > 0 ? 'Payment overdue' : ''),
                                    )),
                                    DataCell(Text(_date(row['created_at']))),
                                  ],
                                )).toList(),
                              ),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LaybyDetailDialog extends StatefulWidget {
  const _LaybyDetailDialog({required this.service, required this.laybyId});
  final LaybyService service;
  final String laybyId;

  @override
  State<_LaybyDetailDialog> createState() => _LaybyDetailDialogState();
}

class _LaybyDetailDialogState extends State<_LaybyDetailDialog> {
  Map<String, dynamic>? _layby;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final layby = await widget.service.get(widget.laybyId);
      if (!mounted) return;
      setState(() {
        _layby = layby;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _payment() async {
    final amount = TextEditingController();
    final notes = TextEditingController();
    String method = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Record Layby Payment'),
        content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Outstanding: ${_money(_layby?['balance_cents'])}'),
          const SizedBox(height: 12),
          TextField(controller: amount, autofocus: true, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R ', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: '', child: Text('Select payment method')),
              DropdownMenuItem(value: 'CASH', child: Text('CASH')),
              DropdownMenuItem(value: 'CARD', child: Text('CARD')),
              DropdownMenuItem(value: 'EFT', child: Text('EFT')),
            ],
            onChanged: (v) => setDialogState(() => method = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Record Payment')),
        ],
      )),
    );
    if (accepted != true) return;
    final value = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
    if (value <= 0 || method.isEmpty) {
      if (mounted) {
        setState(() => _error = 'Enter a valid payment amount and select a payment method.');
      }
      return;
    }
    await _run(() async {
      await widget.service.capturePayment(widget.laybyId, {
        'amountCents': (value * 100).round(),
        'paymentMethod': method,
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      });
    });
  }

  Future<void> _cancel() async {
    final reason = TextEditingController();
    String code = 'OTHER';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Cancel Layby'),
        content: SizedBox(width: 460, child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            value: code,
            decoration: const InputDecoration(labelText: 'Reason category', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              DropdownMenuItem(value: 'DEATH', child: Text('Death')),
              DropdownMenuItem(value: 'HOSPITALISATION', child: Text('Hospitalisation')),
            ],
            onChanged: (v) => setDialogState(() => code = v ?? 'OTHER'),
          ),
          const SizedBox(height: 12),
          TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Cancellation reason', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Layby')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Request Cancellation')),
        ],
      )),
    );
    if (accepted != true || reason.text.trim().isEmpty) return;
    await _run(() async => widget.service.cancel(widget.laybyId, {'reasonCode': code, 'reason': reason.text.trim()}));
  }

  Future<void> _requestRefundApproval() async {
    await _run(() async => widget.service.requestRefundApproval(widget.laybyId));
  }

  Future<void> _refundPaid() async {
    final reference = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Refund Paid'),
        content: TextField(controller: reference, decoration: const InputDecoration(labelText: 'Payment reference', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Mark Paid')),
        ],
      ),
    );
    if (accepted != true) return;
    if (reference.text.trim().isEmpty) {
      if (mounted) setState(() => _error = 'Payment reference is required when marking a refund paid.');
      return;
    }
    await _run(() async => widget.service.markRefundPaid(widget.laybyId, paymentReference: reference.text));
  }

  Future<void> _fulfil() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Release Goods / Complete Layby'),
        content: const SizedBox(
          width: 460,
          child: Text(
            'This will issue the stock from the locations reserved for this layby and generate the final paid invoice.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Release & Complete')),
        ],
      ),
    );
    if (accepted != true) return;
    await _run(() async => widget.service.fulfil(widget.laybyId));
  }

  Future<void> _openFinalInvoice() async {
    final invoiceId = _text(_layby?['final_invoice_id']);
    if (invoiceId.isEmpty || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: invoiceId)),
    );
  }

  Future<void> _pdf(bool statement) async {
    try {
      final bytes = statement ? await widget.service.statementPdf(widget.laybyId) : await widget.service.agreementPdf(widget.laybyId);
      await downloadBytes(
        bytes: bytes,
        fileName: '${_text(_layby?['layby_no'])}-${statement ? 'statement' : 'agreement'}.pdf',
        mimeType: 'application/pdf',
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _text(_layby?['status']).toUpperCase();
    final refund = _layby?['refund'] is Map ? Map<String, dynamic>.from(_layby!['refund'] as Map) : <String, dynamic>{};
    final refundStatus = _text(refund['status']).toUpperCase();
    return Dialog(
      child: SizedBox(
        width: 1120,
        height: 760,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 16, 12),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_text(_layby?['layby_no']), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${_text(_layby?['customer_name'])} • ${_text(_layby?['sales_order_no'])}'),
                      ])),
                      _StatusChip(status),
                      const SizedBox(width: 8),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ]),
                  ),
                  if (_error != null)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(onPressed: _working ? null : () => _pdf(false), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Agreement')),
                      OutlinedButton.icon(onPressed: _working ? null : () => _pdf(true), icon: const Icon(Icons.receipt_long_outlined), label: const Text('Statement')),
                      if (status == 'DRAFT') FilledButton.tonalIcon(onPressed: _working ? null : () => _run(() async => widget.service.activate(widget.laybyId)), icon: const Icon(Icons.play_arrow), label: const Text('Activate')),
                      if (['DRAFT', 'ACTIVE', 'IN_ARREARS'].contains(status)) FilledButton.icon(onPressed: _working ? null : _payment, icon: const Icon(Icons.payments_outlined), label: const Text('Record Payment')),
                      if (['DRAFT', 'ACTIVE', 'IN_ARREARS', 'PAID_UP'].contains(status)) OutlinedButton.icon(onPressed: _working ? null : _cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel Layby')),
                      if (status == 'CANCELLATION_PENDING')
                        const Chip(
                          avatar: Icon(Icons.approval_outlined, size: 18),
                          label: Text('Cancellation awaiting Approval Inbox'),
                        ),
                      if (status == 'PAID_UP') FilledButton.icon(onPressed: _working ? null : _fulfil, icon: const Icon(Icons.local_shipping_outlined), label: const Text('Release Goods / Complete')),
                      if (_text(_layby?['final_invoice_id']).isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: _working ? null : _openFinalInvoice,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('View Final Invoice'),
                        ),
                      if (refundStatus == 'PENDING_APPROVAL')
                        const Chip(
                          avatar: Icon(Icons.approval_outlined, size: 18),
                          label: Text('Refund awaiting Approval Inbox'),
                        ),
                      if (refundStatus == 'REJECTED')
                        OutlinedButton.icon(
                          onPressed: _working ? null : _requestRefundApproval,
                          icon: const Icon(Icons.refresh_outlined),
                          label: const Text('Resubmit Refund Approval'),
                        ),
                      if (refundStatus == 'APPROVED') FilledButton.tonal(onPressed: _working ? null : _refundPaid, child: const Text('Mark Refund Paid')),
                    ]),
                  ),
                  const Divider(height: 1),
                  Expanded(child: _detailBody()),
                ],
              ),
      ),
    );
  }

  Widget _detailBody() {
    final installments = _maps(_layby?['installments']);
    final payments = _maps(_layby?['payments']);
    final history = _maps(_layby?['statusHistory']);
    final salesOrder = _layby?['salesOrder'] is Map ? Map<String, dynamic>.from(_layby!['salesOrder'] as Map) : <String, dynamic>{};
    final lines = _maps(salesOrder['lines']);
    final refund = _layby?['refund'] is Map ? Map<String, dynamic>.from(_layby!['refund'] as Map) : <String, dynamic>{};

    return DefaultTabController(
      length: 5,
      child: Column(children: [
        const TabBar(isScrollable: true, tabs: [
          Tab(text: 'Overview'), Tab(text: 'Items'), Tab(text: 'Payment Schedule'), Tab(text: 'Payments'), Tab(text: 'Audit / Refund'),
        ]),
        Expanded(child: TabBarView(children: [
          ListView(padding: const EdgeInsets.all(24), children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              _metric('Agreement Total', _money(_layby?['total_cents'])),
              _metric('Paid', _money(_layby?['paid_cents'])),
              _metric('Outstanding', _money(_layby?['balance_cents'])),
              _metric('Required Deposit', _money(_layby?['deposit_required_cents'])),
              _metric('Frequency', _text(_layby?['payment_frequency'])),
              _metric('Completion Date', _date(_layby?['expected_completion_date'])),
            ]),
            const SizedBox(height: 20),
            _info('Customer', _text(_layby?['customer_name'])),
            _info('Customer number', _text(_layby?['customer_no'])),
            _info('Sales order', _text(_layby?['sales_order_no'])),
            _info('Terms version', _text(_layby?['terms_version'])),
            _info('Terms accepted', '${_text(_layby?['terms_accepted_by'])} • ${_dateTime(_layby?['terms_accepted_at'])}'),
            if (_text(_layby?['cancellation_approval_request_id']).isNotEmpty) _info('Cancellation approval request', _text(_layby?['cancellation_approval_request_id'])),
            if (_text(_layby?['final_invoice_id']).isNotEmpty) _info('Final invoice ID', _text(_layby?['final_invoice_id'])),
          ]),
          _simpleTable(lines, const ['product_code', 'product_description', 'quantity', 'unit_price', 'line_total', 'reserved_qty', 'issued_qty']),
          _simpleTable(installments, const ['installment_no', 'due_date', 'amount_cents', 'paid_cents', 'balance_cents', 'status'], moneyKeys: const {'amount_cents', 'paid_cents', 'balance_cents'}),
          _paymentTable(payments),
          ListView(padding: const EdgeInsets.all(24), children: [
            if (refund.isNotEmpty) ...[
              Text('Refund', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _info('Status', _text(refund['status'])),
              _info('Gross paid', _money(refund['gross_paid_cents'])),
              _info('Cancellation penalty', _money(refund['penalty_cents'])),
              _info('Refund amount', _money(refund['refund_amount_cents'])),
              if (_text(refund['approval_request_id']).isNotEmpty) _info('Approval request', _text(refund['approval_request_id'])),
              _info('Payment reference', _text(refund['payment_reference'])),
              const Divider(height: 28),
            ],
            Text('Status history', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...history.map((h) => ListTile(
              dense: true,
              leading: const Icon(Icons.history),
              title: Text('${_text(h['previous_status'])} → ${_text(h['new_status'])}'),
              subtitle: Text('${_text(h['reason'])}\n${_dateTime(h['changed_at'])} • ${_text(h['changed_by'])}'),
            )),
          ]),
        ])),
      ]),
    );
  }

  Widget _metric(String label, String value) => Container(
    width: 190,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), const SizedBox(height: 6), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))]),
  );

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 180, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(value.isEmpty ? '-' : value))]),
  );

  Future<void> _reprintReceipt(Map<String, dynamic> payment) async {
    final receiptId = _text(payment['receipt_id']);
    if (receiptId.isEmpty) return;
    try {
      await PosPrintingService().queueReceipt(receiptId, reprint: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt ${_text(payment['receipt_no'])} queued for reprint.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage('Unable to reprint receipt: $e'))),
      );
    }
  }

  Widget _paymentTable(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const Center(child: Text('No payments recorded.'));
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Receipt No')),
            DataColumn(label: Text('Receipt Date')),
            DataColumn(label: Text('Payment Method')),
            DataColumn(label: Text('Amount')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Action')),
          ],
          rows: rows.map((row) => DataRow(cells: [
            DataCell(Text(_text(row['receipt_no']))),
            DataCell(Text(_dateTime(row['receipt_date']))),
            DataCell(Text(_text(row['payment_method']))),
            DataCell(Text(_money(row['allocated_amount_cents']))),
            DataCell(Text(_text(row['receipt_status']))),
            DataCell(IconButton(
              tooltip: 'Reprint receipt',
              icon: const Icon(Icons.print_outlined),
              onPressed: () => _reprintReceipt(row),
            )),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _simpleTable(List<Map<String, dynamic>> rows, List<String> columns, {Set<String> moneyKeys = const {}}) {
    if (rows.isEmpty) return const Center(child: Text('No records.'));
    return SingleChildScrollView(padding: const EdgeInsets.all(20), scrollDirection: Axis.horizontal, child: SingleChildScrollView(child: DataTable(
      columns: columns.map((c) => DataColumn(label: Text(_label(c)))).toList(),
      rows: rows.map((row) => DataRow(cells: columns.map((c) {
        final value = moneyKeys.contains(c) ? _money(row[c]) : (c.contains('date') ? _date(row[c]) : _text(row[c]));
        return DataCell(Text(value));
      }).toList())).toList(),
    )));
  }
}

class _LaybyCreateDialog extends StatefulWidget {
  const _LaybyCreateDialog({required this.service});
  final LaybyService service;

  @override
  State<_LaybyCreateDialog> createState() => _LaybyCreateDialogState();
}

class _LaybyCreateDialogState extends State<_LaybyCreateDialog> {
  final SearchController _customerSearch = SearchController();
  final List<_LaybyLineDraft> _lines = [_LaybyLineDraft()];
  final TextEditingController _installments = TextEditingController(text: '3');
  final TextEditingController _deposit = TextEditingController();
  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _warehouses = [];
  String? _warehouseId;
  String _frequency = 'MONTHLY';
  bool _depositRequired = false;
  double _minimumDepositPercent = 0;
  double _cancellationPenaltyPercent = 1;
  int _graceBusinessDays = 60;
  int _defaultDurationMonths = 3;
  bool _termsAccepted = false;
  bool _saving = false;
  String? _error;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _customerSearch.dispose();
    _installments.dispose();
    _deposit.dispose();
    for (final line in _lines) line.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final values = await Future.wait([widget.service.configuration(), widget.service.warehouses()]);
      if (!mounted) return;
      final config = values[0] as Map<String, dynamic>;
      final warehouses = values[1] as List<Map<String, dynamic>>;
      setState(() {
        _frequency = _text(config['default_payment_frequency']).isEmpty ? 'MONTHLY' : _text(config['default_payment_frequency']);
        _defaultDurationMonths = _int(config['default_duration_months'], 3);
        _installments.text = '${_defaultInstallmentCount(_frequency)}';
        _warehouses = warehouses;
        if (_warehouses.length == 1) _warehouseId = _text(_warehouses.first['id']);
        _depositRequired = _bool(config['deposit_required']);
        _minimumDepositPercent = _double(config['minimum_deposit_percent']);
        _cancellationPenaltyPercent = _double(config['cancellation_penalty_percent']);
        _graceBusinessDays = _int(config['default_grace_business_days'], 60);
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    }
  }

  Future<void> _createCustomer() async {
    final created = await Navigator.of(context).push<Partner>(MaterialPageRoute(
      builder: (_) => const PartnerCreateScreen(initialRole: 'CUSTOMER', lockInitialRole: true, returnCreatedPartner: true),
    ));
    if (created == null || !mounted) return;
    setState(() {
      _customer = {'id': created.id, 'partnerNo': created.number, 'name1': created.name1, 'name2': created.name2, 'name3': created.name3, 'fullName': created.fullName};
      _customerSearch.text = created.fullName;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_customer == null) throw AppException('Select a customer first.');
      if (!_termsAccepted) throw AppException('Layby terms must be accepted.');
      final validLines = _lines.where((line) => line.productId.isNotEmpty && line.quantity > 0).toList();
      if (validLines.isEmpty) throw AppException('Add at least one product or service.');
      final created = await widget.service.create({
        'customerPartnerId': _text(_customer!['id'] ?? _customer!['partnerId']),
        if (_warehouseId != null && _warehouseId!.isNotEmpty) 'warehouseId': _warehouseId,
        'currency': 'ZAR',
        'paymentFrequency': _frequency,
        'installmentCount': int.tryParse(_installments.text) ?? 3,
        if (_deposit.text.trim().isNotEmpty)
          'depositCents': ((_double(_deposit.text)) * 100).round(),
        'termsAccepted': true,
        'lines': validLines.map((line) => line.toJson()).toList(),
      });
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (mounted) setState(() {
        _saving = false;
        _error = friendlyErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 1000,
        height: 720,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 12, 8),
            child: Row(children: [
              Expanded(child: Text('Create Layby', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
              IconButton(onPressed: _saving ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Align(alignment: Alignment.centerLeft, child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)))),
          Expanded(child: Stepper(
            currentStep: _step,
            type: StepperType.horizontal,
            controlsBuilder: (_, __) => const SizedBox.shrink(),
            steps: [
              Step(title: const Text('Customer'), isActive: _step >= 0, content: _customerStep()),
              Step(title: const Text('Items'), isActive: _step >= 1, content: _itemsStep()),
              Step(title: const Text('Terms'), isActive: _step >= 2, content: _termsStep()),
              Step(title: const Text('Review'), isActive: _step >= 3, content: _reviewStep()),
            ],
          )),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              if (_step > 0) OutlinedButton(onPressed: _saving ? null : () => setState(() => _step--), child: const Text('Back')),
              const Spacer(),
              if (_step < 3) FilledButton(onPressed: _saving ? null : () => setState(() => _step++), child: const Text('Next'))
              else FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check), label: const Text('Create Layby')),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _customerStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Search for the customer before creating a new one. Search supports customer name, contact details and partner number.'),
    const SizedBox(height: 16),
    SearchAnchor(
      searchController: _customerSearch,
      builder: (context, controller) => SearchBar(
        controller: controller,
        hintText: 'Search customer',
        leading: const Icon(Icons.search),
        onTap: () => controller.openView(),
        onChanged: (_) => controller.openView(),
      ),
      suggestionsBuilder: (context, controller) async {
        final q = controller.text.trim();
        if (q.length < 2) return const [ListTile(title: Text('Type at least 2 characters'))];
        final rows = await widget.service.searchCustomers(q);
        final suggestions = rows.take(20).map((p) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(_partnerName(p)),
          subtitle: Text(_text(p['partnerNo'] ?? p['number'])),
          onTap: () => setState(() {
            _customer = p;
            controller.closeView(_partnerName(p));
          }),
        )).toList();
        suggestions.add(ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('Create new customer'), subtitle: const Text('Individual, organisation or group'), onTap: () {
          controller.closeView(q);
          _createCustomer();
        }));
        return suggestions;
      },
    ),
    const SizedBox(height: 16),
    if (_customer != null) Card(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.check)), title: Text(_partnerName(_customer!)), subtitle: Text('Customer no: ${_text(_customer!['partnerNo'] ?? _customer!['number'])}'), trailing: IconButton(onPressed: () => setState(() => _customer = null), icon: const Icon(Icons.clear)))),
  ]);

  Widget _itemsStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    if (_warehouses.isNotEmpty)
      DropdownButtonFormField<String?>(
        value: _warehouseId,
        decoration: const InputDecoration(labelText: 'Warehouse for stock reservation', border: OutlineInputBorder()),
        items: [const DropdownMenuItem<String?>(value: null, child: Text('No warehouse selected')), ..._warehouses.map((w) => DropdownMenuItem<String?>(value: _text(w['id']), child: Text('${_text(w['warehouse_code'])} - ${_text(w['name'])}')))],
        onChanged: (v) => setState(() => _warehouseId = v),
      ),
    const SizedBox(height: 14),
    ...List.generate(_lines.length, (index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _lineEditor(index))),
    Align(alignment: Alignment.centerLeft, child: FilledButton.tonalIcon(onPressed: () => setState(() => _lines.add(_LaybyLineDraft())), icon: const Icon(Icons.add), label: const Text('Add Item'))),
  ]);

  Widget _lineEditor(int index) {
    final line = _lines[index];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [Expanded(child: _productSearch(line)), if (_lines.length > 1) IconButton(onPressed: () => setState(() { final removed = _lines.removeAt(index); removed.dispose(); }), icon: const Icon(Icons.delete_outline))]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 3, child: TextField(controller: line.description, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: line.quantityController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: line.unitPrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Unit price', prefixText: 'R ', border: OutlineInputBorder()))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: line.taxRate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'VAT %', border: OutlineInputBorder()))),
          ]),
        ]),
      ),
    );
  }

  Widget _productSearch(_LaybyLineDraft line) => SearchAnchor(
    searchController: line.productSearch,
    builder: (context, controller) => SearchBar(controller: controller, hintText: line.productCode.isEmpty ? 'Search product or service' : line.productCode, leading: const Icon(Icons.inventory_2_outlined), onTap: () => controller.openView(), onChanged: (_) => controller.openView()),
    suggestionsBuilder: (context, controller) async {
      final products = await widget.service.searchProducts(controller.text.trim());
      if (products.isEmpty) return const [ListTile(title: Text('No products found'))];
      return products.take(25).map((product) {
        final price = _productPrice(product);
        return ListTile(
          title: Text('${_text(product['code'])} - ${_text(product['description'])}'),
          subtitle: Text('Price: R ${price.toStringAsFixed(2)}'),
          onTap: () => setState(() {
            line.productId = _text(product['id']);
            line.productCode = _text(product['code']);
            line.productSearch.text = line.productCode;
            line.description.text = _text(product['description']);
            line.unitPrice.text = price.toStringAsFixed(2);
            line.uom = _productUom(product);
            controller.closeView(line.productCode);
          }),
        );
      }).toList();
    },
  );

  Widget _termsStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Wrap(spacing: 12, runSpacing: 12, children: [
      SizedBox(
        width: 240,
        child: DropdownButtonFormField<String>(
          value: _frequency,
          decoration: const InputDecoration(
            labelText: 'Payment frequency',
            border: OutlineInputBorder(),
          ),
          items: const ['WEEKLY', 'FORTNIGHTLY', 'MONTHLY', 'ONCE']
              .map((v) => DropdownMenuItem(value: v, child: Text(v)))
              .toList(),
          onChanged: (v) => setState(() {
            _frequency = v ?? 'MONTHLY';
            _installments.text = '${_defaultInstallmentCount(_frequency)}';
          }),
        ),
      ),
      SizedBox(width: 220, child: TextField(controller: _installments, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Number of instalments', border: OutlineInputBorder()))),
      SizedBox(
        width: 260,
        child: TextField(
          controller: _deposit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Agreed deposit',
            prefixText: 'R ',
            border: const OutlineInputBorder(),
            helperText: _depositRequired
                ? 'Minimum $_minimumDepositPercent% (blank = minimum)'
                : 'Optional; blank = no deposit',
          ),
        ),
      ),
    ]),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Text('Goods are reserved when the layby is activated and are only issued after the layby is fully paid and fulfilled. Partial and early payments are allowed. The recorded cancellation penalty is $_cancellationPenaltyPercent% (never more than 1%) and the default grace period is $_graceBusinessDays business days after anticipated completion. Death or hospitalisation cancellation reasons do not attract a cancellation penalty.'),
    ),
    CheckboxListTile(contentPadding: EdgeInsets.zero, value: _termsAccepted, onChanged: (v) => setState(() => _termsAccepted = v == true), title: const Text('Customer has reviewed and accepted the layby terms')),
  ]);

  Widget _reviewStep() {
    final subtotal = _lines.fold<double>(0, (sum, line) => sum + line.quantity * _double(line.unitPrice.text) * (1 + _double(line.taxRate.text) / 100));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _reviewRow('Customer', _customer == null ? '-' : _partnerName(_customer!)),
      _reviewRow('Items', '${_lines.where((e) => e.productId.isNotEmpty).length}'),
      _reviewRow('Agreement total', 'R ${subtotal.toStringAsFixed(2)}'),
      _reviewRow('Payment frequency', _frequency),
      _reviewRow('Instalments', _installments.text),
      _reviewRow('Agreed deposit', _deposit.text.trim().isEmpty ? (_depositRequired ? 'Configured minimum ($_minimumDepositPercent%)' : 'None') : 'R ${_double(_deposit.text).toStringAsFixed(2)}'),
      _reviewRow('Cancellation penalty', '$_cancellationPenaltyPercent%'),
      _reviewRow('Default grace period', '$_graceBusinessDays business days'),
      _reviewRow('Terms accepted', _termsAccepted ? 'Yes' : 'No'),
      const SizedBox(height: 12),
      const Text('The layby will be created as DRAFT. Capture any required deposit, then activate it to reserve stock.'),
    ]);
  }

  int _defaultInstallmentCount(String frequency) {
    switch (frequency.toUpperCase()) {
      case 'WEEKLY':
        return _defaultDurationMonths * 4;
      case 'FORTNIGHTLY':
        return _defaultDurationMonths * 2;
      case 'ONCE':
        return 1;
      default:
        return _defaultDurationMonths;
    }
  }

  Widget _reviewRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [SizedBox(width: 180, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(value))]));
}

class _LaybyLineDraft {
  final SearchController productSearch = SearchController();
  final TextEditingController description = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController unitPrice = TextEditingController(text: '0.00');
  final TextEditingController taxRate = TextEditingController(text: '15');
  String productId = '';
  String productCode = '';
  String uom = 'EA';

  double get quantity => _double(quantityController.text);

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'productCode': productCode,
    'description': description.text.trim(),
    'quantity': quantity,
    'uom': uom,
    'unitPrice': _double(unitPrice.text),
    'taxRate': _double(taxRate.text),
  };

  void dispose() {
    productSearch.dispose();
    description.dispose();
    quantityController.dispose();
    unitPrice.dispose();
    taxRate.dispose();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.replaceAll('_', ' ');
    return Chip(label: Text(normalized.isEmpty ? '-' : normalized), visualDensity: VisualDensity.compact);
  }
}

List<Map<String, dynamic>> _maps(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

String _partnerName(Map<String, dynamic> partner) {
  final explicit = _text(partner['fullName'] ?? partner['displayName'] ?? partner['customer_name']);
  if (explicit.isNotEmpty) return explicit;
  final parts = [_text(partner['name2']), _text(partner['name3']), _text(partner['name1'])].where((part) => part.trim().isNotEmpty).toList();
  return parts.isEmpty ? _text(partner['partnerNo'] ?? partner['number'] ?? 'Unnamed Customer') : parts.join(' ');
}

double _productPrice(Map<String, dynamic> product) {
  final direct = _double(product['price'] ?? product['unitPrice'] ?? product['amount']);
  if (direct > 0) return direct;
  final pricings = product['pricings'];
  if (pricings is List && pricings.isNotEmpty && pricings.first is Map) return _double((pricings.first as Map)['value']);
  return 0;
}

String _productUom(Map<String, dynamic> product) {
  final raw = product['baseUnitOfMeasure'] ?? product['base_unit_of_measure'] ?? product['uom'];
  if (raw is Map) return _text(raw['code'] ?? raw['description']).isEmpty ? 'EA' : _text(raw['code'] ?? raw['description']);
  return _text(raw).isEmpty ? 'EA' : _text(raw);
}

String _label(String key) => key.replaceAll('_', ' ').split(' ').map((v) => v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}').join(' ');
String _text(dynamic value) => value == null ? '' : value.toString();
double _double(dynamic value) => double.tryParse(_text(value).replaceAll(',', '.')) ?? 0;
int _int(dynamic value, int fallback) => int.tryParse(_text(value)) ?? fallback;
bool _bool(dynamic value) => value == true || value == 1 || _text(value).toLowerCase() == 'true' || _text(value) == '1';
String _money(dynamic cents) => 'R ${((double.tryParse(_text(cents)) ?? 0) / 100.0).toStringAsFixed(2)}';
String _date(dynamic value) {
  if (value == null || _text(value).isEmpty) return '-';
  final parsed = DateTime.tryParse(_text(value));
  return parsed == null ? _text(value) : DateFormat('dd MMM yyyy').format(parsed);
}
String _dateTime(dynamic value) {
  if (value == null || _text(value).isEmpty) return '-';
  final parsed = DateTime.tryParse(_text(value));
  return parsed == null ? _text(value) : DateFormat('dd MMM yyyy HH:mm').format(parsed);
}
