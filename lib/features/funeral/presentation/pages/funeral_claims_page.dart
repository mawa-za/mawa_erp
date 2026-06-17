import 'package:flutter/material.dart';
import '../../data/funeral_api.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/approve_funeral_claim_request_dto.dart';
import '../widgets/funeral_claim_card.dart';
import '../../../../core/utils/formatters.dart';

class FuneralClaimsPage extends StatefulWidget {
  final String serviceRequestId;

  const FuneralClaimsPage({super.key, required this.serviceRequestId});

  @override
  State<FuneralClaimsPage> createState() => _FuneralClaimsPageState();
}

class _FuneralClaimsPageState extends State<FuneralClaimsPage> {
  final _api = FuneralApi();
  List<FuneralClaimDto> _claims = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClaims();
  }

  Future<void> _loadClaims() async {
    setState(() => _isLoading = true);
    try {
      final claims = await _api.getClaims(widget.serviceRequestId);
      setState(() {
        _claims = claims;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading claims: $e')));
      }
    }
  }

  Future<void> _handleApproval(FuneralClaimDto claim) async {
    final amountController = TextEditingController(text: (claim.claimedAmountCents / 100).toString());
    final noteController = TextEditingController();
    
    final result = await showDialog<ApproveFuneralClaimRequestDto>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Claim'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Claimed: ${Formatters.formatCentsAsRand(claim.claimedAmountCents)}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'Approved Amount (Rand)'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: 'Note (Optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, ApproveFuneralClaimRequestDto(
              approvedAmountCents: 0,
              status: 'REJECTED',
              note: noteController.text,
            )),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reject'),
          ),
          ElevatedButton(
            onPressed: () {
              final cents = (double.tryParse(amountController.text) ?? 0 * 100).toInt();
              Navigator.pop(context, ApproveFuneralClaimRequestDto(
                approvedAmountCents: cents,
                status: cents >= claim.claimedAmountCents ? 'APPROVED' : 'PARTIALLY_APPROVED',
                note: noteController.text,
              ));
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        await _api.approveClaim(claim.id, result);
        _loadClaims();
      } catch (e) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Claims'),
        actions: [
          IconButton(onPressed: _loadClaims, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _claims.isEmpty
              ? const Center(child: Text('No claims found for this request.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _claims.length,
                  itemBuilder: (context, index) {
                    return FuneralClaimCard(
                      claim: _claims[index],
                      onApprove: () => _handleApproval(_claims[index]),
                      onReject: () => _handleApproval(_claims[index]), // Rejection handled in dialog
                    );
                  },
                ),
    );
  }
}
