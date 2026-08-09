import 'package:flutter/material.dart';

import '../models/leave_request.dart';
import '../services/leave_service.dart';
import 'leave_request_create_screen.dart';
import 'leave_request_detail_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveRequestListScreen extends StatefulWidget {
  const LeaveRequestListScreen({super.key});

  @override
  State<LeaveRequestListScreen> createState() => _LeaveRequestListScreenState();
}

class _LeaveRequestListScreenState extends State<LeaveRequestListScreen> {
  final _service = LeaveService();
  final _search = TextEditingController();
  List<LeaveRequest> _requests = const [];
  bool _loading = true;
  String? _error;
  String _status = 'ALL';

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
    setState(() { _loading = true; _error = null; });
    try {
      final requests = await _service.getLeaveRequests(status: _status);
      if (mounted) setState(() => _requests = requests);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<LeaveRequest> get _filtered {
    final term = _search.text.trim().toLowerCase();
    if (term.isEmpty) return _requests;
    return _requests.where((request) => [request.requestNumber, request.employeeName, request.employeeNumber, request.leaveTypeName, request.status]
        .join(' ').toLowerCase().contains(term)).toList();
  }

  Future<void> _create() async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const LeaveRequestCreateScreen()));
    if (changed == true) await _load();
  }

  Future<void> _open(LeaveRequest request) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => LeaveRequestDetailScreen(requestId: request.id)));
    if (changed == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Requests'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New Request')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1300),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    TextField(
                      controller: _search,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: 'Search requests', prefixIcon: Icon(Icons.search_rounded)),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, children: ['ALL', 'PENDING', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CANCELLED']
                        .map((status) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(status), selected: _status == status, onSelected: (_) { setState(() => _status = status); _load(); }))).toList())),
                  ]),
                ),
              ),
            ),
            Expanded(child: _body()),
          ]),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), const SizedBox(height: 12), FilledButton(onPressed: _load, child: const Text('Retry'))]));
    final requests = _filtered;
    if (requests.isEmpty) return const Center(child: Text('No leave requests found.'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        itemCount: requests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final request = requests[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(18),
              leading: const CircleAvatar(child: Icon(Icons.beach_access_outlined)),
              title: Text('${request.requestNumber} • ${request.leaveTypeName}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${request.employeeName} (${request.employeeNumber})\n${request.startDate} to ${request.endDate} • ${request.amount.toStringAsFixed(2)} ${request.unit.toLowerCase()}'),
              ),
              isThreeLine: true,
              trailing: Chip(label: Text(_label(request.status))),
              onTap: () => _open(request),
            ),
          );
        },
      ),
    );
  }

  String _label(String value) => value.replaceAll(RegExp(r'[-_]+'), ' ').split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}').join(' ');
}
