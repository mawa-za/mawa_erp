import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/models/paginated_response.dart';
import '../models/membership.dart';
import '../models/membership_plan.dart';
import '../services/membership_service.dart';
import '../../partners/partner_service.dart';
import '../../partners/models/partner.dart';
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
  Timer? _debounce;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;
  final int _pageSize = 20;

  List<Membership> _memberships = [];
  Map<String, MembershipPlan> _plans = {};
  Map<String, Partner> _partners = {};
  String? _error;
  List<String>? _currentMemberIds;

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
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _error == null) {
        _fetchNextPage();
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _fetchInitialData();
    });
    setState(() {});
  }

  Future<void> _fetchPartners(List<String> ids) async {
    final uniqueIds = ids.where((id) => id.isNotEmpty && !_partners.containsKey(id)).toSet();
    if (uniqueIds.isEmpty) return;

    final results = await Future.wait(
      uniqueIds.map((id) async {
        try {
          final partner = await PartnerService().getPartnerById(id);
          return MapEntry(id, partner);
        } catch (_) {
          return null;
        }
      }),
    );

    if (mounted) {
      setState(() {
        for (var entry in results) {
          if (entry != null) {
            _partners[entry.key] = entry.value;
          }
        }
      });
    }
  }

  Future<void> _fetchInitialData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 0;
      _memberships = [];
      _hasMore = true;
      _currentMemberIds = null;
    });

    try {
      final query = _searchController.text.trim();

      if (query.isNotEmpty) {
        try {
          final partners = await PartnerService().getPartnersByRole('CUSTOMER', query: query);
          _currentMemberIds = partners.map((p) => p.id).toList();

          if (mounted) {
            setState(() {
              for (var p in partners) {
                _partners[p.id] = p;
              }
            });
          }
        } catch (e) {
          debugPrint('Error fetching partners: $e');
          _currentMemberIds = [];
        }
      }

      final results = await Future.wait([
        MembershipService().getMemberships(
          page: _currentPage, 
          size: _pageSize, 
          sort: ['membershipNo,asc'],
          query: query,
          memberIds: _currentMemberIds,
        ),
        MembershipService().getMembershipPlans(size: 100),
      ]);

      final membershipsResponse = results[0] as PaginatedResponse<Membership>;
      final plansResponse = results[1] as PaginatedResponse<MembershipPlan>;

      if (mounted) {
        setState(() {
          _memberships = membershipsResponse.content;
          _plans = {for (var p in plansResponse.content) p.id: p};
          _hasMore = !membershipsResponse.last;
        });

        await _fetchPartners(_memberships.map((m) => m.memberId).toList());

        setState(() => _isLoading = false);
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
      final response = await MembershipService().getMemberships(
        page: nextPage, 
        size: _pageSize, 
        sort: ['membershipNo,asc'],
        query: _searchController.text.trim(),
        memberIds: _currentMemberIds,
      );

      if (mounted) {
        final newMemberships = response.content;
        setState(() {
          _currentPage = nextPage;
          _memberships.addAll(newMemberships);
          _hasMore = !response.last;
        });

        await _fetchPartners(newMemberships.map((m) => m.memberId).toList());

        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
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
        title: const Text('Memberships'),
        titleTextStyle: TextStyle(color: colorScheme.onSurface, fontSize: 20, fontWeight: FontWeight.bold),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: false,
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
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddMemberScreen()),
          );
          _fetchInitialData();
        },
        label: const Text('LINK MEMBER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        icon: const Icon(Icons.add_link_rounded),
        elevation: 2,
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search by policy, name or ID...',
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
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade100),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5),
          ),
          fillColor: const Color(0xFFF5F7F9),
          filled: true,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 64, color: colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text('Failed to load memberships', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            FilledButton.icon(
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), shape: BoxShape.circle),
            child: Icon(Icons.contact_emergency_outlined, size: 64, color: Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          Text(_searchController.text.isEmpty ? 'No memberships found' : 'No matches found',
            style: TextStyle(color: Colors.grey[800], fontSize: 18, fontWeight: FontWeight.bold)
          ),
          const SizedBox(height: 8),
          Text(_searchController.text.isEmpty
            ? 'Start by linking a customer to a plan.'
            : 'Try refining your search terms.',
            style: const TextStyle(color: Colors.grey)
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipList(ColorScheme colorScheme) {
    return RefreshIndicator(
      onRefresh: _fetchInitialData,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
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
          final partner = _partners[membership.memberId];

          return _buildMembershipCard(membership, plan, partner, colorScheme);
        },
      ),
    );
  }

  Widget _buildMembershipCard(Membership membership, MembershipPlan? plan, Partner? partner, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => MembershipDetailScreen(membershipId: membership.id)),
            );
            _fetchInitialData();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: colorScheme.primary.withOpacity(0.1),
                      child: Text(
                        partner != null && partner.fullName.isNotEmpty ? partner.fullName[0].toUpperCase() : '?',
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            partner?.fullName ?? 'Loading...',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          Text(
                            'Policy #${membership.membershipNo}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(membership.status),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text(plan?.name ?? 'Plan: ${membership.planId}', 
                      style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                if (partner?.identityNumber != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined, size: 14, color: Colors.grey[400]),
                      const SizedBox(width: 8),
                      Text(partner!.identityNumber, 
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetric('START DATE', membership.startDate ?? '-', Icons.calendar_today_outlined),
                    if (plan != null)
                      _buildMetric('MONTHLY PREMIUM', 'R ${plan.premium.toStringAsFixed(2)}', Icons.payments_outlined, valueColor: colorScheme.primary),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[500], fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'ACTIVE': color = Colors.green; break;
      case 'WAITING-PERIOD':
      case 'UPGRADE-WAITING-PERIOD': color = Colors.orange; break;
      case 'INACTIVE': color = Colors.red; break;
      default: color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.replaceAll('-', ' ').toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
