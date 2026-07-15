import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/api_client.dart';

class MessageQueueAdminScreen extends StatefulWidget {
  const MessageQueueAdminScreen({super.key});

  @override
  State<MessageQueueAdminScreen> createState() =>
      _MessageQueueAdminScreenState();
}

class _MessageQueueAdminScreenState extends State<MessageQueueAdminScreen> {
  final _api = ApiClient();
  final _referenceController = TextEditingController();
  final _intervalController = TextEditingController(text: '60');
  final _batchSizeController = TextEditingController(text: '10');
  final _retryDelayController = TextEditingController(text: '10');

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _scheduleLoading = false;
  bool _schedulerEnabled = true;
  String? _lastRunAt;
  String? _nextRunAt;
  String? _scheduleError;
  String _status = 'ALL';
  String _type = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _intervalController.dispose();
    _batchSizeController.dispose();
    _retryDelayController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    try {
      final response = await _api.get('/v2/message-queue/schedule');
      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final data = Map<String, dynamic>.from(
        jsonDecode(response.body) as Map,
      );
      if (!mounted) return;

      setState(() {
        _schedulerEnabled = data['enabled'] == true;
        _intervalController.text =
            ((data['intervalSeconds'] as num?)?.toInt() ?? 60).toString();
        _batchSizeController.text =
            ((data['batchSize'] as num?)?.toInt() ?? 10).toString();
        _retryDelayController.text =
            ((data['retryDelaySeconds'] as num?)?.toInt() ?? 10).toString();
        _lastRunAt = data['lastRunAt']?.toString();
        _nextRunAt = data['nextRunAt']?.toString();
        _scheduleError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _scheduleError = 'Failed to load queue schedule: $e');
    }
  }

  int _positiveInt(TextEditingController controller, int fallback) {
    final parsed = int.tryParse(controller.text.trim());
    return parsed == null || parsed <= 0 ? fallback : parsed;
  }

  Map<String, dynamic> _schedulePayload({required bool enabled}) => {
        'enabled': enabled,
        'intervalSeconds': _positiveInt(_intervalController, 60),
        'batchSize': _positiveInt(_batchSizeController, 10),
        'retryDelaySeconds': _positiveInt(_retryDelayController, 10),
      };

  Future<void> _saveSchedule() async {
    await _updateSchedule(
      enabled: _schedulerEnabled,
      successMessage: 'Queue schedule updated',
    );
  }

  Future<void> _setSchedulerEnabled(bool enabled) async {
    setState(() => _scheduleLoading = true);
    try {
      final settingsResponse = await _api.put(
        '/v2/message-queue/schedule',
        body: _schedulePayload(enabled: enabled),
      );
      if (settingsResponse.statusCode != 200) {
        throw Exception(settingsResponse.body);
      }

      final action = enabled ? 'start' : 'stop';
      final actionResponse = await _api.post(
        '/v2/message-queue/schedule/$action',
      );
      if (actionResponse.statusCode != 200) {
        throw Exception(actionResponse.body);
      }

      await _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Message queue processing started'
                  : 'Message queue processing stopped',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scheduleError = 'Schedule action failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scheduleLoading = false);
    }
  }

  Future<void> _updateSchedule({
    required bool enabled,
    required String successMessage,
  }) async {
    setState(() => _scheduleLoading = true);
    try {
      final response = await _api.put(
        '/v2/message-queue/schedule',
        body: _schedulePayload(enabled: enabled),
      );
      if (response.statusCode != 200) throw Exception(response.body);

      await _loadSchedule();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _scheduleError = 'Schedule update failed: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule update failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _scheduleLoading = false);
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _loadSchedule();
    try {
      final response = await _api.get(
        '/v2/message-queue',
        queryParameters: {
          if (_status != 'ALL') 'status': _status,
          if (_type.trim().isNotEmpty) 'type': _type.trim(),
          if (_referenceController.text.trim().isNotEmpty)
            'reference': _referenceController.text.trim(),
          'size': 100,
        },
      );
      if (response.statusCode == 200) {
        final decoded = Map<String, dynamic>.from(
          jsonDecode(response.body) as Map,
        );
        final list = decoded['items'] as List? ?? const [];
        _items = list
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load queue: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry(num id) async {
    final response = await _api.post('/v2/message-queue/$id/retry');
    if (response.statusCode != 200 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: ${response.body}')),
      );
    }
    await _load();
  }

  Future<void> _processNow() async {
    final response = await _api.post('/v2/message-queue/process-now');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.statusCode == 200
                ? 'Queue processing triggered'
                : 'Failed: ${response.body}',
          ),
        ),
      );
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Queue Administration'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Process now',
            onPressed: _processNow,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScheduleCard(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    value: _status,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      'ALL',
                      'PENDING',
                      'RETRY_WAIT',
                      'PROCESSED',
                      'FAILED',
                    ]
                        .map(
                          (e) => DropdownMenuItem(value: e, child: Text(e)),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() => _status = value ?? 'ALL');
                      _load();
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      hintText: 'FNB-EFT-PAYMENT',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => _type = value,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Reference',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(
                        child: Text('No message queue entries found.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) =>
                            _buildCard(_items[index]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard() {
    final statusColor = _schedulerEnabled ? Colors.green : Colors.grey;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Queue Scheduler',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Control automatic queue processing for the current tenant.',
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(
                    _schedulerEnabled ? Icons.play_circle : Icons.stop_circle,
                    size: 18,
                    color: statusColor,
                  ),
                  label: Text(_schedulerEnabled ? 'RUNNING' : 'STOPPED'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _intervalController,
                    decoration: const InputDecoration(
                      labelText: 'Interval seconds',
                      helperText: 'Minimum 30 seconds',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _batchSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Batch size',
                      helperText: '1 to 100',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: TextFormField(
                    controller: _retryDelayController,
                    decoration: const InputDecoration(
                      labelText: 'Retry delay seconds',
                      helperText: '5 to 3600 seconds',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _scheduleLoading ? null : _saveSchedule,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Schedule'),
                ),
                FilledButton.icon(
                  onPressed: _scheduleLoading || _schedulerEnabled
                      ? null
                      : () => _setSchedulerEnabled(true),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                OutlinedButton.icon(
                  onPressed: _scheduleLoading || !_schedulerEnabled
                      ? null
                      : () => _setSchedulerEnabled(false),
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
                if (_scheduleLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                Text('Last run: ${_lastRunAt ?? 'Never'}'),
                Text('Next run: ${_nextRunAt ?? 'Stopped'}'),
              ],
            ),
            if (_scheduleError != null) ...[
              const SizedBox(height: 8),
              Text(
                _scheduleError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final status = item['status']?.toString() ?? '';
    final id = item['id'] as num;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['type'] ?? ''} #$id',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(label: Text(status)),
              ],
            ),
            Text(
              'Reference: ${item['referenceNo'] ?? item['referenceId'] ?? ''}',
            ),
            Text('Retry count: ${item['retryCount'] ?? 0}'),
            Text('Next attempt: ${item['nextAttemptAt'] ?? ''}'),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Payload'),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(item['payload']?.toString() ?? ''),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _retry(id),
                icon: const Icon(Icons.replay),
                label: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
