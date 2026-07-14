import 'package:flutter/material.dart';
import '../models/leave_request.dart';
import '../services/leave_service.dart';
import 'leave_request_create_screen.dart';
import 'leave_request_detail_screen.dart';

class LeaveRequestListScreen extends StatefulWidget {
  const LeaveRequestListScreen({super.key});

  @override
  State<LeaveRequestListScreen> createState() => _LeaveRequestListScreenState();
}

class _LeaveRequestListScreenState extends State<LeaveRequestListScreen> {
  final LeaveService _service = LeaveService();
  bool _isLoading = true;
  List<LeaveRequest> _requests = [];
  String? _error;
  String _selectedStatus = 'ALL';

  final List<String> _statuses = ['ALL', 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _service.getLeaveRequests(
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
      );
      results.sort((a, b) => (b.createdAt ?? b.startDate).compareTo(a.createdAt ?? a.startDate));
      if (mounted) {
        setState(() {
          _requests = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Leave Requests', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilter(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget()
                    : _requests.isEmpty
                        ? _buildEmptyWidget()
                        : _buildList(colorScheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaveRequestCreateScreen()),
          );
          if (result == true) _fetchRequests();
        },
        label: const Text('Request Leave'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusFilter() {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _statuses.length,
        itemBuilder: (context, index) {
          final status = _statuses[index];
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatus = status);
                  _fetchRequests();
                }
              },
              selectedColor: Theme.of(context).colorScheme.primary,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Text(request.type, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _buildStatusBadge(request.status),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${request.startDate} to ${request.endDate}', style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${request.days} day(s)', style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LeaveRequestDetailScreen(requestId: request.id)),
                );
                if (result == true) _fetchRequests();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'APPROVED': color = Colors.green; break;
      case 'REJECTED': color = Colors.red; break;
      case 'PENDING': color = Colors.orange; break;
      case 'CANCELLED': color = Colors.grey; break;
      default: color = Colors.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!),
          ElevatedButton(onPressed: _fetchRequests, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return const Center(
      child: Text('No leave requests found'),
    );
  }
}
