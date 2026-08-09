import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_dashboard_summary.dart';
import '../services/case_management_service.dart';
import 'case_list_screen.dart';
import 'create_case_screen.dart';
import 'overdue_tasks_screen.dart';
import 'upcoming_events_screen.dart';
import 'unbilled_cases_screen.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

class CaseDashboardScreen extends StatefulWidget {
  const CaseDashboardScreen({super.key});

  @override
  State<CaseDashboardScreen> createState() => _CaseDashboardScreenState();
}

class _CaseDashboardScreenState extends State<CaseDashboardScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  CaseDashboardSummary? _summary;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _caseService.getDashboardSummary();
      setState(() {
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage('Error loading dashboard: $e')), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCents(int cents) {
    return NumberFormat.currency(symbol: 'R ', locale: 'en_ZA').format(cents / 100);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Case Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchSummary,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSummary,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(),
                    const SizedBox(height: 32),
                    _buildQuickActions(colorScheme),
                    const SizedBox(height: 32),
                    _buildSummaryGrid(isDesktop, colorScheme),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Case Management Overview',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
        ),
        const SizedBox(height: 4),
        Text(
          'Track your legal matters and practice performance',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildQuickActions(ColorScheme colorScheme) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildActionButton(
          'New Case',
          Icons.add_box_rounded,
          colorScheme.primary,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CreateCaseScreen())).then((_) => _fetchSummary()),
        ),
        _buildActionButton(
          'View Cases',
          Icons.list_alt_rounded,
          Colors.blueGrey,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CaseListScreen())),
        ),
        _buildActionButton(
          'Overdue Tasks',
          Icons.assignment_late_rounded,
          Colors.redAccent,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OverdueTasksScreen())),
        ),
        _buildActionButton(
          'Upcoming Events',
          Icons.event_note_rounded,
          Colors.orange,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UpcomingEventsScreen())),
        ),
        _buildActionButton(
          'Unbilled Matters',
          Icons.receipt_long_rounded,
          Colors.green,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const UnbilledCasesScreen())),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryGrid(bool isDesktop, ColorScheme colorScheme) {
    if (_summary == null) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: isDesktop ? 4 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 20,
      mainAxisSpacing: 20,
      childAspectRatio: 1.5,
      children: [
        _buildSummaryCard('Open Cases', _summary!.totalOpenCases.toString(), Icons.folder_open_rounded, Colors.blue),
        _buildSummaryCard('In Progress', _summary!.totalInProgressCases.toString(), Icons.pending_actions_rounded, Colors.orange),
        _buildSummaryCard('Closed Cases', _summary!.totalClosedCases.toString(), Icons.folder_special_rounded, Colors.green),
        _buildSummaryCard('Overdue Tasks', _summary!.overdueTasks.toString(), Icons.assignment_late_rounded, Colors.red),
        _buildSummaryCard('Upcoming Events', _summary!.upcomingEvents.toString(), Icons.event_available_rounded, Colors.indigo),
        _buildSummaryCard('Unbilled Amount', _formatCents(_summary!.unbilledAmountCents), Icons.money_off_rounded, const Color(0xFFF20D1A)),
        _buildSummaryCard('Outstanding Balance', _formatCents(_summary!.totalBalanceCents), Icons.account_balance_wallet_rounded, Colors.teal),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}
