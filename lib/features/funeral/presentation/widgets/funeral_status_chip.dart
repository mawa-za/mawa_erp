import 'package:flutter/material.dart';
import '../../data/models/funeral_enums.dart';

class FuneralStatusChip extends StatelessWidget {
  final dynamic status;

  const FuneralStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String label = 'UNKNOWN';
    Color color = Colors.grey;

    if (status is PickupStatus) {
      label = status.name;
      switch (status as PickupStatus) {
        case PickupStatus.PENDING:
          color = Colors.orange;
          break;
        case PickupStatus.ASSIGNED:
          color = Colors.blue;
          break;
        case PickupStatus.COMPLETED:
          color = Colors.green;
          break;
        case PickupStatus.CANCELLED:
          color = Colors.red;
          break;
      }
    } else if (status is MortuaryStatus) {
      label = status.name;
      switch (status as MortuaryStatus) {
        case MortuaryStatus.IN_STORAGE:
          color = Colors.purple;
          break;
        case MortuaryStatus.RELEASED:
          color = Colors.green;
          break;
        case MortuaryStatus.CANCELLED:
          color = Colors.red;
          break;
      }
    } else if (status is ClaimStatus) {
      label = status.name;
      switch (status as ClaimStatus) {
        case ClaimStatus.PENDING:
          color = Colors.orange;
          break;
        case ClaimStatus.APPROVED:
          color = Colors.green;
          break;
        case ClaimStatus.PARTIALLY_APPROVED:
          color = Colors.blue;
          break;
        case ClaimStatus.REJECTED:
          color = Colors.red;
          break;
        case ClaimStatus.CANCELLED:
          color = Colors.grey;
          break;
      }
    } else if (status is String) {
      label = status.toString();
    }

    return Chip(
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
