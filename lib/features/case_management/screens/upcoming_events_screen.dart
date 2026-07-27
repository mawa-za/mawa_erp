import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/case_event.dart';
import '../services/case_management_service.dart';
import 'case_detail_screen.dart';

class UpcomingEventsScreen extends StatefulWidget {
  const UpcomingEventsScreen({super.key});

  @override
  State<UpcomingEventsScreen> createState() => _UpcomingEventsScreenState();
}

class _UpcomingEventsScreenState extends State<UpcomingEventsScreen> {
  final CaseManagementService _caseService = CaseManagementService();
  List<CaseEvent> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await _caseService.getUpcomingEvents();
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Upcoming Events', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    return _buildEventCard(event);
                  },
                ),
    );
  }

  Widget _buildEventCard(CaseEvent event) {
    final isCritical = ['HEARING', 'TRIAL', 'DEADLINE', 'FILING'].contains(event.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: isCritical ? Colors.orange.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CaseDetailScreen(caseId: event.caseId)),
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (isCritical ? Colors.orange : Colors.blue).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getEventIcon(event.eventType),
            color: isCritical ? Colors.orange : Colors.blue,
            size: 20,
          ),
        ),
        title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm').format(event.startAt),
                  style: const TextStyle(fontSize: 12),
                ),
                if (event.location != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(child: Text(event.location!, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                ],
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blueGrey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            event.eventType,
            style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type) {
      case 'HEARING':
      case 'TRIAL':
        return Icons.gavel_rounded;
      case 'MEETING':
        return Icons.groups_rounded;
      case 'CALL':
        return Icons.phone_in_talk_rounded;
      case 'DEADLINE':
      case 'FILING':
        return Icons.priority_high_rounded;
      default:
        return Icons.event_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_rounded, size: 64, color: Colors.blue.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No upcoming events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Your schedule is clear.', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
