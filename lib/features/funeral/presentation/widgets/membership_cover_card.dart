import 'package:flutter/material.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_enums.dart';
import '../../../../core/utils/formatters.dart';

class MembershipCoverCard extends StatelessWidget {
  final FuneralMembershipCoverDto cover;
  final bool isSelected;
  final VoidCallback onTap;

  const MembershipCoverCard({
    super.key,
    required this.cover,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocal = cover.coverSource == CoverSource.LOCAL_TENANT;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
          : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cover.burialSocietyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: Theme.of(context).primaryColor),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Membership: ${cover.membershipNumber}'),
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
                ],
              ),
              const SizedBox(height: 4),
              if (!isLocal && cover.sourceTenantName != null)
                Text('Source: ${cover.sourceTenantName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Cover Amount:'),
                  Text(
                    Formatters.formatCentsAsRand(cover.coverAmountCents),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
