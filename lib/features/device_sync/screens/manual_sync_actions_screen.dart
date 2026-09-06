import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/errors/app_error.dart';
import '../models/manual_sync_action.dart';
import '../services/manual_sync_action_service.dart';

class ManualSyncActionsScreen extends StatefulWidget {
  const ManualSyncActionsScreen({super.key});

  @override
  State<ManualSyncActionsScreen> createState() => _ManualSyncActionsScreenState();
}

class _ManualSyncActionsScreenState extends State<ManualSyncActionsScreen> {
  final _service = ManualSyncActionService();
  final _search = TextEditingController();

  List<ManualSyncAction> _items = const [];
  bool _loading = true;
  String _status = 'ATTENTION_REQUIRED';

  static const _statuses = [
    'ATTENTION_REQUIRED',
    'PENDING',
    'CORRECTION_REQUIRED',
    'FAILED',
    'PROCESSING',
    'COMPLETED',
    'REJECTED',
    'ALL',
  ];

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

  String _pretty(dynamic value) {
    if (value == null) return '—';
    try {
      final decoded = value is String ? jsonDecode(value) : value;
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = await _service.list(status: _status, search: _search.text);
      if (mounted) setState(() => _items = rows);
    } catch (error) {
      _message('Load failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyErrorMessage(text))),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return Colors.green;
      case 'FAILED':
        return Colors.red;
      case 'CORRECTION_REQUIRED':
        return Colors.orange;
      case 'PROCESSING':
        return Colors.blue;
      default:
        return Colors.blueGrey;
    }
  }

  Future<String?> _notesDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Administrator notes',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(ManualSyncAction item) async {
    var current = await _service.get(item.id);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (outerContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> correct() async {
            final controller = TextEditingController(
              text: _pretty(current.payload),
            );
            final accepted = await showDialog<bool>(
              context: dialogContext,
              builder: (correctionContext) => AlertDialog(
                title: const Text('Correct working payload'),
                content: SizedBox(
                  width: 760,
                  height: 450,
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      helperText:
                          'Identity fields are immutable. Enter valid JSON.',
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(correctionContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(correctionContext, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            if (accepted != true) return;
            try {
              current = await _service.correct(
                current.id,
                jsonDecode(controller.text),
                'Corrected in ERP',
              );
              setDialogState(() {});
            } catch (error) {
              _message('Correction failed: $error');
            }
          }

          Future<void> execute() async {
            final accepted = await showDialog<bool>(
              context: dialogContext,
              builder: (confirmationContext) => AlertDialog(
                title: const Text('Execute payload?'),
                content: Text(
                  'This will POST to ${current.endpoint} using the protected '
                  'idempotency key. The full attempt and response will be audited.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(confirmationContext, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(confirmationContext, true),
                    child: const Text('Execute'),
                  ),
                ],
              ),
            );
            if (accepted != true) return;
            try {
              current = await _service.process(current.id);
              setDialogState(() {});
            } catch (error) {
              _message('Execution failed: $error');
            }
          }

          Future<void> reject() async {
            final notes = await _notesDialog('Reject manual action');
            if (notes == null) return;
            try {
              current = await _service.reject(current.id, notes);
              setDialogState(() {});
            } catch (error) {
              _message('Rejection failed: $error');
            }
          }

          final locked = current.status == 'PROCESSING' ||
              current.status == 'COMPLETED';
          final executable = const {
            'PENDING',
            'FAILED',
            'CORRECTION_REQUIRED',
          }.contains(current.status);

          return AlertDialog(
            title: Text('Manual sync ${current.id}'),
            content: SizedBox(
              width: 900,
              height: 650,
              child: ListView(
                children: [
                  Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      _fact('Status', current.status),
                      _fact('Entity', current.entityType),
                      _fact('Device', current.deviceId),
                      _fact('Local record', current.localRecordId),
                      _fact('Request', '${current.method} ${current.endpoint}'),
                      _fact('Attempts', '${current.attemptCount}'),
                      _fact(
                        'HTTP response',
                        '${current.responseStatus ?? '—'}',
                      ),
                      _fact(
                        'Idempotency key',
                        current.idempotencyKey ?? '—',
                      ),
                    ],
                  ),
                  if ((current.failureResponse ?? '').isNotEmpty)
                    ..._section(
                      'Original device failure',
                      current.failureResponse!,
                    ),
                  if ((current.lastError ?? '').isNotEmpty)
                    ..._section('Latest execution error', current.lastError!),
                  ..._section(
                    'Original payload (read-only)',
                    _pretty(current.originalPayload),
                  ),
                  ..._section('Working payload', _pretty(current.payload)),
                  ..._section(
                    'Backend response',
                    _pretty(current.responseBody),
                  ),
                  if (current.attempts.isNotEmpty)
                    ..._section(
                      'Attempt audit history',
                      _pretty(current.attempts),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(outerContext),
                child: const Text('Close'),
              ),
              OutlinedButton.icon(
                onPressed: locked ? null : correct,
                icon: const Icon(Icons.edit),
                label: const Text('Correct payload'),
              ),
              OutlinedButton.icon(
                onPressed: locked ? null : reject,
                icon: const Icon(Icons.block),
                label: const Text('Reject'),
              ),
              FilledButton.icon(
                onPressed: executable ? execute : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Execute payload'),
              ),
            ],
          );
        },
      ),
    );
    await _load();
  }

  Widget _fact(String label, String value) => SizedBox(
        width: 250,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            SelectableText(value),
          ],
        ),
      );

  List<Widget> _section(String title, String body) => [
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            body,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MawaPay Manual Sync Corrections'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText:
                          'Search action, device, entity, endpoint or error',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _status,
                  items: _statuses
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _status = value);
                    _load();
                  },
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _load, child: const Text('Apply')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return const Center(
        child: Text('No manual sync actions match the filters.'),
      );
    }
    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items[index];
        final tone = _statusColor(item.status);
        return Card(
          child: ListTile(
            leading: Icon(Icons.build_circle, color: tone),
            title: Text('${item.method} ${item.endpoint}'),
            subtitle: Text(
              '${item.entityType} • device ${item.deviceId} • '
              'local ${item.localRecordId}\n'
              '${item.lastError ?? item.failureResponse ?? 'Awaiting administrator action'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              item.status.replaceAll('_', ' '),
              style: TextStyle(color: tone, fontWeight: FontWeight.bold),
            ),
            isThreeLine: true,
            onTap: () => _open(item),
          ),
        );
      },
    );
  }
}
