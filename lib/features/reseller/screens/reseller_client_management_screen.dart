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
  void _refresh() => setState(() => _data = Future.wait([_service.profile(), _service.clients(), _service.sessions()]));

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
      return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView(padding: const EdgeInsets.all(20), children: [
        _header(profile, clients.length, sessions.length), const SizedBox(height: 20),
        Text('MAWA tenant clients', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6),
        const Text('External clients and non-MAWA services remain under Customers and Service Management in this tenant.'), const SizedBox(height: 12),
        if (clients.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('No MAWA tenants are assigned to this reseller.')))
        else ...clients.map((client) => _clientCard(client, sessions)),
      ]));
    }),
  );

  Widget _header(Map<String, dynamic> profile, int clients, int sessions) => Card(child: Padding(
    padding: const EdgeInsets.all(20), child: Wrap(spacing: 32, runSpacing: 16, children: [
      _metric(Icons.handshake_rounded, profile['brandingName']?.toString() ?? profile['tenantName']?.toString() ?? 'Reseller', 'Support provider'),
      _metric(Icons.business_rounded, '$clients', 'Assigned tenants'),
      _metric(Icons.schedule_rounded, '${profile['slaResponseHours'] ?? 8}h', 'Response SLA'),
      _metric(Icons.lock_clock_rounded, '$sessions', 'Active support sessions'),
    ]),
  ));
  Widget _metric(IconData icon, String value, String label) => SizedBox(width: 180, child: Row(children: [Icon(icon, size: 30), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(label)]))]));

  Widget _clientCard(Map<String, dynamic> client, List<Map<String, dynamic>> sessions) {
    final active = sessions.where((session) => session['clientTenantId'] == client['clientTenantId']).toList();
    return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
      const CircleAvatar(child: Icon(Icons.business_rounded)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(client['clientTenantName']?.toString() ?? 'Tenant', style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), Text(client['clientTenantHost']?.toString() ?? ''),
        Text('${_label(client['supportLevel'])} • ${_label(client['billingResponsibility'])}'),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        if (active.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [
          TextButton.icon(onPressed: () => _openSession(active.first), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open tenant')),
          IconButton(onPressed: () => _revokeSession(active.first), icon: const Icon(Icons.cancel_outlined), tooltip: 'Revoke support session'),
        ]),
        FilledButton.tonalIcon(onPressed: () => _startSession(client), icon: const Icon(Icons.support_agent_rounded), label: Text(active.isEmpty ? 'Support access' : 'New session')),
      ]),
    ])));
  }

  Future<void> _startSession(Map<String, dynamic> client) async {
    final form = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _SupportSessionDialog(clientName: client['clientTenantName']?.toString() ?? 'tenant'));
    if (form == null) return;
    form['assignmentId'] = client['id'];
    try { await _service.startSession(form); _refresh(); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Time-limited support session started.'))); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_friendly(e)), backgroundColor: Colors.red.shade700)); }
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
}

class _SupportSessionDialog extends StatefulWidget { final String clientName; const _SupportSessionDialog({required this.clientName}); @override State<_SupportSessionDialog> createState() => _SupportSessionDialogState(); }
class _SupportSessionDialogState extends State<_SupportSessionDialog> {
  final _form = GlobalKey<FormState>(); final _reason = TextEditingController(); final _ticket = TextEditingController();
  String _mode = 'READ_ONLY'; int _minutes = 60;
  @override Widget build(BuildContext context) => AlertDialog(title: Text('Support access: ${widget.clientName}'), content: SizedBox(width: 480, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('Access is time-limited and fully audited. Read-only is recommended for first-line diagnosis.'), const SizedBox(height: 16),
    TextFormField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Access reason'), validator: (v) => v?.trim().isEmpty == true ? 'Reason is required' : null),
    const SizedBox(height: 12), TextFormField(controller: _ticket, decoration: const InputDecoration(labelText: 'Ticket reference (optional)')),
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
