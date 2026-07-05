import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FuneralDashboardPage extends StatelessWidget {
  const FuneralDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Funeral Management'),
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildMenuCard(
            context,
            'Pickup Requests',
            Icons.local_shipping_outlined,
            Colors.blue,
            () => context.push('/funeral/pickups'),
          ),
          _buildMenuCard(
            context,
            'Mortuary Inventory',
            Icons.inventory_2_outlined,
            Colors.purple,
            () => context.push('/funeral/mortuary'),
          ),
          _buildMenuCard(
            context,
            'Service Requests',
            Icons.volunteer_activism_outlined,
            Colors.green,
            () => context.push('/funeral/service-requests'),
          ),
          _buildMenuCard(
            context,
            'New Arrangement',
            Icons.add_task_outlined,
            Colors.green,
            () => context.push('/funeral/service-request/new'),
          ),
          _buildMenuCard(
            context,
            'Funeral Claims',
            Icons.request_quote_outlined,
            Colors.orange,
            // Assuming we need a way to list service requests to see claims, 
            // but the prompt says a dedicated claims page. 
            // We'll link to a list or a placeholder for now.
            () => context.push('/funeral/claims'), 
          ),
          _buildMenuCard(
            context,
            'Payments',
            Icons.payments_outlined,
            Colors.teal,
            () => context.push('/funeral/payments'),
          ),
          _buildMenuCard(
            context,
            'Package Setup',
            Icons.inventory_outlined,
            Colors.indigo,
            () => context.push('/funeral/packages/setup'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
