import 'package:flutter/material.dart';
import '../models/tombstone_models.dart';
import '../services/tombstone_service.dart';

class TombstoneOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const TombstoneOrderDetailScreen({super.key, required this.orderId});

  @override
  State<TombstoneOrderDetailScreen> createState() => _TombstoneOrderDetailScreenState();
}

class _TombstoneOrderDetailScreenState extends State<TombstoneOrderDetailScreen> {
  final _service = TombstoneService();
  TombstoneOrder? _order;
  bool _loading = true;
  bool _working = false;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await _service.order(widget.orderId);
      if (mounted) setState(() { _order = value; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _run(Future<TombstoneOrder> Function() action) async {
    setState(() { _working = true; _error = null; });
    try {
      final value = await action();
      if (mounted) setState(() => _order = value);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error!)));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_order?.orderNo ?? 'Tombstone Order'),
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? _failure()
              : Stack(children: [
                  RefreshIndicator(onRefresh: _load, child: _body(_order!)),
                  if (_working) const Positioned.fill(child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator()))),
                ]),
    );
  }

  Widget _failure() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.error_outline, size: 52), const SizedBox(height: 12), Text(_error ?? 'Order not found'),
    const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry')),
  ]));

  Widget _body(TombstoneOrder order) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (_error != null) _errorBanner(_error!),
      _summary(order),
      const SizedBox(height: 14),
      _actions(order),
      const SizedBox(height: 14),
      _items(order),
      _funding(order),
      _layby(order),
      _assessments(order),
      _amendments(order),
      _designs(order),
      _production(order),
      _installations(order),
      _history(order),
      const SizedBox(height: 80),
    ],
  );

  Widget _summary(TombstoneOrder order) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const CircleAvatar(radius: 28, child: Icon(Icons.account_balance_outlined, size: 30)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(order.deceasedName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text('${order.orderNo} • ${_label(order.status)}'),
            if (order.cemeteryName != null) Text('${order.cemeteryName}${order.graveNumber == null ? '' : ' • Grave ${order.graveNumber}'}'),
          ])),
          _chip(order.fundingStatus),
        ]),
        const Divider(height: 28),
        Wrap(spacing: 28, runSpacing: 14, children: [
          _metric('Order Total', 'R ${order.total.toStringAsFixed(2)}'),
          _metric('Confirmed Funding', 'R ${order.confirmedFunding.toStringAsFixed(2)}'),
          _metric('Outstanding', 'R ${order.balance.toStringAsFixed(2)}'),
          _metric('Funding Method', _label(order.fundingMethod)),
          _metric('Production', _label(order.productionStatus)),
          _metric('Installation', _label(order.installationStatus)),
        ]),
        if (order.invoiceId != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Invoice: ${order.invoiceId}', style: Theme.of(context).textTheme.bodySmall),
        ),
      ]),
    ),
  );

  Widget _actions(TombstoneOrder order) {
    final closed = const {'COMPLETED', 'CANCELLED'}.contains(order.status);
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.tonalIcon(onPressed: closed ? null : _addFunding, icon: const Icon(Icons.add_card), label: const Text('Add Funding')),
        FilledButton.tonalIcon(onPressed: closed || order.laybyAgreement != null || order.balanceCents <= 0 ? null : _createLayby, icon: const Icon(Icons.savings_outlined), label: const Text('Create Lay-by')),
        FilledButton.tonalIcon(onPressed: closed ? null : _addAssessment, icon: const Icon(Icons.location_searching), label: const Text('Site Assessment')),
        FilledButton.tonalIcon(onPressed: closed ? null : _addDesign, icon: const Icon(Icons.design_services_outlined), label: const Text('New Design')),
        FilledButton.tonalIcon(onPressed: closed ? null : _createProduction, icon: const Icon(Icons.precision_manufacturing_outlined), label: const Text('Production Job')),
        FilledButton.tonalIcon(onPressed: closed ? null : _createInstallation, icon: const Icon(Icons.construction_outlined), label: const Text('Plan Installation')),
        OutlinedButton.icon(onPressed: closed ? null : _createAmendment, icon: const Icon(Icons.edit_note), label: const Text('Order Amendment')),
        OutlinedButton.icon(onPressed: closed ? null : _cancelOrder, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel Order')),
      ]),
    ));
  }

  Widget _items(TombstoneOrder order) => _section(
    title: 'Order Items', icon: Icons.list_alt_outlined,
    children: order.items.map((item) => ListTile(
      title: Text(item['description']?.toString() ?? 'Item'),
      subtitle: Text([
        if (item['material'] != null) item['material'].toString(),
        if (item['colour'] != null) item['colour'].toString(),
        if (item['dimensions'] != null) item['dimensions'].toString(),
        if (item['inscriptionText'] != null) 'Inscription: ${item['inscriptionText']}',
      ].join(' • ')),
      trailing: Text('R ${_cents(item['totalCents']).toStringAsFixed(2)}'),
    )).toList(),
  );

  Widget _funding(TombstoneOrder order) => _section(
    title: 'Funding Allocations', icon: Icons.account_balance_wallet_outlined,
    children: order.fundingAllocations.isEmpty
        ? [const ListTile(title: Text('No funding has been allocated'))]
        : order.fundingAllocations.map((value) => ListTile(
            leading: Icon(value['fundingType'] == 'FUNERAL_COVER' ? Icons.health_and_safety_outlined : value['fundingType'] == 'LAYBY' ? Icons.savings_outlined : Icons.payments_outlined),
            title: Text('${_label(value['fundingType']?.toString() ?? '')} • ${value['sourceNo'] ?? value['sourceId'] ?? ''}'),
            subtitle: Text(_label(value['status']?.toString() ?? '')),
            trailing: Text('R ${_cents(value['confirmedAmountCents']).toStringAsFixed(2)}'),
          )).toList(),
  );

  Widget _layby(TombstoneOrder order) {
    final agreement = order.laybyAgreement;
    if (agreement == null) return const SizedBox.shrink();
    return _section(
      title: 'Lay-by Agreement', icon: Icons.savings_outlined,
      action: TextButton.icon(onPressed: agreement['status'] == 'SETTLED' ? null : _recordLaybyPayment, icon: const Icon(Icons.add), label: const Text('Record Payment')),
      children: [
        ListTile(
          title: Text(agreement['agreementNo']?.toString() ?? 'Lay-by'),
          subtitle: Text('${_label(agreement['status']?.toString() ?? '')} • ${agreement['paymentFrequency'] ?? ''}'),
          trailing: Text('R ${_cents(agreement['balanceCents']).toStringAsFixed(2)} outstanding'),
        ),
        ...order.laybyInstallments.map((row) => ListTile(
          dense: true,
          leading: Icon(row['status'] == 'PAID' ? Icons.check_circle : Icons.schedule),
          title: Text('Instalment ${row['installmentNo']} • ${row['dueDate']}'),
          subtitle: Text(_label(row['status']?.toString() ?? '')),
          trailing: Text('R ${_cents(row['paidAmountCents']).toStringAsFixed(2)} / R ${_cents(row['amountCents']).toStringAsFixed(2)}'),
        )),
      ],
    );
  }

  Widget _assessments(TombstoneOrder order) => _section(
    title: 'Site Assessments', icon: Icons.location_searching,
    children: order.assessments.isEmpty ? [const ListTile(title: Text('No site assessments'))] : order.assessments.map((a) => ListTile(
      title: Text('Assessment v${a['versionNo']} • ${_label(a['status']?.toString() ?? '')}'),
      subtitle: Text([
        if (a['foundationCondition'] != null) 'Foundation: ${a['foundationCondition']}',
        if (a['permitRequired'] == true) 'Permit: ${a['permitApproved'] == true ? 'Approved' : 'Required'}',
        if ((a['additionalCostCents'] as num?)?.toInt() != 0) 'Additional cost: R ${_cents(a['additionalCostCents']).toStringAsFixed(2)}',
      ].join('\n')),
      isThreeLine: true,
    )).toList(),
  );

  Widget _amendments(TombstoneOrder order) => _section(
    title: 'Order Amendments', icon: Icons.edit_note,
    children: order.amendments.isEmpty ? [const ListTile(title: Text('No order amendments'))] : order.amendments.map((a) => ListTile(
      title: Text('Amendment ${a['amendmentNo']} • ${_label(a['status']?.toString() ?? '')}'),
      subtitle: Text(a['reason']?.toString() ?? ''),
      trailing: a['status'] == 'PENDING_CUSTOMER_APPROVAL'
          ? Wrap(spacing: 4, children: [
              IconButton(tooltip: 'Approve', icon: const Icon(Icons.check_circle_outline), onPressed: () => _decideAmendment(a['id'].toString(), 'APPROVED')),
              IconButton(tooltip: 'Reject', icon: const Icon(Icons.cancel_outlined), onPressed: () => _decideAmendment(a['id'].toString(), 'REJECTED')),
            ])
          : Text('${_cents(a['amountDeltaCents']).isNegative ? '-' : ''}R ${_cents(a['amountDeltaCents']).abs().toStringAsFixed(2)}'),
    )).toList(),
  );

  Widget _designs(TombstoneOrder order) => _section(
    title: 'Design Versions', icon: Icons.design_services_outlined,
    children: order.designs.isEmpty ? [const ListTile(title: Text('No designs'))] : order.designs.map((d) => ListTile(
      title: Text('Design v${d['versionNo']} • ${_label(d['status']?.toString() ?? '')}'),
      subtitle: Text([
        if (d['material'] != null) '${d['material']} ${d['colour'] ?? ''}',
        if (d['inscriptionText'] != null) 'Inscription: ${d['inscriptionText']}',
        if (d['designAttachmentId'] != null) 'Attachment: ${d['designAttachmentId']}',
      ].join('\n')),
      isThreeLine: true,
      trailing: const {'DRAFT', 'SENT_FOR_APPROVAL', 'CHANGES_REQUESTED'}.contains(d['status'])
          ? TextButton(onPressed: () => _approveDesign(d['id'].toString()), child: const Text('Approve'))
          : null,
    )).toList(),
  );

  Widget _production(TombstoneOrder order) => _section(
    title: 'Production Jobs', icon: Icons.precision_manufacturing_outlined,
    children: order.productionJobs.isEmpty ? [const ListTile(title: Text('No production jobs'))] : order.productionJobs.map((job) => Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(children: [
          ListTile(
            title: Text('${job['jobNo']} • ${_label(job['status']?.toString() ?? '')}'),
            subtitle: Text(job['internalProduction'] == true ? 'Internal production' : 'Supplier: ${job['supplierPartnerId'] ?? ''}'),
          ),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final status in const ['MATERIAL_RECEIVED', 'CUTTING', 'ENGRAVING', 'ASSEMBLY', 'QUALITY_CHECK', 'READY_FOR_INSTALLATION'])
              OutlinedButton(onPressed: job['status'] == status ? null : () => _updateProduction(job, status), child: Text(_label(status))),
            if (job['internalProduction'] == false && const {'QUALITY_CHECK', 'READY_FOR_INSTALLATION'}.contains(job['status']))
              FilledButton.tonal(onPressed: () => _supplierPayment(job), child: const Text('Supplier Payment Request')),
          ]),
        ]),
      ),
    )).toList(),
  );

  Widget _installations(TombstoneOrder order) => _section(
    title: 'Installations', icon: Icons.construction_outlined,
    children: order.installations.isEmpty ? [const ListTile(title: Text('No installation plans'))] : order.installations.map((installation) {
      final checklist = (installation['checklist'] as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return ExpansionTile(
        title: Text('${installation['installationNo']} • ${_label(installation['status']?.toString() ?? '')}'),
        subtitle: Text('${installation['scheduledStartAt'] ?? 'Not scheduled'} • ${(installation['team'] as List? ?? const []).length} team member(s)'),
        children: [
          ...checklist.map((item) => CheckboxListTile(
            value: item['completed'] == true,
            title: Text(item['checklistLabel']?.toString() ?? item['checklistCode']?.toString() ?? ''),
            subtitle: item['evidenceAttachmentId'] == null ? null : Text('Evidence: ${item['evidenceAttachmentId']}'),
            onChanged: (value) => _updateChecklist(installation['id'].toString(), item, value == true),
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              OutlinedButton(
                onPressed: const {'READY_TO_SCHEDULE', 'SCHEDULED'}.contains(installation['status'])
                    ? () => _scheduleInstallation(installation)
                    : null,
                child: Text(installation['status'] == 'SCHEDULED' ? 'Reschedule' : 'Schedule'),
              ),
              OutlinedButton(
                onPressed: installation['status'] == 'SCHEDULED'
                    ? () => _installationStatus(installation, 'TEAM_DISPATCHED')
                    : null,
                child: const Text('Dispatch Team'),
              ),
              OutlinedButton(
                onPressed: installation['status'] == 'TEAM_DISPATCHED'
                    ? () => _installationStatus(installation, 'ON_SITE')
                    : null,
                child: const Text('Arrived On Site'),
              ),
              FilledButton.tonal(
                onPressed: installation['status'] == 'ON_SITE'
                    ? () => _completeInstallation(installation)
                    : null,
                child: const Text('Complete Installation'),
              ),
              FilledButton(
                onPressed: installation['status'] != 'INSTALLED'
                    ? null
                    : () => _acceptInstallation(installation),
                child: const Text('Accept & Close'),
              ),
              OutlinedButton(
                onPressed: const {'INSTALLED', 'COMPLETED', 'REWORK_REQUIRED'}.contains(installation['status'])
                    ? () => _createRework(installation)
                    : null,
                child: const Text('Create Rework'),
              ),
            ]),
          ),
        ],
      );
    }).toList(),
  );

  Widget _history(TombstoneOrder order) => _section(
    title: 'Audit Trail', icon: Icons.history,
    initiallyExpanded: false,
    children: order.statusHistory.map((h) => ListTile(
      dense: true,
      leading: const Icon(Icons.change_circle_outlined),
      title: Text('${h['statusDimension']}: ${_label(h['fromStatus']?.toString() ?? 'New')} → ${_label(h['toStatus']?.toString() ?? '')}'),
      subtitle: Text('${h['changedAt'] ?? ''}${h['reason'] == null ? '' : '\n${h['reason']}'}'),
    )).toList(),
  );

  Widget _section({required String title, required IconData icon, required List<Widget> children, Widget? action, bool initiallyExpanded = true}) => Card(
    margin: const EdgeInsets.only(top: 14),
    child: ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      leading: Icon(icon), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: action,
      children: children,
    ),
  );

  Future<void> _addFunding() async {
    final source = TextEditingController();
    final amount = TextEditingController();
    String type = 'CASH';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Add Funding Allocation'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: type, decoration: const InputDecoration(labelText: 'Funding Type'), items: const [
          DropdownMenuItem(value: 'CASH', child: Text('Cash Receipt')),
          DropdownMenuItem(value: 'FUNERAL_COVER', child: Text('Funeral Cover Claim')),
        ], onChanged: (v) => setLocal(() => type = v ?? 'CASH')),
        TextField(controller: source, decoration: InputDecoration(labelText: type == 'CASH' ? 'Receipt ID' : 'Approved Claim ID')),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (R)')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {
        'fundingType': type, 'sourceType': type == 'CASH' ? 'RECEIPT' : 'MEMBERSHIP_CLAIM', 'sourceId': source.text.trim(), 'allocatedAmountCents': _money(amount.text),
      }), child: const Text('Allocate'))],
    )));
    source.dispose(); amount.dispose();
    if (result != null) await _run(() => _service.addFunding(widget.orderId, result));
  }

  Future<void> _createLayby() async {
    final deposit = TextEditingController(text: '0');
    final installment = TextEditingController();
    final admin = TextEditingController(text: '0');
    String frequency = 'MONTHLY';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Create Lay-by Agreement'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: deposit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Deposit Required (R)')),
        TextField(controller: installment, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Instalment Amount (R)')),
        TextField(controller: admin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Administration Fee (R)')),
        DropdownButtonFormField<String>(value: frequency, decoration: const InputDecoration(labelText: 'Frequency'), items: const [
          DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')), DropdownMenuItem(value: 'FORTNIGHTLY', child: Text('Fortnightly')), DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
        ], onChanged: (v) => setLocal(() => frequency = v ?? 'MONTHLY')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {
        'depositRequiredCents': _money(deposit.text), 'installmentAmountCents': _money(installment.text), 'administrationFeeCents': _money(admin.text),
        'paymentFrequency': frequency, 'startDate': DateTime.now().toIso8601String().split('T').first, 'gracePeriodDays': 5,
      }), child: const Text('Create'))],
    )));
    deposit.dispose(); installment.dispose(); admin.dispose();
    if (result != null) await _run(() => _service.createLayby(widget.orderId, result));
  }

  Future<void> _recordLaybyPayment() async {
    final receipt = TextEditingController();
    final amount = TextEditingController();
    final result = await _simpleDialog('Record Lay-by Payment', [
      _DialogField('Receipt ID', receipt), _DialogField('Amount (R)', amount, number: true),
    ], () => {'receiptId': receipt.text.trim(), 'amountCents': _money(amount.text)});
    receipt.dispose(); amount.dispose();
    final id = _order?.laybyAgreement?['id']?.toString();
    if (result != null && id != null) await _run(() => _service.recordLaybyPayment(id, result));
  }

  Future<void> _addAssessment() async {
    final assessor = TextEditingController();
    final foundation = TextEditingController();
    final permit = TextEditingController();
    final additionalWork = TextEditingController();
    final additionalCost = TextEditingController(text: '0');
    final photos = TextEditingController();
    bool permitRequired = false, permitApproved = false;
    String status = 'COMPLETED';
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Site Assessment'),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(value: status, decoration: const InputDecoration(labelText: 'Status'), items: const [
          DropdownMenuItem(value: 'REQUESTED', child: Text('Requested')), DropdownMenuItem(value: 'SCHEDULED', child: Text('Scheduled')), DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')), DropdownMenuItem(value: 'FAILED', child: Text('Failed')),
        ], onChanged: (v) => setLocal(() => status = v ?? 'COMPLETED')),
        TextField(controller: assessor, decoration: const InputDecoration(labelText: 'Assessor Partner ID')),
        TextField(controller: foundation, decoration: const InputDecoration(labelText: 'Foundation Condition')),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: permitRequired, title: const Text('Permit Required'), onChanged: (v) => setLocal(() => permitRequired = v)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: permitApproved, title: const Text('Permit Approved'), onChanged: permitRequired ? (v) => setLocal(() => permitApproved = v) : null),
        TextField(controller: permit, decoration: const InputDecoration(labelText: 'Permit Reference')),
        TextField(controller: additionalWork, maxLines: 2, decoration: const InputDecoration(labelText: 'Additional Work Required')),
        TextField(controller: additionalCost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Additional Cost (R)')),
        TextField(controller: photos, decoration: const InputDecoration(labelText: 'Photo Attachment IDs (comma-separated)')),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {
        'status': status, 'assessedAt': status == 'COMPLETED' ? DateTime.now().toIso8601String() : null, 'assessorPartnerId': _blank(assessor.text),
        'foundationCondition': _blank(foundation.text), 'permitRequired': permitRequired, 'permitApproved': permitApproved,
        'permitReference': _blank(permit.text), 'additionalWorkRequired': _blank(additionalWork.text), 'additionalCostCents': _money(additionalCost.text),
        'photoAttachmentIds': _csv(photos.text),
      }), child: const Text('Save'))],
    )));
    for (final c in [assessor, foundation, permit, additionalWork, additionalCost, photos]) c.dispose();
    if (result != null) await _run(() => _service.addAssessment(widget.orderId, result));
  }

  Future<void> _createAmendment() async {
    final reason = TextEditingController();
    final amount = TextEditingController(text: '0');
    final result = await _simpleDialog('Order Amendment', [
      _DialogField('Reason', reason, lines: 3), _DialogField('Amount Change (R)', amount, number: true),
    ], () => {'reason': reason.text.trim(), 'amountDeltaCents': _signedMoney(amount.text)});
    reason.dispose(); amount.dispose();
    if (result != null) await _run(() => _service.createAmendment(widget.orderId, result));
  }

  Future<void> _decideAmendment(String id, String decision) async {
    await _run(() => _service.decideAmendment(id, {'decision': decision, 'responseNotes': '$decision in Tombstone Management'}));
  }

  Future<void> _addDesign() async {
    final inscription = TextEditingController();
    final font = TextEditingController();
    final material = TextEditingController();
    final colour = TextEditingController();
    final dimensions = TextEditingController();
    final attachment = TextEditingController();
    final result = await _simpleDialog('New Design Version', [
      _DialogField('Inscription', inscription, lines: 3), _DialogField('Font', font), _DialogField('Material', material),
      _DialogField('Colour', colour), _DialogField('Dimensions', dimensions), _DialogField('Design Attachment ID', attachment),
    ], () => {
      'status': 'SENT_FOR_APPROVAL', 'inscriptionText': _blank(inscription.text), 'fontName': _blank(font.text), 'material': _blank(material.text),
      'colour': _blank(colour.text), 'dimensions': _blank(dimensions.text), 'designAttachmentId': _blank(attachment.text),
    });
    for (final c in [inscription, font, material, colour, dimensions, attachment]) c.dispose();
    if (result != null) await _run(() => _service.addDesign(widget.orderId, result));
  }

  Future<void> _approveDesign(String id) async {
    final reference = TextEditingController();
    final result = await _simpleDialog('Approve Design', [_DialogField('Signature / OTP Reference', reference)], () => {
      'approvalMethod': 'SIGNATURE', 'approvalReference': reference.text.trim(),
    });
    reference.dispose();
    if (result != null) await _run(() => _service.approveDesign(id, result));
  }

  Future<void> _createProduction() async {
    bool internal = true;
    final supplier = TextEditingController();
    final purchaseOrder = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (context) => StatefulBuilder(builder: (context, setLocal) => AlertDialog(
      title: const Text('Create Production Job'),
      content: SizedBox(width: 440, child: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(contentPadding: EdgeInsets.zero, value: internal, title: const Text('Internal Production'), onChanged: (v) => setLocal(() => internal = v)),
        TextField(controller: supplier, enabled: !internal, decoration: const InputDecoration(labelText: 'Supplier Partner ID')),
        TextField(controller: purchaseOrder, enabled: !internal, decoration: const InputDecoration(labelText: 'Purchase Order ID')),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, {
        'internalProduction': internal, 'supplierPartnerId': internal ? null : supplier.text.trim(), 'purchaseOrderId': internal ? null : _blank(purchaseOrder.text),
      }), child: const Text('Create'))],
    )));
    supplier.dispose(); purchaseOrder.dispose();
    if (result != null) await _run(() => _service.createProduction(widget.orderId, result));
  }

  Future<void> _updateProduction(Map<String, dynamic> job, String status) async {
    final qualityBy = TextEditingController();
    Map<String, dynamic> body = {'status': status};
    if (const {'QUALITY_CHECK', 'READY_FOR_INSTALLATION'}.contains(status)) {
      final result = await _simpleDialog(_label(status), [_DialogField('Quality Checked By', qualityBy)], () => {'status': status, 'qualityCheckedBy': qualityBy.text.trim()});
      qualityBy.dispose();
      if (result == null) return;
      body = result;
    }
    await _run(() => _service.updateProductionStatus(job['id'].toString(), body));
  }

  Future<void> _supplierPayment(Map<String, dynamic> job) async {
    final amount = TextEditingController();
    final result = await _simpleDialog(
      'Supplier Payment Request',
      [_DialogField('Amount (R)', amount, number: true)],
      () => {
        'amountCents': _money(amount.text),
        'paymentMethod': 'EFT',
        'milestone': 'TOMBSTONE_PRODUCTION_QUALITY_APPROVED',
      },
    );
    amount.dispose();
    if (result == null) return;
    setState(() => _working = true);
    try {
      final payment = await _service.supplierPaymentRequest(job['id'].toString(), result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment request ${payment['requestNo'] ?? ''} submitted for approval')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _createInstallation() async {
    final start = TextEditingController();
    final end = TextEditingController();
    final team = TextEditingController();
    final vehicle = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final materials = TextEditingController();
    final result = await _simpleDialog('Plan Installation', [
      _DialogField('Start (YYYY-MM-DDTHH:mm)', start), _DialogField('End (YYYY-MM-DDTHH:mm)', end),
      _DialogField('Team Partner IDs (comma-separated)', team), _DialogField('Vehicle ID', vehicle),
      _DialogField('Contact Person', contact), _DialogField('Contact Number', phone),
      _DialogField('Materials (comma-separated descriptions)', materials, lines: 2),
    ], () => {
      'scheduledStartAt': _iso(start.text), 'scheduledEndAt': _iso(end.text), 'assignedVehicleId': _blank(vehicle.text),
      'contactPerson': _blank(contact.text), 'contactNumber': _blank(phone.text),
      'team': _csv(team.text).map((id) => {'employeePartnerId': id, 'teamRole': 'INSTALLER'}).toList(),
      'materials': _csv(materials.text).map((description) => {'description': description, 'quantity': 1, 'uom': 'EA'}).toList(),
    });
    final contactNumber = phone.text.trim();
    for (final c in [start, end, team, vehicle, contact, phone, materials]) c.dispose();
    if (result == null) return;
    if (contactNumber.isNotEmpty && !RegExp(r'^\d{10}$').hasMatch(contactNumber)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact Number must be 10 numeric digits.')),
        );
      }
      return;
    }
    await _run(() => _service.createInstallation(widget.orderId, result));
  }

  Future<void> _scheduleInstallation(Map<String, dynamic> installation) async {
    final start = TextEditingController(text: installation['scheduledStartAt']?.toString() ?? '');
    final end = TextEditingController(text: installation['scheduledEndAt']?.toString() ?? '');
    final result = await _simpleDialog('Schedule Installation', [
      _DialogField('Start (YYYY-MM-DDTHH:mm)', start),
      _DialogField('End (YYYY-MM-DDTHH:mm)', end),
    ], () => {
      'status': 'SCHEDULED',
      'scheduledStartAt': _iso(start.text),
      'scheduledEndAt': _iso(end.text),
    });
    start.dispose();
    end.dispose();
    if (result != null) {
      await _run(() => _service.updateInstallationStatus(installation['id'].toString(), result));
    }
  }

  Future<void> _installationStatus(Map<String, dynamic> installation, String status) async {
    await _run(() => _service.updateInstallationStatus(installation['id'].toString(), {'status': status}));
  }

  Future<void> _updateChecklist(String installationId, Map<String, dynamic> item, bool completed) async {
    final evidence = TextEditingController(text: item['evidenceAttachmentId']?.toString() ?? '');
    final result = completed
        ? await _simpleDialog('Complete Checklist Item', [_DialogField('Evidence Attachment ID (optional)', evidence)], () => {'completed': true, 'evidenceAttachmentId': _blank(evidence.text)})
        : {'completed': false};
    evidence.dispose();
    if (result != null) await _run(() => _service.updateChecklist(installationId, item['id'].toString(), result));
  }

  Future<void> _completeInstallation(Map<String, dynamic> installation) async {
    final before = TextEditingController();
    final after = TextEditingController();
    final representative = TextEditingController();
    final customerSignature = TextEditingController();
    final installerSignature = TextEditingController();
    final notes = TextEditingController();
    final result = await _simpleDialog('Complete Installation', [
      _DialogField('Before Photo IDs (comma-separated)', before), _DialogField('After Photo IDs (comma-separated)', after),
      _DialogField('Customer Representative', representative), _DialogField('Customer Signature Attachment ID', customerSignature),
      _DialogField('Installer Signature Attachment ID', installerSignature), _DialogField('Completion Notes', notes, lines: 3),
    ], () => {
      'beforePhotoAttachmentIds': _csv(before.text), 'afterPhotoAttachmentIds': _csv(after.text),
      'customerRepresentativeName': representative.text.trim(), 'customerSignatureAttachmentId': _blank(customerSignature.text),
      'installerSignatureAttachmentId': installerSignature.text.trim(), 'completionNotes': _blank(notes.text),
    });
    for (final c in [before, after, representative, customerSignature, installerSignature, notes]) c.dispose();
    if (result != null) await _run(() => _service.completeInstallation(installation['id'].toString(), result));
  }

  Future<void> _acceptInstallation(Map<String, dynamic> installation) async {
    final acceptedBy = TextEditingController(text: installation['customerRepresentativeName']?.toString() ?? '');
    final result = await _simpleDialog('Accept Installation', [_DialogField('Accepted By', acceptedBy)], () => {'acceptedBy': acceptedBy.text.trim()});
    acceptedBy.dispose();
    if (result != null) await _run(() => _service.acceptInstallation(installation['id'].toString(), result));
  }

  Future<void> _createRework(Map<String, dynamic> installation) async {
    final reason = TextEditingController();
    final result = await _simpleDialog('Create Rework Job', [_DialogField('Rework Reason', reason, lines: 3)], () => {'reason': reason.text.trim()});
    reason.dispose();
    if (result != null) await _run(() => _service.createRework(installation['id'].toString(), result));
  }

  Future<void> _cancelOrder() async {
    final reason = TextEditingController();
    final result = await _simpleDialog('Cancel Tombstone Order', [_DialogField('Cancellation Reason', reason, lines: 3)], () => {'reason': reason.text.trim()});
    if (result != null) {
      setState(() => _working = true);
      try {
        final summary = await _service.cancelOrder(widget.orderId, reason.text.trim());
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Refund review required: R ${_cents(summary['refundRequiredCents']).toStringAsFixed(2)}')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }
    reason.dispose();
  }

  Future<Map<String, dynamic>?> _simpleDialog(String title, List<_DialogField> fields, Map<String, dynamic> Function() value) {
    return showDialog<Map<String, dynamic>>(context: context, builder: (context) => AlertDialog(
      title: Text(title),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: fields.map((f) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(controller: f.controller, maxLines: f.lines, keyboardType: f.number ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null, decoration: InputDecoration(labelText: f.label, border: const OutlineInputBorder())),
      )).toList()))),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, value()), child: const Text('Continue'))],
    ));
  }

  Widget _errorBanner(String message) => Container(
    margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(10)),
    child: Row(children: [const Icon(Icons.error_outline), const SizedBox(width: 8), Expanded(child: Text(message))]),
  );
  Widget _chip(String value) => Chip(label: Text(_label(value)));
  Widget _metric(String label, String value) => SizedBox(width: 180, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]));

  static String _label(String value) => value.replaceAll('_', ' ').toLowerCase().split(' ').map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}').join(' ');
  static double _cents(dynamic value) => ((value as num?)?.toInt() ?? 0) / 100;
  static int _money(String value) => ((double.tryParse(value.trim()) ?? 0) * 100).round().abs();
  static int _signedMoney(String value) => ((double.tryParse(value.trim()) ?? 0) * 100).round();
  static String? _blank(String value) => value.trim().isEmpty ? null : value.trim();
  static List<String> _csv(String value) => value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  static String? _iso(String value) {
    final parsed = DateTime.tryParse(value.trim());
    return parsed?.toIso8601String();
  }
}

class _DialogField {
  final String label;
  final TextEditingController controller;
  final bool number;
  final int lines;
  const _DialogField(this.label, this.controller, {this.number = false, this.lines = 1});
}
