import 'package:flutter/material.dart';
import '../services/support_ticket_service.dart';

class SupportTicketScreen extends StatefulWidget {
  const SupportTicketScreen({super.key});
  @override State<SupportTicketScreen> createState() => _SupportTicketScreenState();
}

class _SupportTicketScreenState extends State<SupportTicketScreen> {
  final _service = SupportTicketService();
  late Future<List<Map<String, dynamic>>> _tickets;
  @override void initState() { super.initState(); _refresh(); }
  void _refresh() => setState(() => _tickets = _service.list());

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Support Tickets'), actions: [
      IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create, icon: const Icon(Icons.add), label: const Text('New ticket')),
    body: FutureBuilder<List<Map<String, dynamic>>>(future: _tickets, builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Text(snapshot.error.toString()));
      final tickets = snapshot.data ?? const [];
      if (tickets.isEmpty) return const Center(child: Text('No support tickets yet.'));
      return RefreshIndicator(onRefresh: () async => _refresh(), child: ListView.builder(
        padding: const EdgeInsets.all(16), itemCount: tickets.length, itemBuilder: (_, index) {
          final ticket = tickets[index];
          final breached = ticket['slaBreached'] == true;
          return Card(child: ListTile(
            leading: Icon(breached ? Icons.warning_amber_rounded : Icons.support_agent_rounded,
                color: breached ? Colors.red : null),
            title: Text(ticket['subject']?.toString() ?? 'Support ticket'),
            subtitle: Text('${ticket['ticketNo'] ?? ''} • ${_label(ticket['priority'])} • ${_label(ticket['status'])}\n'
                'Response due: ${ticket['responseDueAt'] ?? '-'}'),
            isThreeLine: true,
            trailing: breached ? const Chip(label: Text('SLA overdue')) : null,
          ));
        },
      ));
    }),
  );

  Future<void> _create() async {
    final result = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => const _NewTicketDialog());
    if (result == null) return;
    try {
      await _service.create(result); _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support ticket created.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), backgroundColor: Colors.red));
    }
  }
}

class _NewTicketDialog extends StatefulWidget {
  const _NewTicketDialog();
  @override State<_NewTicketDialog> createState() => _NewTicketDialogState();
}
class _NewTicketDialogState extends State<_NewTicketDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String _priority = 'NORMAL';
  @override Widget build(BuildContext context) => AlertDialog(
    title: const Text('New support ticket'),
    content: SizedBox(width: 520, child: Form(key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextFormField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Subject is required' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _description, maxLines: 5, decoration: const InputDecoration(labelText: 'Description'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _priority, decoration: const InputDecoration(labelText: 'Priority'),
        items: const ['LOW', 'NORMAL', 'HIGH', 'URGENT'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: (value) => setState(() => _priority = value!),),
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: () { if (_form.currentState!.validate()) Navigator.pop(context, {
        'subject': _subject.text.trim(), 'description': _description.text.trim(), 'priority': _priority, 'category': 'GENERAL',
      }); }, child: const Text('Create'))],
  );
}

String _label(Object? value) => (value?.toString() ?? '').toLowerCase().split('_')
    .map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}').join(' ');
