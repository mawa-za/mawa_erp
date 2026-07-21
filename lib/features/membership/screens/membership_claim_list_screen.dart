import 'dart:async';

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
    'PAYMENT_PENDING': 'Payment pending',
    'PAYMENT_PROCESSING': 'Payment processing',
    'PAYMENT_FAILED': 'Payment failed',
    'REJECTED': 'Rejected',
    'CANCELLED': 'Cancelled',
    'PAID': 'Paid',
  };

  final MembershipService _membershipService = MembershipService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final List<MembershipClaim> _claims = [];

  Timer? _searchDebounce;
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
    _searchDebounce?.cancel();
    _searchController.dispose();
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

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchClaims(reset: true),
    );
    setState(() {});
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
        query: _searchController.text,
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
          _buildSearchBar(),
          _buildStatusFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _fetchClaims(reset: true),
          decoration: InputDecoration(
            hintText: 'Search claim, membership, member or deceased ID',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _fetchClaims(reset: true);
                    },
                  ),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
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
      final search = _searchController.text.trim();
      return Center(
        child: Text(
          search.isEmpty
              ? 'No ${_statuses[_selectedStatus]!.toLowerCase()} claims'
              : 'No claims match “$search”',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchClaims(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _claims.length) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildClaimCard(_claims[index]);
        },
      ),
    );
  }

  Widget _buildClaimCard(MembershipClaim claim) {
    final memberReference = _firstNonEmpty(
      claim.memberIdentityNumber,
      claim.memberNumber,
    );
    final deceasedReference = _firstNonEmpty(
      claim.deceasedIdentityNumber,
      claim.deceasedNumber,
    );

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openClaim(claim),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    child: Text(claim.claimType.isEmpty ? '?' : claim.claimType[0]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.claimNo.isEmpty ? 'Membership claim' : claim.claimNo,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${claim.claimType.replaceAll('_', ' ')} • ${claim.claimDate}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _statusChip(claim.status),
                ],
              ),
              const Divider(height: 24),
              _referenceLine(
                Icons.person_outline,
                'Member',
                claim.memberName,
                memberReference.isEmpty ? null : 'ID / Reg: $memberReference',
              ),
              const SizedBox(height: 10),
              _referenceLine(
                Icons.card_membership_outlined,
                'Membership',
                claim.membershipNo.isEmpty ? 'Not available' : claim.membershipNo,
                null,
              ),
              const SizedBox(height: 10),
              _referenceLine(
                Icons.person_off_outlined,
                'Deceased',
                claim.deceasedName,
                deceasedReference.isEmpty ? null : 'ID / Reg: $deceasedReference',
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'R ${claim.claimAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _referenceLine(
    IconData icon,
    String label,
    String value,
    String? supporting,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey[500]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              Text(
                value.isEmpty ? 'Not available' : value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (supporting != null)
                Text(supporting, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _firstNonEmpty(String first, String second) {
    if (first.trim().isNotEmpty) return first.trim();
    return second.trim();
  }

  Widget _statusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
