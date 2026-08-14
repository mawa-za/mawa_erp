import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';

import '../../../core/widgets/attachment_section.dart';
import '../models/leave_request.dart';
import '../services/leave_service.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class LeaveRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const LeaveRequestDetailScreen({super.key, required this.requestId});

  @override
  State<LeaveRequestDetailScreen> createState() => _LeaveRequestDetailScreenState();
}

class _LeaveRequestDetailScreenState extends State<LeaveRequestDetailScreen> {
  final _service = LeaveService();
  LeaveRequest? _request;
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final request = await _service.getLeaveRequestById(widget.requestId);
      if (mounted) setState(() => _request = request);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() => _working = true);
    try {
      await _service.submitLeaveRequest(widget.requestId);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Leave request submitted for approval.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Leave Request'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Cancellation reason')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Cancel Request')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    setState(() => _working = true);
    try {
      await _service.cancelLeaveRequest(widget.requestId, reason);
      await _load();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Request'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    final request = _request!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1050),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 16,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(request.requestNumber, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('${request.employeeName} • ${request.employeeNumber}'),
                    ]),
                    Chip(label: Text(_label(request.status))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            _section('Request information', Icons.info_outline_rounded, [
              _grid([
                ('Leave type', request.leaveTypeName),
                ('Dates', '${request.startDate} to ${request.endDate}'),
                ('Requested', '${request.amount.toStringAsFixed(2)} ${request.unit.toLowerCase()}'),
                ('Profile', request.leaveProfileName),
                ('Working calendar', request.workingCalendarName),
                ('Profile source', request.assignmentSource),
                ('Available before request', request.availableBalance.toStringAsFixed(2)),
                ('Projected balance', request.projectedBalance.toStringAsFixed(2)),
              ]),
              const SizedBox(height: 16),
              const Text('Reason', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(request.reason.isEmpty ? 'No reason recorded.' : request.reason),
              if (request.statusReason?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Text('Status reason: ${request.statusReason}'),
              ],
            ]),
            const SizedBox(height: 14),
            _section('Supporting documents', Icons.attach_file_rounded, [
              if (request.attachmentObjectIds.isEmpty)
                Text(request.supportingDocumentRequired ? 'Required supporting document has not been attached.' : 'No supporting documents attached.')
              else
                ...request.attachmentObjectIds.map((objectId) => AttachmentSection(objectId: objectId, readOnly: true)),
            ]),
            const SizedBox(height: 14),
            _section('Status history', Icons.history_rounded, [
              if (request.history.isEmpty)
                const Text('No status events recorded.')
              else
                ...request.history.map((event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle_outlined, size: 18),
                  title: Text(_label(_fieldCode(event['status']))),
                  subtitle: Text('${AppDateUtils.displayDateTime(event['changedAt'] ?? event['createdAt'])} • ${event['changedBy'] ?? '-'}${event['reason'] != null ? '\n${event['reason']}' : ''}'),
                )),
            ]),
            if (request.status == 'PENDING') ...[
              const SizedBox(height: 20),
              FilledButton.icon(onPressed: _working ? null : _submit, icon: const Icon(Icons.send_rounded), label: const Text('Submit for Approval')),
            ],
            if (['PENDING', 'SUBMITTED', 'AWAITING-APPROVAL'].contains(request.status)) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _working ? null : _cancel, icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel Request')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))]),
            const SizedBox(height: 14),
            ...children,
          ]),
        ),
      );

  Widget _grid(List<(String, String)> values) => LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth < 650 ? constraints.maxWidth : (constraints.maxWidth - 24) / 3;
        return Wrap(spacing: 12, runSpacing: 12, children: values.map((item) => SizedBox(width: width, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.$1, style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 3), Text(item.$2.isEmpty ? '—' : item.$2, style: const TextStyle(fontWeight: FontWeight.w700))]))).toList());
      });

  String _fieldCode(dynamic value) => value is Map ? (value['code'] ?? value['description'] ?? '').toString() : (value ?? '').toString();
  String _label(String value) => value.replaceAll(RegExp(r'[-_]+'), ' ').split(' ').map((part) => part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}').join(' ');
}
