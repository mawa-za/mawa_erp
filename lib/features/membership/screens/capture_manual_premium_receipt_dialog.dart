import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/membership_detail.dart';
import '../../partners/models/partner.dart';
import '../services/membership_service.dart';

class CaptureManualPremiumReceiptDialog extends StatefulWidget {
  final MembershipDetail membership;
  final Partner member;
  const CaptureManualPremiumReceiptDialog({super.key, required this.membership, required this.member});

  @override
  State<CaptureManualPremiumReceiptDialog> createState() => _CaptureManualPremiumReceiptDialogState();
}

class _CaptureManualPremiumReceiptDialogState extends State<CaptureManualPremiumReceiptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _book = TextEditingController();
  final _number = TextEditingController();
  final _collector = TextEditingController();
  final _location = TextEditingController();
  final _workcentre = TextEditingController();
  final _reason = TextEditingController();
  final _attachmentId = TextEditingController();
  final _notes = TextEditingController();
  DateTime _originalDate = DateTime.now();
  String _mode = 'LEGACY_CATCH_UP';
  String _paymentMethod = 'CASH';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_amount, _book, _number, _collector, _location, _workcentre, _reason, _attachmentId, _notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      await MembershipService().captureManualPremiumReceipt(
        membershipId: widget.membership.id,
        amountCents: (double.parse(_amount.text) * 100).round(),
        paymentMethod: _paymentMethod,
        originalReceiptDate: _originalDate,
        receiptBookNo: _book.text.trim(),
        manualReceiptNo: _number.text.trim(),
        originalCollector: _collector.text.trim(),
        location: _location.text.trim(),
        workcentreId: _workcentre.text.trim(),
        captureMode: _mode,
        lateCaptureReason: _reason.text.trim(),
        proofAttachmentId: _attachmentId.text.trim(),
        createdBy: prefs.getString('userId') ?? 'unknown',
        notes: _notes.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Capture Manual Premium Receipt'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${widget.member.fullName} • ${widget.membership.membershipNo}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _mode,
                decoration: const InputDecoration(labelText: 'Capture type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'LEGACY_CATCH_UP', child: Text('Outstanding legacy receipt')),
                  DropdownMenuItem(value: 'MANUAL_EMERGENCY', child: Text('Post-go-live emergency receipt')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _book, decoration: const InputDecoration(labelText: 'Receipt book number', border: OutlineInputBorder()), validator: _required)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'Receipt number', border: OutlineInputBorder()), validator: _required)),
              ]),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Original receipt date'),
                subtitle: Text('${_originalDate.year}-${_originalDate.month.toString().padLeft(2,'0')}-${_originalDate.day.toString().padLeft(2,'0')}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _originalDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                  if (d != null) setState(() => _originalDate = d);
                },
              ),
              Row(children: [
                Expanded(child: TextFormField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R ', border: OutlineInputBorder()), validator: (v) => double.tryParse(v ?? '') == null ? 'Enter a valid amount' : null)),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<String>(value: _paymentMethod, decoration: const InputDecoration(labelText: 'Payment method', border: OutlineInputBorder()), items: const ['CASH','CARD','EFT','OTHER'].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => _paymentMethod = v!))),
              ]),
              const SizedBox(height: 12),
              TextFormField(controller: _collector, decoration: const InputDecoration(labelText: 'Original collector/cashier', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location/branch', border: OutlineInputBorder()))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _workcentre, decoration: const InputDecoration(labelText: 'Workcentre ID', border: OutlineInputBorder()))),
              ]),
              if (_mode == 'MANUAL_EMERGENCY') ...[
                const SizedBox(height: 12),
                TextFormField(controller: _reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Emergency/late capture reason', border: OutlineInputBorder()), validator: _required),
                const SizedBox(height: 12),
                TextFormField(controller: _attachmentId, decoration: const InputDecoration(labelText: 'Carbon-copy proof attachment ID', helperText: 'Upload the proof under Documents first, then enter its attachment ID.', border: OutlineInputBorder()), validator: _required),
              ],
              const SizedBox(height: 12),
              TextFormField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes', border: OutlineInputBorder())),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ]),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Capture and update membership')),
      ],
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;
}
