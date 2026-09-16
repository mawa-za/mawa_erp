import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/reseller_portal_service.dart';
import '../../../core/errors/app_error.dart';

class ResellerClientManagementScreen extends StatefulWidget {
  const ResellerClientManagementScreen({super.key});
  @override State<ResellerClientManagementScreen> createState() => _ResellerClientManagementScreenState();
}

class _ResellerClientManagementScreenState extends State<ResellerClientManagementScreen> {
  final _service = ResellerPortalService();
  late Future<List<dynamic>> _data;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() => setState(() => _data = Future.wait([_service.profile(), _service.clients(), _service.sessions(), _service.tickets()]));

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reseller Client Management'), actions: [IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded))]),
    body: FutureBuilder<List<dynamic>>(future: _data, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.admin_panel_settings_outlined, size: 48), const SizedBox(height: 12),
        const Text('Reseller access is not configured for this tenant.', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8), Text(_friendly(snapshot.error), textAlign: TextAlign.center), const SizedBox(height: 16),
        FilledButton(onPressed: _refresh, child: const Text('Retry')),
      ])));
      final profile = Map<String, dynamic>.from(snapshot.data![0] as Map);
      final clients = List<Map<String, dynamic>>.from(snapshot.data![1] as List);
      final sessions = List<Map<String, dynamic>>.from(snapshot.data![2] as List);
      final tickets = List<Map<String, dynamic>>.from(snapshot.data![3] as List);
      return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.all(20), children: [
        _header(profile, clients.length, sessions.length, tickets.length), const SizedBox(height: 20),
        Row(children: [Expanded(child: Text('Support queue', style: Theme.of(context).textTheme.titleLarge)),
          Text('${tickets.where((item) => !['RESOLVED','CLOSED'].contains(item['status'])).length} open')]),
        const SizedBox(height: 6), const Text('Only tickets for client tenants assigned to your signed-in employee account are shown.'),
        const SizedBox(height: 12),
        if (tickets.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No support tickets are assigned to your client access.')))
        else ...tickets.map((ticket) => _ticketCard(ticket, clients, sessions)),
        const SizedBox(height: 20),
        Row(children: [Expanded(child: Text('MAWA tenant clients', style: Theme.of(context).textTheme.titleLarge)),
          if (profile['mayProvisionTenants'] == true) FilledButton.icon(
            onPressed: _createTenant, icon: const Icon(Icons.add_business_rounded), label: const Text('Create tenant'))]),
        const SizedBox(height: 6),
        const Text('External clients and non-MAWA services remain under Customers and Service Management in this tenant.'), const SizedBox(height: 12),
        if (clients.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No MAWA tenants are assigned to this reseller.')))
        else ...clients.map((client) => _clientCard(client, sessions)),
      ]));
    }),
  );

  Widget _header(Map<String, dynamic> profile, int clients, int sessions, int tickets) => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Wrap(spacing: 32, runSpacing: 16, children: [
      _metric(Icons.handshake_rounded, profile['brandingName']?.toString() ?? profile['tenantName']?.toString() ?? 'Reseller', 'Support provider'),
      _metric(Icons.business_rounded, '$clients', 'Assigned tenants'),
      _metric(Icons.schedule_rounded, '${profile['slaResponseHours'] ?? 8}h', 'Response SLA'),
      _metric(Icons.lock_clock_rounded, '$sessions', 'Active support sessions'),
      _metric(Icons.confirmation_number_outlined, '$tickets', 'Visible tickets'),
    ]),
  ));
  Widget _metric(IconData icon, String value, String label) => SizedBox(width: 180, child: Row(children: [Icon(icon, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label)]))]));

  Widget _clientCard(Map<String, dynamic> client, List<Map<String, dynamic>> sessions) {
    final active = sessions.where((session) => session['clientTenantId'] == client['clientTenantId']).toList();
    final tenantStatus = client['clientTenantStatus']?.toString() ?? 'ACTIVE';
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      const CircleAvatar(child: Icon(Icons.business_rounded)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(client['clientTenantName']?.toString() ?? 'Tenant', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), Text(client['clientTenantHost']?.toString() ?? ''),
        Text('${_label(client['supportLevel'])} • ${_label(client['billingResponsibility'])}'),
        if (tenantStatus != 'ACTIVE') Text(_label(tenantStatus), style: TextStyle(
          color: tenantStatus == 'PROVISIONING_FAILED' ? Colors.red : Colors.orange, fontWeight: FontWeight.bold)),
        if (tenantStatus == 'PROVISIONING_FAILED' && client['clientTenantProvisioningError'] != null)
          Text(client['clientTenantProvisioningError'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (tenantStatus == 'PROVISIONING_FAILED') TextButton.icon(
          onPressed: () => _retryProvisioning(client), icon: const Icon(Icons.refresh_rounded), label: const Text('Retry setup')),
        if (tenantStatus == 'ACTIVE' && active.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(onPressed: () => _openSession(active.first), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open tenant')),
          IconButton(onPressed: () => _revokeSession(active.first), icon: const Icon(Icons.cancel_outlined), tooltip: 'Revoke support session'),
        ]),
        const Text('Start support access from an active ticket.', style: TextStyle(fontSize: 12)),
      ]),
    ])));
  }

  Widget _ticketCard(Map<String, dynamic> ticket, List<Map<String, dynamic>> clients, List<Map<String, dynamic>> sessions) {
    final breached = ticket['slaBreached'] == true;
    final activeSession = sessions.where((item) => item['ticketReference'] == ticket['ticketNo']).toList();
    return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
      leading: CircleAvatar(backgroundColor: breached ? Colors.red.shade50 : null,
        child: Icon(breached ? Icons.warning_amber_rounded : Icons.support_agent_rounded, color: breached ? Colors.red : null)),
      title: Text(ticket['subject']?.toString() ?? 'Support ticket'),
      subtitle: Text('${ticket['ticketNo'] ?? ''} • ${ticket['clientTenantName'] ?? ''}\n${_label(ticket['priority'])} • ${_label(ticket['status'])}${breached ? ' • SLA overdue' : ''}'),
      isThreeLine: true, onTap: () => _openTicket(ticket),
      trailing: activeSession.isNotEmpty
        ? IconButton(onPressed: () => _openSession(activeSession.first), icon: const Icon(Icons.open_in_new_rounded), tooltip: 'Open tenant')
        : IconButton(onPressed: ['RESOLVED','CLOSED'].contains(ticket['status']) ? null : () => _startTicketSession(ticket, clients),
            icon: const Icon(Icons.lock_clock_rounded), tooltip: 'Start support access'),
    ));
  }

  Future<void> _startTicketSession(Map<String, dynamic> ticket, List<Map<String, dynamic>> clients) async {
    Map<String, dynamic>? client;
    for (final item in clients) { if (item['clientTenantId'] == ticket['clientTenantId']) { client = item; break; } }
    if (client == null) { _showError('The client assignment for this ticket is not active.'); return; }
    await _startSession(client, ticketReference: ticket['ticketNo']?.toString());
  }

  Future<void> _startSession(Map<String, dynamic> client, {String? ticketReference}) async {
    final form = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SupportSessionDialog(
      clientName: client['clientTenantName']?.toString() ?? 'tenant', ticketReference: ticketReference));
    if (form == null) return;
    form['assignmentId'] = client['id'];
    try { await _service.startSession(form); _refresh(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time-limited support session started.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e)), backgroundColor: Colors.red.shade700)); }
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    try {
      final detail = await _service.ticketDetail(ticket['id'].toString());
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => _TicketDialog(ticket: detail, service: _service, onChanged: _refresh));
    } catch (e) { _showError(_friendly(e)); }
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red.shade700));
  }

  Future<void> _openSession(Map<String, dynamic> session) async {
    try {
      final handoff = await _service.openSession(session['id'].toString());
      final target = handoff['targetUrl']?.toString();
      if (target == null || target.isEmpty) throw AppException('The support handoff did not return a destination.');
      final opened = await launchUrl(Uri.parse(target), webOnlyWindowName: '_blank');
      if (!opened) throw AppException('The tenant window could not be opened.');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e)), backgroundColor: Colors.red.shade700));
    }
  }

  Future<void> _revokeSession(Map<String, dynamic> session) async {
    try { await _service.revokeSession(session['id'].toString()); _refresh(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e)), backgroundColor: Colors.red.shade700)); }
  }

  Future<void> _retryProvisioning(Map<String, dynamic> client) async {
    try {
      await _service.retryClientProvisioning(client['clientTenantId'].toString());
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tenant provisioning restarted.')));
    } catch (e) { _showError(_friendly(e)); }
  }

  Future<void> _createTenant() async {
    final request = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => const _CreateTenantDialog());
    if (request == null) return;
    try {
      final result = await _service.createClient(request);
      _refresh();
      final tenant = Map<String, dynamic>.from(result['tenant'] as Map? ?? const {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['provisioningStatus'] == 'PROVISIONING_FAILED'
          ? 'Tenant registered, but setup could not start. Use Retry setup.'
          : 'Tenant registered at ${tenant['url'] ?? tenant['host'] ?? ''}. Setup is running.')));
    } catch (e) { _showError(_friendly(e)); }
  }
}

class _CreateTenantDialog extends StatefulWidget {
  const _CreateTenantDialog();
  @override State<_CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<_CreateTenantDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _prefix = TextEditingController();
  String _support = 'FIRST_LINE';
  String _billing = 'MAWA_TO_TENANT';

  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create MAWA tenant'),
    content: SizedBox(width: 520, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('The tenant schema and wildcard-routed URL are created automatically.'), const SizedBox(height: 16),
      TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Tenant name'),
        validator: (value) => value == null || value.trim().isEmpty ? 'Tenant name is required' : null),
      const SizedBox(height: 12), TextFormField(controller: _prefix, autocorrect: false,
        decoration: const InputDecoration(labelText: 'URL prefix', helperText: 'Lowercase letters, numbers and hyphens'),
        validator: (value) => RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(value?.trim() ?? '')
          ? null : 'Enter a valid URL prefix'),
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: _support,
        decoration: const InputDecoration(labelText: 'Support level'), items: const [
          DropdownMenuItem(value: 'FIRST_LINE', child: Text('First line')),
          DropdownMenuItem(value: 'FIRST_AND_SECOND_LINE', child: Text('First and second line')),
          DropdownMenuItem(value: 'COMMERCIAL_ONLY', child: Text('Commercial only')),
        ], onChanged: (value) => setState(() => _support = value!)),
      const SizedBox(height: 12), DropdownButtonFormField<String>(value: _billing,
        decoration: const InputDecoration(labelText: 'Billing responsibility'), items: const [
          DropdownMenuItem(value: 'MAWA_TO_TENANT', child: Text('MAWA bills tenant')),
          DropdownMenuItem(value: 'MAWA_TO_RESELLER', child: Text('MAWA bills reseller')),
          DropdownMenuItem(value: 'RESELLER_TO_CLIENT', child: Text('Reseller bills client')),
          DropdownMenuItem(value: 'SHARED', child: Text('Shared')),
        ], onChanged: (value) => setState(() => _billing = value!)),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, {
        'name': _name.text.trim(), 'urlPrefix': _prefix.text.trim(),
        'supportLevel': _support, 'billingResponsibility': _billing,
      }); }, child: const Text('Create tenant'))],
  );
}

class _TicketDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final ResellerPortalService service;
  final VoidCallback onChanged;
  const _TicketDialog({required this.ticket, required this.service, required this.onChanged});
  @override State<_TicketDialog> createState() => _TicketDialogState();
}
class _TicketDialogState extends State<_TicketDialog> {
  late Map<String, dynamic> _ticket;
  final _comment = TextEditingController();
  bool _busy = false;
  @override void initState() { super.initState(); _ticket = widget.ticket; }
  @override Widget build(BuildContext context) {
    final activities = List<Map<String, dynamic>>.from((_ticket['activities'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)));
    return AlertDialog(title: Text('${_ticket['ticketNo']} — ${_ticket['subject']}'), content: SizedBox(width: 720, height: 560,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [Chip(label: Text(_label(_ticket['priority']))), Chip(label: Text(_label(_ticket['status']))),
          Chip(label: Text(_ticket['clientTenantName']?.toString() ?? 'Client')),
          if (_ticket['slaBreached'] == true) const Chip(avatar: Icon(Icons.warning_amber_rounded, size: 18), label: Text('SLA overdue'))]),
        const SizedBox(height: 12), Text(_ticket['description']?.toString() ?? ''), const Divider(height: 28),
        Expanded(child: activities.isEmpty ? const Center(child: Text('No activity yet.')) : ListView.builder(itemCount: activities.length, itemBuilder: (_, index) {
          final item = activities[index];
          return ListTile(dense: true, leading: const Icon(Icons.history_rounded), title: Text(_label(item['activityType'])),
            subtitle: Text('${item['message'] ?? item['newStatus'] ?? ''}\n${item['actor'] ?? ''} • ${item['createdAt'] ?? ''}'), isThreeLine: true);
        })),
        Row(children: [Expanded(child: TextField(controller: _comment, decoration: const InputDecoration(labelText: 'Add a comment'))),
          const SizedBox(width: 8), IconButton(onPressed: _busy ? null : _sendComment, icon: const Icon(Icons.send_rounded), tooltip: 'Send comment')]),
      ])),
      actions: [
        TextButton(onPressed: _busy ? null : _assign, child: const Text('Assign')),
        TextButton(onPressed: _busy ? null : _escalate, child: const Text('Escalate to MAWA')),
        PopupMenuButton<String>(enabled: !_busy, onSelected: _status, itemBuilder: (_) => const [
          PopupMenuItem(value: 'IN_PROGRESS', child: Text('In progress')), PopupMenuItem(value: 'WAITING_FOR_CLIENT', child: Text('Waiting for client')),
          PopupMenuItem(value: 'RESOLVED', child: Text('Resolve')), PopupMenuItem(value: 'CLOSED', child: Text('Close'))], child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Text('Change status'))),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ]);
  }
  Future<void> _run(Future<Map<String, dynamic>> Function() action) async {
    setState(() => _busy = true);
    try { final updated = await action(); if (mounted) setState(() { _ticket = updated; _busy = false; }); widget.onChanged(); }
    catch (error) { if (mounted) { setState(() => _busy = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(error)), backgroundColor: Colors.red)); } }
  }
  void _sendComment() { final message = _comment.text.trim(); if (message.isEmpty) return; _comment.clear(); _run(() => widget.service.comment(_ticket['id'].toString(), message)); }
  void _status(String status) => _run(() => widget.service.updateStatus(_ticket['id'].toString(), status));
  Future<void> _assign() async { final value = await _textPrompt('Assign ticket', 'Employee username'); if (value != null) _run(() => widget.service.assign(_ticket['id'].toString(), value)); }
  Future<void> _escalate() async { final value = await _textPrompt('Escalate to MAWA', 'Escalation reason', lines: 3); if (value != null) _run(() => widget.service.escalate(_ticket['id'].toString(), value)); }
  Future<String?> _textPrompt(String title, String label, {int lines = 1}) async {
    final controller = TextEditingController();
    return showDialog<String>(context: context, builder: (_) => AlertDialog(title: Text(title), content: TextField(controller: controller, maxLines: lines,
      decoration: InputDecoration(labelText: label)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { if (controller.text.trim().isNotEmpty) Navigator.pop(context, controller.text.trim()); }, child: const Text('Confirm'))]));
  }
}

class _SupportSessionDialog extends StatefulWidget { final String clientName; final String? ticketReference; const _SupportSessionDialog({required this.clientName, this.ticketReference}); @override State<_SupportSessionDialog> createState() => _SupportSessionDialogState(); }
class _SupportSessionDialogState extends State<_SupportSessionDialog> {
  final _form = GlobalKey<FormState>(); final _reason = TextEditingController(); final _ticket = TextEditingController();
  String _mode = 'READ_ONLY'; int _minutes = 60;
  @override void initState() { super.initState(); _ticket.text = widget.ticketReference ?? ''; }
  @override Widget build(BuildContext context) => AlertDialog(title: Text('Support access: ${widget.clientName}'), content: SizedBox(width: 480, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('Access is time-limited and fully audited. Read-only is recommended for first-line diagnosis.'), const SizedBox(height: 16),
    TextFormField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Access reason'), validator: (v) => v?.trim().isEmpty == true ? 'Reason is required' : null),
    const SizedBox(height: 12), TextFormField(controller: _ticket, readOnly: widget.ticketReference != null, decoration: const InputDecoration(labelText: 'Active ticket reference'), validator: (v) => v?.trim().isEmpty == true ? 'Ticket reference is required' : null),
    const SizedBox(height: 12), DropdownButtonFormField<String>(value: _mode, decoration: const InputDecoration(labelText: 'Access mode'), items: const [
      DropdownMenuItem(value: 'READ_ONLY', child: Text('Read only')), DropdownMenuItem(value: 'SUPPORT_OPERATOR', child: Text('Support operator')),
    ], onChanged: (v) => setState(() => _mode = v!)),
    const SizedBox(height: 12), DropdownButtonFormField<int>(value: _minutes, decoration: const InputDecoration(labelText: 'Duration'), items: const [
      DropdownMenuItem(value: 30, child: Text('30 minutes')), DropdownMenuItem(value: 60, child: Text('1 hour')),
      DropdownMenuItem(value: 120, child: Text('2 hours')), DropdownMenuItem(value: 240, child: Text('4 hours')),
    ], onChanged: (v) => setState(() => _minutes = v!)),
  ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, {
    'accessReason': _reason.text.trim(), 'ticketReference': _ticket.text.trim(), 'accessMode': _mode, 'durationMinutes': _minutes,
  }); }, child: const Text('Start session'))]);
}

String _label(Object? value) => (value?.toString() ?? '').toLowerCase().split('_').map((p) => p.isEmpty ? p : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');
String _friendly(Object? error) { if (error is AppException) return error.message; return error?.toString() ?? 'Something went wrong'; }
