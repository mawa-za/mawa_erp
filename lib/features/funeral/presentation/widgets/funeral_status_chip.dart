import 'package:flutter/material.dart';
import '../../data/models/funeral_enums.dart';

class FuneralStatusChip extends StatelessWidget {
  final dynamic status;

  const FuneralStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    String label;
    Color color;

    if (status is PickupStatus) {
      label = status.name;
      switch (status) {
        case PickupStatus.PENDING: color = Colors.orange;
        case PickupStatus.ASSIGNED: color = Colors.blue;
        case PickupStatus.COMPLETED: color = Colors.green;
        case PickupStatus.CANCELLED: color = Colors.red;
      }
    } else if (status is MortuaryStatus) {
      label = status.name;
      switch (status) {
        case MortuaryStatus.IN_STORAGE: color = Colors.purple;
        case MortuaryStatus.RELEASED: color = Colors.green;
        case MortuaryStatus.CANCELLED: color = Colors.red;
      }
    } else if (status is ClaimStatus) {
      label = status.name;
      switch (status) {
        case ClaimStatus.PENDING: color = Colors.orange;
        case ClaimStatus.APPROVED: color = Colors.green;
        case ClaimStatus.PARTIALLY_APPROVED: color = Colors.blue;
        case ClaimStatus.REJECTED: color = Colors.red;
        case ClaimStatus.CANCELLED: color = Colors.grey;
      }
    } else {
      label = status.toString();
      color = Colors.grey;
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
