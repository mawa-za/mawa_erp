import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import '../models/approval.dart';
import '../screens/approval_detail_screen.dart';
import '../services/approval_service.dart';

/// The business object's approval history: no editing or replacement of audit records.
class ApprovalHistorySection extends StatefulWidget {
  final String referenceId;
  final String? objectType;
  final int refreshRevision;
  /// Use the compact timeline presentation inside a history dialog.
  final bool timeline;
  /// Optional loader for deterministic widget testing; normal screens use the API.
  final Future<List<Approval>> Function(String referenceId, String? objectType)? historyLoader;
  const ApprovalHistorySection({
    super.key,
    required this.referenceId,
    this.objectType,
    this.refreshRevision = 0,
    this.timeline = false,
    this.historyLoader,
  });

  @override
  State<ApprovalHistorySection> createState() => _ApprovalHistorySectionState();
}

class _ApprovalHistorySectionState extends State<ApprovalHistorySection> {
  List<Approval> _items = [];
  bool _loading = true;
  String? _error;
  int _requestNumber = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ApprovalHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referenceId != widget.referenceId || oldWidget.objectType != widget.objectType || oldWidget.refreshRevision != widget.refreshRevision) {
      _load();
    }
  }

  Future<void> _load() async {
    final requestNumber = ++_requestNumber;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final items = widget.historyLoader == null
          ? await ApprovalService().getObjectApprovalHistory(
              widget.referenceId, objectType: widget.objectType)
          : await widget.historyLoader!(widget.referenceId, widget.objectType);
      if (mounted && requestNumber == _requestNumber) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted && requestNumber == _requestNumber) setState(() { _loading = false; _error = 'Approval history could not be loaded.'; });
    }
  }

  String _date(String? value) {
    if (value == null || value.isEmpty) return 'Not recorded';
    return AppDateUtils.displayDateTimePattern(value, 'dd MMM yyyy HH:mm');
  }

  Widget _timelineItem(Approval item, ColorScheme colors) {
    final status = item.status.toUpperCase();
    final approved = status == 'APPROVED';
    final rejected = status == 'REJECTED' || status == 'CANCELLED';
    final accent = approved ? Colors.green.shade700 : rejected ? colors.error : colors.primary;
    final finalized = approved || rejected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, right: 12),
            child: Column(children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: accent.withOpacity(0.10),
                child: Icon(approved ? Icons.check_circle_outline :
                    rejected ? Icons.highlight_off : Icons.schedule_outlined,
                    size: 19, color: accent),
              ),
              const SizedBox(height: 5),
              Container(width: 2, height: 28, color: colors.outlineVariant),
            ]),
          ),
          Expanded(child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openApproval(item),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: Text(item.title, style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800,
                    ))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(status.replaceAll('_', ' '), style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 10, color: accent)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text('Requested by ${item.requesterName} • ${_date(item.createdAt)}',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 5),
                  Text('${finalized ? 'Decided' : 'Last updated'}: '
                      '${_date(item.finalActionAt ?? item.updatedAt)}'
                      '${item.finalActionByName == null ? '' : ' • ${item.finalActionByName}'}',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 9),
                  Row(children: [
                    Text('VIEW REQUEST', style: TextStyle(
                      color: colors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 5),
                    Icon(Icons.arrow_forward, size: 14, color: colors.primary),
                  ]),
                ]),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Future<void> _openApproval(Approval item) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ApprovalDetailScreen(approval: item),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final content = <Widget>[
      Row(children: [
        if (!widget.timeline) ...[
          const Icon(Icons.history, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Approval History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ] else
          const Expanded(child: Text('Approval activity',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14))),
        IconButton(onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh), tooltip: 'Refresh approval history'),
      ]),
      if (_loading) const LinearProgressIndicator()
      else if (_error != null) ...[
        Text(_error!, style: TextStyle(color: colors.error)),
        TextButton.icon(onPressed: _load,
          icon: const Icon(Icons.refresh), label: const Text('RETRY')),
      ] else if (_items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text('No approval requests are recorded for this object.'),
        )
      else if (widget.timeline) ...[
        const SizedBox(height: 12),
        ..._items.map((item) => _timelineItem(item, colors)),
      ] else ..._items.map((item) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text('Requested by ${item.requesterName} • ${_date(item.createdAt)}\n'
            '${item.status == 'APPROVED' || item.status == 'REJECTED' || item.status == 'CANCELLED' ? 'Decided' : 'Last updated'}: ${_date(item.finalActionAt ?? item.updatedAt)}'
            '${item.finalActionByName == null ? '' : ' • ${item.finalActionByName}'}'),
        isThreeLine: true,
        trailing: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(item.status == 'APPROVED' ? Icons.check_circle :
              item.status == 'REJECTED' ? Icons.cancel : Icons.schedule,
            color: item.status == 'APPROVED' ? Colors.green :
                item.status == 'REJECTED' ? Colors.red : Colors.grey),
          Text(item.status.replaceAll('_', ' '), style: const TextStyle(fontSize: 10)),
        ]),
        onTap: () => _openApproval(item),
      )),
    ];
    if (widget.timeline) return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch, children: content,
    );
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
    ));
  }
}
