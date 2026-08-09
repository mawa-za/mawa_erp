import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_error.dart';
import '../models/device_crash_log.dart';
import '../services/device_crash_log_service.dart';

class DeviceCrashLogScreen extends StatefulWidget {
  const DeviceCrashLogScreen({super.key});

  @override
  State<DeviceCrashLogScreen> createState() => _DeviceCrashLogScreenState();
}

class _DeviceCrashLogScreenState extends State<DeviceCrashLogScreen> {
  final _service = DeviceCrashLogService();
  final _search = TextEditingController();
  List<DeviceCrashLog> _items = const [];
  bool _loading = true;

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
    setState(() => _loading = true);
    try {
      final items = await _service.list(search: _search.text);
      if (mounted) setState(() => _items = items);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to load MawaPay crash logs: $error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(DateTime? value) => value == null
      ? '—'
      : DateFormat('dd MMM yyyy HH:mm:ss').format(value.toLocal());

  String _pretty(dynamic value) {
    if (value == null) return '—';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Future<void> _open(DeviceCrashLog item) async {
    DeviceCrashLog current;
    try {
      current = await _service.get(item.logId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Failed to load crash details: $error'))),
        );
      }
      return;
    }
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('MawaPay Crash ${current.logId}'),
        content: SizedBox(
          width: 960,
          height: 680,
          child: ListView(
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _fact('Crash time', _date(current.occurredAt)),
                  _fact('Device serial', current.deviceSerialNumber ?? '—'),
                  _fact('Device ID', current.deviceId ?? '—'),
                  _fact('User', current.userId ?? '—'),
                  _fact('Source', current.source),
                  _fact('App version', current.appVersion ?? '—'),
                  _fact('Device model', current.deviceModel ?? '—'),
                  _fact('OS', current.osVersion ?? '—'),
                  _fact('Received', _date(current.receivedAt)),
                ],
              ),
              const SizedBox(height: 18),
              Text('Error', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _panel([
                if ((current.errorType ?? '').isNotEmpty) current.errorType!,
                if ((current.errorMessage ?? '').isNotEmpty) current.errorMessage!,
              ].join('\n')),
              const SizedBox(height: 18),
              Text('Stack trace', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _panel(current.stackTrace ?? '—'),
              const SizedBox(height: 18),
              Text('Additional details', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              _panel(_pretty(current.details)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _fact(String label, String value) => SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
            SelectableText(value),
          ],
        ),
      );

  Widget _panel(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('MawaPay Device Crash Logs'),
          actions: [
            IconButton(onPressed: _load, tooltip: 'Refresh', icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onSubmitted: (_) => _load(),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            labelText: 'Search serial, device, user, error, source or model',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.search),
                        label: const Text('Search'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _items.isEmpty
                        ? const Center(child: Text('No MawaPay device crash logs found.'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final serial = item.deviceSerialNumber ?? item.deviceId ?? 'Unknown device';
                              final message = (item.errorMessage ?? '').trim();
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context).colorScheme.errorContainer,
                                    child: Icon(
                                      Icons.bug_report_outlined,
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                                  ),
                                  title: Text(
                                    '${item.errorType ?? 'Application crash'} • $serial',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${_date(item.occurredAt)} • ${item.source} • ${item.appVersion ?? 'version unknown'}\n${message.isEmpty ? 'No error message recorded' : message}',
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  isThreeLine: true,
                                  onTap: () => _open(item),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      );
}
