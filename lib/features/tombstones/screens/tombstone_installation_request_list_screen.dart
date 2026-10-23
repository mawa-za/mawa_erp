import 'package:flutter/material.dart';
import '../services/tombstone_service.dart';
import 'tombstone_installation_request_wizard_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class TombstoneInstallationRequestListScreen extends StatefulWidget {
  final bool embedded;
  const TombstoneInstallationRequestListScreen({super.key, this.embedded = false});
  @override
  State<TombstoneInstallationRequestListScreen> createState() => _TombstoneInstallationRequestListScreenState();
}

class _TombstoneInstallationRequestListScreenState extends State<TombstoneInstallationRequestListScreen> {
  final _service = TombstoneService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      final records = await _service.installationRequests();
      if (mounted) setState(() => _requests = records);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally { if (mounted) setState(() => _loading = false); }
  }
  Future<void> _open(String? id) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TombstoneInstallationRequestWizardScreen(requestId: id),
    ));
    if (mounted) _reload();
  }
  @override
  Widget build(BuildContext context) {
    final body = Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          const Expanded(child: Text('Tombstone Installation Requests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
          IconButton(onPressed: _reload, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
          FilledButton.icon(onPressed: () => _open(null), icon: const Icon(Icons.add), label: const Text('New Request')),
        ]),
      ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
      Expanded(child: _requests.isEmpty && !_loading
        ? const Center(child: Text('No tombstone installation requests'))
        : ListView.builder(itemCount: _requests.length, itemBuilder: (context, index) {
            final item = _requests[index];
            return Card(child: ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text('${item['request_no'] ?? ''} • ${item['deceased_name'] ?? ''}'),
              subtitle: Text('${item['status'] ?? ''} • ${item['cemetery_name'] ?? ''}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(item['id']?.toString()),
            ));
          })),
    ]);
    return widget.embedded ? body : Scaffold(
      appBar: AppBar(title: const Text('Tombstone Installation Requests')),
      body: body,
    );
  }
}
