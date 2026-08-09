import 'package:flutter/material.dart';

import '../../../../core/theme/mawa_design.dart';
import '../../../../core/widgets/mawa_ui.dart';
import '../../data/models/funeral_package_dto.dart';
import 'funeral_money_text.dart';

class FuneralPackageCard extends StatelessWidget {
  final FuneralPackageDto package;
  final bool isSelected;
  final VoidCallback onTap;

  const FuneralPackageCard({
    super.key,
    required this.package,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final supportingText = package.inclusions.isNotEmpty
        ? package.inclusions.take(3).join(' • ')
        : package.products.isNotEmpty
            ? '${package.products.length} configured package items'
            : 'A configured funeral package for the selected arrangement.';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFFFBFB) : MawaDesign.surface,
        borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
        border: Border.all(
          color: isSelected ? MawaDesign.red : MawaDesign.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: isSelected ? MawaDesign.cardShadow : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MawaDesign.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const MawaIconBadge(
                  icon: Icons.inventory_2_outlined,
                  color: MawaDesign.red,
                  size: 50,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 5),
                      Text(
                        supportingText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: MawaDesign.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    FuneralMoneyText(
                      cents: package.basePriceCents,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: MawaDesign.red,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              key: ValueKey('selected'),
                              color: MawaDesign.red,
                              size: 22,
                            )
                          : const Icon(
                              Icons.radio_button_unchecked_rounded,
                              key: ValueKey('unselected'),
                              color: MawaDesign.borderStrong,
                              size: 22,
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
