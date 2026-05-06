import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import 'add_member_screen.dart';
import 'membership_detail_screen.dart';

class MemberListScreen extends StatefulWidget {
  const MemberListScreen({super.key});

  @override
  State<MemberListScreen> createState() => _MemberListScreenState();
}

class _MemberListScreenState extends State<MemberListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  List<Membership> _memberships = [];
  Map<String, MembershipPlan> _plans = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _error == null) {
        _fetchNextPage();
      }
    }
  }

  Future<void> _fetchInitialData() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _memberships = [];
      _hasMore = true;
    });

    try {
      final results = await Future.wait([
        MembershipService().getMemberships(page: _currentPage, size: _pageSize, sort: ['createdAt,desc']),
        MembershipService().getMembershipPlans(),
      ]);

      final memberships = results[0] as List<Membership>;
      final plans = results[1] as List<MembershipPlan>;

      if (mounted) {
        setState(() {
          _memberships = memberships;
          _plans = {for (var p in plans) p.id: p};
          _hasMore = memberships.length == _pageSize;
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

  Future<void> _fetchNextPage() async {
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final newMemberships = await MembershipService().getMemberships(
        page: nextPage, 
        size: _pageSize, 
        sort: ['createdAt,desc']
      );

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _memberships.addAll(newMemberships);
          _hasMore = newMemberships.length == _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          // We don't set global error here to not hide existing data
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading more: $e'), behavior: SnackBarBehavior.floating),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Memberships', style: TextStyle(fontWeight: FontWeight.bold)),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchInitialData,
            tooltip: 'Refresh',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget(colorScheme)
                    : _memberships.isEmpty
                        ? _buildEmptyWidget()
                        : _buildMembershipList(colorScheme),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
          );
          if (result == true) {
            _fetchInitialData();
          }
        },
        label: const Text('Link Member'),
        icon: const Icon(Icons.add_link_rounded),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        onSubmitted: (value) {
          // In a real paginated search, we'd trigger a fresh fetch with search query
          // For now, we'll just refresh initial data (assuming API supports search)
          _fetchInitialData();
        },
        decoration: InputDecoration(
          hintText: 'Search by policy #, member ID or plan...',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _fetchInitialData();
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          fillColor: const Color(0xFFF1F3F4),
          filled: true,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load memberships', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchInitialData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contact_emergency_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No memberships found', 
            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          const Text('Create a new membership to see it here', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildMembershipList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _memberships.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _memberships.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          
          final membership = _memberships[index];
          final plan = _plans[membership.planId];
          return _buildMembershipCard(membership, plan, colorScheme);
        },
      ),
    );
  }

  Widget _buildMembershipCard(Membership membership, MembershipPlan? plan, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => MembershipDetailScreen(membershipId: membership.id),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Policy: ${membership.membershipNo}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    _buildStatusChip(membership.status),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  plan?.name ?? 'Plan: ${membership.planId}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Member ID: ${membership.memberId}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('START DATE', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(membership.startDate ?? '-', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    if (plan != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('MONTHLY PREMIUM', style: TextStyle(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          const SizedBox(height: 2),
                          Text(
                            'R ${plan.premium.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: colorScheme.primary)
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        color = Colors.green;
        break;
      case 'WAITING-PERIOD':
      case 'UPGRADE-WAITING-PERIOD':
        color = Colors.orange;
        break;
      case 'INACTIVE':
        color = Colors.red;
        break;
      case 'NEW':
      case 'AWAITING-APPROVAL':
        color = Colors.blue;
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
        status.replaceAll('-', ' '),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
