import 'package:flutter/material.dart';

class CaseStatusChip extends StatelessWidget {
  final String status;
  const CaseStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toUpperCase()) {
      case 'OPEN':
        color = Colors.blue;
        break;
      case 'IN_PROGRESS':
        color = Colors.orange;
        break;
      case 'ON_HOLD':
        color = Colors.amber;
        break;
      case 'SETTLED':
        color = Colors.purple;
        break;
      case 'CLOSED':
        color = Colors.green;
        break;
      case 'CANCELLED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
