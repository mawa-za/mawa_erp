import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../models/device_sync_submission.dart';
import '../services/device_sync_service.dart';

class DeviceSyncWorkcenterScreen extends StatefulWidget {
  const DeviceSyncWorkcenterScreen({super.key});

  @override
  State<DeviceSyncWorkcenterScreen> createState() => _DeviceSyncWorkcenterScreenState();
}

class _DeviceSyncWorkcenterScreenState extends State<DeviceSyncWorkcenterScreen> {
  final _service = DeviceSyncService();
  final _search = TextEditingController();
  List<DeviceSyncSubmission> _items = const [];
  bool _loading = true;
  String _status = 'CORRECTION_REQUIRED';

  static const _statuses = ['ALL', 'RECEIVED', 'PROCESSING', 'COMPLETED', 'CORRECTION_REQUIRED', 'PROCESSING_FAILED'];

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.list(status: _status, search: _search.text);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Failed to load device sync submissions: $e'))));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  String _pretty(dynamic value) => const JsonEncoder.withIndent('  ').convert(value);
  String _date(DateTime? value) => value == null ? '—' : DateFormat('dd MMM yyyy HH:mm').format(value.toLocal());

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'COMPLETED': return Colors.green;
      case 'CORRECTION_REQUIRED': return Colors.orange;
      case 'PROCESSING_FAILED': return Theme.of(context).colorScheme.error;
      case 'PROCESSING': return Colors.blue;
      default: return Colors.blueGrey;
    }
  }

  Future<void> _open(DeviceSyncSubmission item) async {
    var current = await _service.get(item.submissionId);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (dialogContext) {
      return StatefulBuilder(builder: (context, setDialogState) {
        Future<void> refresh() async { final updated = await _service.get(current.submissionId); setDialogState(() => current = updated); }
        Future<void> correct() async {
          final controller = TextEditingController(text: _pretty(current.requestPayload));
          final accepted = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
            title: const Text('Correct submitted payload'),
            content: SizedBox(width: 760, height: 480, child: TextField(controller: controller, expands: true, maxLines: null, minLines: null, keyboardType: TextInputType.multiline, decoration: const InputDecoration(border: OutlineInputBorder(), helperText: 'Enter valid JSON. The original backend record remains identifiable by its submission and idempotency keys.'))),
            actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save correction'))],
          ));
          if (accepted != true) return;
          try { current = await _service.correct(current.submissionId, jsonDecode(controller.text)); setDialogState(() {}); }
          catch (e) { if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Correction failed: $e')))); }
        }
        Future<void> reprocess() async {
          try { current = await _service.reprocess(current.submissionId); setDialogState(() {}); }
          catch (e) { if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage('Reprocessing failed: $e')))); }
        }
        return AlertDialog(
          title: Row(children: [Expanded(child: Text('Device Sync ${current.submissionId}')), IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
          content: SizedBox(width: 900, height: 620, child: ListView(children: [
            Wrap(spacing: 16, runSpacing: 10, children: [
              _fact('Status', current.status), _fact('Device', current.deviceId ?? '—'), _fact('Submitted by', current.submittedBy ?? '—'), _fact('Attempts', '${current.attemptCount}'), _fact('Created', _date(current.createdAt)), _fact('HTTP', '${current.method} ${current.path}'),
            ]),
            if ((current.errorMessage ?? '').isNotEmpty) ...[const SizedBox(height: 16), Text('Processing error', style: Theme.of(context).textTheme.titleMedium), SelectableText(current.errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error))],
            const SizedBox(height: 16), Text('Submitted payload', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), _jsonPanel(_pretty(current.requestPayload)),
            const SizedBox(height: 16), Text('Backend response', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 6), _jsonPanel(_pretty(current.responsePayload)),
          ])),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close')), OutlinedButton.icon(onPressed: correct, icon: const Icon(Icons.edit), label: const Text('Correct payload')), FilledButton.icon(onPressed: reprocess, icon: const Icon(Icons.replay), label: const Text('Reprocess'))],
        );
      });
    });
    await _load();
  }

  Widget _fact(String label, String value) => SizedBox(width: 250, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), SelectableText(value)]));
  Widget _jsonPanel(String text) => Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MawaPay Device Sync'), actions: [IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh))]),
    body: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: TextField(controller: _search, onSubmitted: (_) => _load(), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search submission, device, user, endpoint or error', border: OutlineInputBorder()))),
        const SizedBox(width: 12), SizedBox(width: 230, child: DropdownButtonFormField<String>(initialValue: _status, decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()), items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(), onChanged: (v) { if (v != null) { setState(() => _status = v); _load(); } })),
        const SizedBox(width: 12), FilledButton.icon(onPressed: _load, icon: const Icon(Icons.filter_alt), label: const Text('Apply')),
      ]))),
      const SizedBox(height: 12),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : _items.isEmpty ? const Center(child: Text('No device sync submissions match the selected filters.')) : ListView.separated(
        itemCount: _items.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (context, index) { final item = _items[index]; final color = _statusColor(context, item.status); return Card(child: ListTile(
          leading: CircleAvatar(backgroundColor: color.withValues(alpha: .15), child: Icon(Icons.sync_problem, color: color)),
          title: Text('${item.method} ${item.path}', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${item.submissionId} • ${item.deviceId ?? 'Unknown device'} • ${_date(item.createdAt)}\n${item.errorMessage ?? 'No processing error'}', maxLines: 3, overflow: TextOverflow.ellipsis),
          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text(item.status.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, color: color)), Text('${item.attemptCount} attempt${item.attemptCount == 1 ? '' : 's'}')]),
          isThreeLine: true, onTap: () => _open(item),
        )); },
      )),
    ])),
  );
}
