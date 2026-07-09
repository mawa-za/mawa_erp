import 'package:flutter/material.dart';
import '../../data/models/funeral_membership_cover_dto.dart';
import '../../data/models/funeral_enums.dart';
import 'funeral_money_text.dart';

class MembershipCoverSelectionCard extends StatelessWidget {
  final FuneralMembershipCoverDto cover;
  final bool isSelected;
  final VoidCallback onTap;
  final String claimType;
  final bool disabled;
  final String? disabledReason;

  const MembershipCoverSelectionCard({
    super.key,
    required this.cover,
    required this.isSelected,
    required this.onTap,
    this.claimType = 'FUNERAL',
    this.disabled = false,
    this.disabledReason,
  });

  @override
  Widget build(BuildContext context) {
    final isLocal = cover.coverSource == CoverSource.LOCAL_TENANT;
    final theme = Theme.of(context);
    final effectiveClaimType = claimType.toUpperCase() == 'COMBINATION' ? 'COMBINATION' : 'FUNERAL';

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
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
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
                      onChanged: disabled ? null : (_) => onTap(),
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
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'USING $effectiveClaimType',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _AmountTile(
                        label: 'FUNERAL',
                        amountCents: cover.funeralAmountCents,
                        highlighted: isSelected && effectiveClaimType == 'FUNERAL',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AmountTile(
                        label: 'COMBINATION',
                        amountCents: cover.combinationAmountCents,
                        highlighted: isSelected && effectiveClaimType == 'COMBINATION',
                      ),
                    ),
                  ],
                ),
                if (!isLocal && cover.sourceTenantName != null) ...[
                  const SizedBox(height: 8),
                  Text('Source: ${cover.sourceTenantName}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
                if (disabled && disabledReason != null && disabledReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    disabledReason!,
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final int amountCents;
  final bool highlighted;

  const _AmountTile({
    required this.label,
    required this.amountCents,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlighted ? theme.colorScheme.primary.withOpacity(0.08) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlighted ? theme.colorScheme.primary : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          FuneralMoneyText(
            cents: amountCents,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: highlighted ? theme.colorScheme.primary : Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
