import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/user_service.dart';
import '../models/approval.dart';
import '../services/approval_service.dart';
import 'approval_detail_screen.dart';

class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({super.key});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApprovalService _service = ApprovalService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Approvals', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'In Progress'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ApprovalListView(status: 'PENDING', service: _service),
          _ApprovalListView(status: 'IN_PROGRESS', service: _service),
          _ApprovalListView(status: 'APPROVED', service: _service),
          _ApprovalListView(status: 'REJECTED', service: _service),
          _ApprovalListView(status: 'CANCELLED', service: _service),
        ],
      ),
    );
  }
}

class _ApprovalListView extends StatefulWidget {
  final String status;
  final ApprovalService service;

  const _ApprovalListView({required this.status, required this.service});

  @override
  State<_ApprovalListView> createState() => _ApprovalListViewState();
}

class _ApprovalListViewState extends State<_ApprovalListView> {
  bool _isLoading = true;
  List<Approval> _approvals = [];
  String? _error;
  final UserService _userService = UserService();
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _fetchApprovals();
  }

  Future<void> _fetchApprovals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await widget.service.getApprovals(status: widget.status);
      if (mounted) {
        setState(() {
          _approvals = results;
          _isLoading = false;
        });
        _resolveUserNames();
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

  void _resolveUserNames() {
    for (var approval in _approvals) {
      _resolveUserName(approval.requesterId);
    }
  }

  Future<void> _resolveUserName(String userId) async {
    if (userId.isEmpty || _userNameCache.containsKey(userId)) return;
    try {
      final user = await _userService.getUser(userId);
      if (mounted) {
        setState(() {
          _userNameCache[userId] = user.displayName ?? user.username;
        });
      }
    } catch (e) {
      debugPrint('Error resolving user $userId: $e');
    }
  }

  String _getDisplayName(String id) {
    if (_userNameCache.containsKey(id)) {
      return _userNameCache[id]!;
    }
    if (id.length > 8 && id.contains('-')) {
      return id.split('-').first;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));
    if (_approvals.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.approval_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No ${widget.status.replaceAll('_', ' ').toLowerCase()} approvals', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchApprovals,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _approvals.length,
        itemBuilder: (context, index) {
          final approval = _approvals[index];
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: ListTile(
              title: Text(approval.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(approval.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildBadge(approval.approvalType, _getTypeColor(approval.approvalType)),
                      const SizedBox(width: 8),
                      Text(approval.referenceNo, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const Spacer(),
                      Text('by ${_getDisplayName(approval.requesterId)}', 
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ApprovalDetailScreen(approval: approval),
                  ),
                );
                if (result == true) _fetchApprovals();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'CLAIM': return Colors.blue;
      case 'PAYMENT': return Colors.green;
      case 'LEAVE': return Colors.orange;
      case 'CASHUP': return Colors.purple;
      case 'INVOICE': return Colors.teal;
      case 'PURCHASE_ORDER': return Colors.indigo;
      case 'JOURNAL': return Colors.brown;
      default: return Colors.grey;
    }
  }
}
