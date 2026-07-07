import 'package:flutter/material.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../../data/models/funeral_enums.dart';
import 'funeral_money_text.dart';

class FuneralClaimApprovalDialog extends StatefulWidget {
  final FuneralClaimDto claim;

  const FuneralClaimApprovalDialog({super.key, required this.claim});

  @override
  State<FuneralClaimApprovalDialog> createState() => _FuneralClaimApprovalDialogState();
}

class _FuneralClaimApprovalDialogState extends State<FuneralClaimApprovalDialog> {
  late final TextEditingController _amountController;
  final _noteController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(text: (widget.claim.claimedAmountCents / 100).toString());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review & Approve Claim'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Burial Society: ${widget.claim.burialSocietyName}'),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Claimed: '),
                  FuneralMoneyText(cents: widget.claim.claimedAmountCents, style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(height: 24),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Approved Amount (Rand)',
                  border: OutlineInputBorder(),
                  prefixText: 'R ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final val = double.tryParse(v);
                  if (val == null) return 'Invalid number';
                  if (val < 0) return 'Cannot be negative';
                  if ((val * 100).toInt() > widget.claim.claimedAmountCents) {
                    return 'Cannot exceed claimed amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Approval Note',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
              ApproveFuneralClaimRequestDto(
                approvedAmountCents: 0,
                status: ClaimStatus.REJECTED,
                note: _noteController.text.isNotEmpty ? _noteController.text : 'Rejected by user',
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Reject'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final cents = (double.parse(_amountController.text) * 100).toInt();
              Navigator.pop(
                context,
                ApproveFuneralClaimRequestDto(
                  approvedAmountCents: cents,
                  status: cents >= widget.claim.claimedAmountCents ? ClaimStatus.APPROVED : ClaimStatus.PARTIALLY_APPROVED,
                  note: _noteController.text,
                ),
              );
            }
          },
          child: const Text('Approve'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
