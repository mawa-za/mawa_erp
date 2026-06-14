import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../partners/screens/partner_list_screen.dart';
import 'communication_list_screen.dart';
import 'survey_list_screen.dart';

class InternalCommunicationsDashboard extends StatelessWidget {
  const InternalCommunicationsDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Internal Communications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEngagementSummary(colorScheme),
          const SizedBox(height: 24),
          _buildQuickActions(context, colorScheme),
          const SizedBox(height: 24),
          _buildSectionHeader('Employee Engagement'),
          const SizedBox(height: 12),
          _buildDashboardCard(
            context,
            title: 'Employee Database',
            subtitle: 'Manage internal contacts and roles',
            icon: Icons.badge_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PartnerListScreen(
                  role: 'EMPLOYEE',
                  title: 'Employee Database',
                ),
              ),
            ),
          ),
          _buildDashboardCard(
            context,
            title: 'Communications',
            subtitle: 'Newsletters, notices, and announcements',
            icon: Icons.campaign_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CommunicationListScreen()),
            ),
          ),
          _buildDashboardCard(
            context,
            title: 'Surveys & Feedback',
            subtitle: 'Pulse surveys and engagement metrics',
            icon: Icons.poll_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SurveyListScreen()),
            ),
          ),
          _buildDashboardCard(
            context,
            title: 'Engagement Reports',
            subtitle: 'Reach, participation, and metrics',
            icon: Icons.bar_chart_outlined,
            onTap: () {}, // To be implemented
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementSummary(ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Engagement Overview',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryStat('Total Reach', '85%', Icons.trending_up),
                _buildSummaryStat('Participation', '62%', Icons.people_outline),
                _buildSummaryStat('Active Surveys', '3', Icons.poll),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            context,
            'New Announcement',
            Icons.add_alert_outlined,
            colorScheme.primary,
            () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            context,
            'Create Survey',
            Icons.add_chart_outlined,
            colorScheme.secondary,
            () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[800]),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      ),
    );
  }
}
