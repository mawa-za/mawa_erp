import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/communication.dart';
import '../services/communication_service.dart';

class CommunicationListScreen extends StatefulWidget {
  const CommunicationListScreen({super.key});

  @override
  State<CommunicationListScreen> createState() => _CommunicationListScreenState();
}

class _CommunicationListScreenState extends State<CommunicationListScreen> {
  final CommunicationService _service = CommunicationService();
  bool _isLoading = true;
  List<Communication> _communications = [];

  @override
  void initState() {
    super.initState();
    _fetchCommunications();
  }

  Future<void> _fetchCommunications() async {
    setState(() => _isLoading = true);
    final results = await _service.getCommunications();
    setState(() {
      _communications = results;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Communications'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCommunications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _communications.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _communications.length,
                  itemBuilder: (context, index) {
                    final comm = _communications[index];
                    return _buildCommunicationCard(comm, colorScheme);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {}, // Implementation for creating new communication
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.campaign_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No communications found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Create First Communication'),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunicationCard(Communication comm, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTypeChip(comm.type),
                  _buildStatusChip(comm.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                comm.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                comm.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.people_outline, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text('Reach: ${comm.reachCount}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const Spacer(),
                  if (comm.scheduledAt != null)
                    Text(
                      'Scheduled: ${DateFormat('MMM d, HH:mm').format(comm.scheduledAt!)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(CommunicationType type) {
    Color color = Colors.blue;
    if (type == CommunicationType.announcement) color = Colors.orange;
    if (type == CommunicationType.campaign) color = Colors.purple;
    if (type == CommunicationType.notice) color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        type.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatusChip(CommunicationStatus status) {
    Color color = Colors.grey;
    if (status == CommunicationStatus.sent) color = Colors.green;
    if (status == CommunicationStatus.scheduled) color = Colors.blue;

    return Text(
      status.name.toUpperCase(),
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
    );
  }
}
