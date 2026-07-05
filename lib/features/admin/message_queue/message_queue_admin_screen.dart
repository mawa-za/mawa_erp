import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/api_client.dart';

class MessageQueueAdminScreen extends StatefulWidget {
  const MessageQueueAdminScreen({super.key});

  @override
  State<MessageQueueAdminScreen> createState() => _MessageQueueAdminScreenState();
}

class _MessageQueueAdminScreenState extends State<MessageQueueAdminScreen> {
  final _api = ApiClient();
  final _referenceController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await _api.get('/v2/message-queue', queryParameters: {
        if (_status != 'ALL') 'status': _status,
        if (_type.trim().isNotEmpty) 'type': _type.trim(),
        if (_referenceController.text.trim().isNotEmpty) 'reference': _referenceController.text.trim(),
        'size': 100,
      });
      if (response.statusCode == 200) {
        final decoded = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
        final list = decoded['items'] as List? ?? const [];
        _items = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } else {
        throw Exception(response.body);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load queue: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _retry(num id) async {
    final response = await _api.post('/v2/message-queue/$id/retry');
    if (response.statusCode != 200) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Retry failed: ${response.body}')));
    }
    await _load();
  }

  Future<void> _processNow() async {
    final response = await _api.post('/v2/message-queue/process-now');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.statusCode == 200 ? 'Queue processing triggered' : 'Failed: ${response.body}')));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Queue Administration'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(onPressed: _processNow, icon: const Icon(Icons.play_arrow)),
        ],
      ),
      body: Column(
        children: [
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
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const ['ALL', 'PENDING', 'RETRY_WAIT', 'PROCESSED', 'FAILED']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (value) { setState(() => _status = value ?? 'ALL'); _load(); },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    decoration: const InputDecoration(labelText: 'Type', hintText: 'FNB-EFT-PAYMENT', border: OutlineInputBorder()),
                    onChanged: (value) => _type = value,
                    onSubmitted: (_) => _load(),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _referenceController,
                    decoration: const InputDecoration(labelText: 'Reference', border: OutlineInputBorder()),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.search), label: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('No message queue entries found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) => _buildCard(_items[index]),
                      ),
          ),
        ],
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
                Expanded(child: Text('${item['type'] ?? ''} #$id', style: const TextStyle(fontWeight: FontWeight.bold))),
                Chip(label: Text(status)),
              ],
            ),
            Text('Reference: ${item['referenceNo'] ?? item['referenceId'] ?? ''}'),
            Text('Retry count: ${item['retryCount'] ?? 0}'),
            Text('Next attempt: ${item['nextAttemptAt'] ?? ''}'),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Payload'),
              children: [Align(alignment: Alignment.centerLeft, child: SelectableText(item['payload']?.toString() ?? ''))],
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
