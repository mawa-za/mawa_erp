import 'package:flutter/material.dart';
import '../models/pos_printing_models.dart';
import '../services/pos_printing_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class PosPrintJobMonitorScreen extends StatefulWidget {
  const PosPrintJobMonitorScreen({super.key});
  @override
  State<PosPrintJobMonitorScreen> createState() => _PosPrintJobMonitorScreenState();
}

class _PosPrintJobMonitorScreenState extends State<PosPrintJobMonitorScreen> {
  final _service = PosPrintingService();
  List<PosPrintJob> _jobs = const [];
  bool _loading = true;
  bool _problemsOnly = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final jobs = await _service.getJobs();
      if (mounted) setState(() => _jobs = jobs);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry(PosPrintJob job, bool reroute) async {
    try {
      await _service.retryJob(job.id, reroute: reroute);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        reroute ? 'Job rerouted to the terminal’s current printer.' : 'Print job queued for retry.')));
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(friendlyErrorMessage(error)), backgroundColor: Colors.red));
    }
  }

  Color _colour(PosPrintJob job) {
    if (job.status == 'SPOOLED') return Colors.green;
    if (job.failed) return Colors.red;
    if (job.aged) return Colors.orange.shade900;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _problemsOnly
        ? _jobs.where((j) => j.status != 'SPOOLED').toList()
        : _jobs;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Print Jobs'), actions: [
        IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'),
      ]),
      body: _loading && _jobs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
              SwitchListTile.adaptive(
                title: const Text('Show problems only'),
                subtitle: Text('${_jobs.where((j) => j.status != 'SPOOLED').length} open or failed job(s)'),
                value: _problemsOnly,
                onChanged: (value) => setState(() => _problemsOnly = value),
              ),
              if (_error != null) Card(color: Colors.red.shade50, child: Padding(
                padding: const EdgeInsets.all(12), child: Text(_error!, style: TextStyle(color: Colors.red.shade900)))),
              if (visible.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No print jobs match this view.'))),
              ...visible.map((job) => Card(child: ExpansionTile(
                leading: Icon(job.failed ? Icons.error_outline : job.aged ? Icons.schedule : job.status == 'SPOOLED' ? Icons.check_circle_outline : Icons.print_outlined, color: _colour(job)),
                title: Text('${job.sourceType.replaceAll('_', ' ')} • ${job.status}', style: TextStyle(fontWeight: FontWeight.w700, color: _colour(job))),
                subtitle: Text('${job.printerQueueName.isEmpty ? 'Printer unavailable' : job.printerQueueName}\nCreated ${job.createdAt ?? 'unknown'} • Attempt ${job.attemptCount}/${job.maxAttempts}'),
                children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText('Job: ${job.id}\nReceipt: ${job.receiptId ?? '—'}\nTerminal: ${job.terminalId}\nAgent: ${job.agentId}'),
                  if ((job.lastError ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(job.lastError!, style: TextStyle(color: Colors.red.shade900))),
                  if (job.status != 'SPOOLED') Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, children: [
                    OutlinedButton.icon(onPressed: () => _retry(job, false), icon: const Icon(Icons.refresh), label: const Text('Retry')),
                    FilledButton.icon(onPressed: () => _retry(job, true), icon: const Icon(Icons.alt_route), label: const Text('Reroute & retry')),
                  ])),
                ]))],
              ))),
            ])),
    );
  }
}
