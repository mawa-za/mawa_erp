import 'package:flutter/material.dart';
import '../../data/models/funeral_enums.dart';

class FuneralStatusChip extends StatelessWidget {
  final dynamic status;

  const FuneralStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = _normalizeStatus(status);
    final label = _labelFor(normalized);
    final color = _colorFor(normalized);

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

  dynamic _normalizeStatus(dynamic value) {
    if (value == null) return null;
    if (value is PickupStatus || value is MortuaryStatus || value is ClaimStatus) {
      return value;
    }
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      final upper = text.toUpperCase();

      for (final item in PickupStatus.values) {
        if (_enumLabel(item) == upper) return item;
      }
      for (final item in MortuaryStatus.values) {
        if (_enumLabel(item) == upper) return item;
      }
      for (final item in ClaimStatus.values) {
        if (_enumLabel(item) == upper) return item;
      }
      return upper;
    }

    return value.toString().split('.').last.toUpperCase();
  }

  String _labelFor(dynamic value) {
    if (value == null) return 'UNKNOWN';
    if (value is PickupStatus || value is MortuaryStatus || value is ClaimStatus) {
      return _enumLabel(value);
    }
    return value.toString().split('.').last.toUpperCase();
  }

  Color _colorFor(dynamic value) {
    if (value is PickupStatus) {
      switch (value) {
        case PickupStatus.PENDING:
          return Colors.orange;
        case PickupStatus.ASSIGNED:
          return Colors.blue;
        case PickupStatus.COMPLETED:
          return Colors.green;
        case PickupStatus.CANCELLED:
          return Colors.red;
      }
    }

    if (value is MortuaryStatus) {
      switch (value) {
        case MortuaryStatus.IN_STORAGE:
        case MortuaryStatus.IN_MORTUARY:
          return Colors.purple;
        case MortuaryStatus.CHECKED_OUT:
        case MortuaryStatus.RELEASED:
          return Colors.green;
        case MortuaryStatus.CANCELLED:
          return Colors.red;
      }
    }

    if (value is ClaimStatus) {
      switch (value) {
        case ClaimStatus.PENDING:
          return Colors.orange;
        case ClaimStatus.APPROVED:
          return Colors.green;
        case ClaimStatus.PARTIALLY_APPROVED:
          return Colors.blue;
        case ClaimStatus.REJECTED:
          return Colors.red;
        case ClaimStatus.CANCELLED:
          return Colors.grey;
      }
    }

    final label = _labelFor(value);
    switch (label) {
      case 'PENDING':
        return Colors.orange;
      case 'ASSIGNED':
      case 'PARTIALLY_APPROVED':
        return Colors.blue;
      case 'COMPLETED':
      case 'APPROVED':
      case 'RELEASED':
      case 'CHECKED_OUT':
        return Colors.green;
      case 'IN_STORAGE':
      case 'IN_MORTUARY':
        return Colors.purple;
      case 'CANCELLED':
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _enumLabel(Object value) {
    // Do not use dynamic .name access here. In Flutter web this was compiled as a
    // dynamic call when the widget received a custom enum value and caused:
    // NoSuchMethodError: 'name' method not found on PickupStatus.
    return value.toString().split('.').last.toUpperCase();
  }
}
