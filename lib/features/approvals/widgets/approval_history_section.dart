import 'package:flutter/material.dart';
import '../../../core/utils/app_date_utils.dart';
import '../models/approval.dart';
import '../screens/approval_detail_screen.dart';
import '../services/approval_service.dart';

/// The business object's approval history: no editing or replacement of audit records.
class ApprovalHistorySection extends StatefulWidget {
  final String referenceId;
  final String? objectType;
  const ApprovalHistorySection({super.key, required this.referenceId, this.objectType});

  @override
  State<ApprovalHistorySection> createState() => _ApprovalHistorySectionState();
}

class _ApprovalHistorySectionState extends State<ApprovalHistorySection> {
  List<Approval> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ApprovalHistorySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.referenceId != widget.referenceId || oldWidget.objectType != widget.objectType) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final items = await ApprovalService().getObjectApprovalHistory(
        widget.referenceId, objectType: widget.objectType);
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Approval history could not be loaded.'; });
    }
  }

  String _date(String? value) {
    if (value == null || value.isEmpty) return 'Not recorded';
    return AppDateUtils.displayDateTimePattern(value, 'dd MMM yyyy HH:mm');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Approval history', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh approval history'),
          ]),
          if (_loading) const LinearProgressIndicator()
          else if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
          else if (_items.isEmpty) const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No approval requests are recorded for this object.'),
          )
          else ..._items.map((item) => ListTile(
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
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ApprovalDetailScreen(approval: item),
              ));
              _load();
            },
          )),
        ]),
      ),
    );
  }
}
