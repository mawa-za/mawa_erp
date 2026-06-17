import 'package:flutter/material.dart';
import '../../data/models/funeral_claim_dto.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../../../core/utils/formatters.dart';
import 'funeral_status_chip.dart';

class FuneralClaimCard extends StatelessWidget {
  final FuneralClaimDto claim;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const FuneralClaimCard({
    super.key,
    required this.claim,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = claim.status.toUpperCase() == 'PENDING';
    final isLocal = claim.coverSource == CoverSource.LOCAL_TENANT;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        claim.burialSocietyName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('Member: ${claim.membershipNumber}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                FuneralStatusChip(status: claim.status),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isLocal ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isLocal ? 'Same Tenant' : 'External Tenant',
                    style: TextStyle(
                      color: isLocal ? Colors.green : Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!isLocal && claim.sourceTenantName != null) ...[
                  const SizedBox(width: 8),
                  Text('Source: ${claim.sourceTenantName}', style: const TextStyle(fontSize: 12)),
                ],
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Claimed Amount:'),
                Text(
                  Formatters.formatCentsAsRand(claim.claimedAmountCents),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Approved Amount:'),
                Text(
                  Formatters.formatCentsAsRand(claim.approvedAmountCents),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: claim.approvedAmountCents > 0 ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            if (isPending && (onApprove != null || onReject != null)) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onReject != null)
                    TextButton(
                      onPressed: onReject,
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('Reject'),
                    ),
                  if (onApprove != null)
                    ElevatedButton(
                      onPressed: onApprove,
                      child: const Text('Review & Approve'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
