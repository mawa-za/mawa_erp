import 'package:flutter/material.dart';
import '../../data/models/funeral_package_dto.dart';
import '../../../../core/utils/formatters.dart';

class FuneralPackageSelector extends StatelessWidget {
  final List<FuneralPackageDto> packages;
  final FuneralPackageDto? selectedPackage;
  final ValueChanged<FuneralPackageDto> onSelected;

  const FuneralPackageSelector({
    super.key,
    required this.packages,
    this.selectedPackage,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Funeral Package', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        ...packages.map((package) {
          final isSelected = selectedPackage?.id == package.id;
          return Card(
            elevation: isSelected ? 4 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected 
                ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
                : BorderSide.none,
            ),
            child: ListTile(
              title: Text(package.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Formatters.formatCentsAsRand(package.basePriceCents)),
                  if (package.inclusions.isNotEmpty)
                    Text('Includes: ${package.inclusions.join(', ')}', 
                         style: const TextStyle(fontSize: 12)),
                ],
              ),
              trailing: isSelected 
                ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                : null,
              onTap: () => onSelected(package),
            ),
          );
        }),
      ],
    );
  }
}
