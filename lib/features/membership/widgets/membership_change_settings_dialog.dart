import 'package:flutter/material.dart';
import '../services/membership_service.dart';

Future<void> showMembershipChangeSettingsDialog(BuildContext context) async {
  final config = await MembershipService().getMembershipChangeConfiguration();
  if (!context.mounted) return;
  final controller = TextEditingController(text: '${config.planChangeWaitingPeriodMonths}');
  final save = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Membership Change Settings'),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Waiting period before an approved membership plan upgrade or downgrade becomes effective.'),
        const SizedBox(height: 16),
        TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Waiting period (months)', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('SAVE')),
      ],
    ),
  );
  if (save == true) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 0 || value > 120) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Waiting period must be between 0 and 120 months')));
    } else {
      try {
        await MembershipService().updateMembershipChangeConfiguration(value);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Membership change settings saved')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save settings: $error'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
  controller.dispose();
}
