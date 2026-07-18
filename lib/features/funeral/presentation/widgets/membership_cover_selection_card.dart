import 'package:flutter/material.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_enums.dart';
import 'funeral_money_text.dart';

class MembershipCoverSelectionCard extends StatelessWidget {
  final FuneralMembershipCoverDto cover;
  final bool isSelected;
  final VoidCallback onTap;

  const MembershipCoverSelectionCard({
    super.key,
    required this.cover,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLocal = cover.coverSource == CoverSource.LOCAL_TENANT;
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected 
          ? BorderSide(color: theme.primaryColor, width: 2)
          : BorderSide(color: Colors.grey.shade300),
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
                children: [
                  Expanded(
                    child: Text(
                      cover.burialSocietyName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onTap(),
                    activeColor: theme.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Membership: ${cover.membershipNumber}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLocal ? Colors.green.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isLocal ? 'LOCAL_TENANT' : 'EXTERNAL_TENANT',
                      style: TextStyle(
                        color: isLocal ? Colors.green : Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end,children:[
                    const Text('Funeral benefit',style:TextStyle(fontSize:10,color:Colors.grey)),FuneralMoneyText(cents:cover.funeralAmountCents>0?cover.funeralAmountCents:cover.coverAmountCents,style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.green)),
                    const SizedBox(height:4),const Text('Combination benefit',style:TextStyle(fontSize:10,color:Colors.grey)),FuneralMoneyText(cents:cover.combinationAmountCents,style:const TextStyle(fontWeight:FontWeight.bold,color:Colors.blue)),
                  ]),
                ],
              ),
              if (!isLocal && cover.sourceTenantName != null) ...[
                const SizedBox(height: 8),
                Text('Source: ${cover.sourceTenantName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
