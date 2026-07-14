import 'package:flutter/material.dart';
import '../models/membership_claim.dart';
import '../services/membership_service.dart';
import 'membership_claim_detail_screen.dart';

class MembershipClaimListScreen extends StatefulWidget {
  const MembershipClaimListScreen({super.key});

  @override
  State<MembershipClaimListScreen> createState() => _MembershipClaimListScreenState();
}

class _MembershipClaimListScreenState extends State<MembershipClaimListScreen> {
  static const Map<String, String> _statuses = {
    'ALL': 'All',
    'DRAFT': 'Draft',
    'SUBMITTED': 'Submitted',
    'IN_PROGRESS': 'In progress',
    'APPROVED': 'Approved',
    'REJECTED': 'Rejected',
    'CANCELLED': 'Cancelled',
    'PAID': 'Paid',
  };

  final MembershipService _membershipService = MembershipService();
  final ScrollController _scrollController = ScrollController();
  final List<MembershipClaim> _claims = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _lastPage = false;
  int _page = 0;
  int _requestGeneration = 0;
  String _selectedStatus = 'ALL';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchClaims(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 240 &&
        !_isLoading &&
        !_isLoadingMore &&
        !_lastPage) {
      _fetchClaims(reset: false);
    }
  }

  Future<void> _fetchClaims({required bool reset}) async {
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    if (reset) {
      setState(() {
        _page = 0;
        _lastPage = false;
        _claims.clear();
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _membershipService.getMembershipClaimPage(
        status: _selectedStatus == 'ALL' ? null : _selectedStatus,
        page: _page,
        size: 50,
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _claims.addAll(result.items);
        _claims.sort((a, b) {
          final ad = DateTime.tryParse(a.createdAt.replaceFirst(' ', 'T'));
          final bd = DateTime.tryParse(b.createdAt.replaceFirst(' ', 'T'));
          return (bd ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(ad ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        _page = result.page + 1;
        _lastPage = result.last;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _selectStatus(String status) {
    if (_selectedStatus == status) return;
    _selectedStatus = status;
    _fetchClaims(reset: true);
  }

  Future<void> _openClaim(MembershipClaim claim) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MembershipClaimDetailScreen(claimId: claim.id),
      ),
    );
    if (result == true) _fetchClaims(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Membership Claims'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchClaims(reset: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    return Material(
      color: Colors.white,
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: _statuses.entries.map((entry) {
            final selected = entry.key == _selectedStatus;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                label: Text(entry.value),
                onSelected: (_) => _selectStatus(entry.key),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _claims.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _fetchClaims(reset: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_claims.isEmpty) {
      return Center(
        child: Text('No ${_statuses[_selectedStatus]!.toLowerCase()} claims'),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchClaims(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == _claims.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final claim = _claims[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            leading: CircleAvatar(
              child: Text(claim.claimType.isEmpty ? '?' : claim.claimType[0]),
            ),
            title: Text(
              claim.claimNo.isEmpty ? 'Membership claim' : claim.claimNo,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${claim.membershipId}\n${claim.claimDate}',
              maxLines: 2,
            ),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusChip(claim.status),
                const SizedBox(height: 4),
                Text('R ${claim.claimAmount.toStringAsFixed(2)}'),
              ],
            ),
            onTap: () => _openClaim(claim),
          );
        },
      ),
    );
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
