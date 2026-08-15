import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mawa_erp/core/errors/app_error.dart';

import '../../../core/utils/app_date_utils.dart';
import '../models/membership_claim.dart';
import '../services/membership_service.dart';
import 'membership_claim_detail_screen.dart';

class MembershipClaimListScreen extends StatefulWidget {
  const MembershipClaimListScreen({super.key});

  @override
  State<MembershipClaimListScreen> createState() => _MembershipClaimListScreenState();
}

class _MembershipClaimListScreenState extends State<MembershipClaimListScreen> {
  static const Map<String, String> _statuses = <String, String>{
    'ALL': 'All',
    'DRAFT': 'Draft',
    'SUBMITTED': 'Submitted',
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
  final List<MembershipClaim> _claims = <MembershipClaim>[];

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
          final aDate = AppDateUtils.parse(a.createdAt);
          final bDate = AppDateUtils.parse(b.createdAt);
          return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(aDate ?? DateTime.fromMillisecondsSinceEpoch(0));
        });
        _page = result.page + 1;
        _lastPage = result.last;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = friendlyErrorMessage(e);
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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Membership Claims'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : () => _fetchClaims(reset: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _buildToolbar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    final count = _claims.length;
    return Material(
      color: Colors.white,
      child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$count ${_selectedStatus == 'ALL' ? '' : '${_statuses[_selectedStatus]!.toLowerCase()} '}claim${count == 1 ? '' : 's'} loaded',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    Text(
                      'Latest first',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
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
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statuses.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final entry = _statuses.entries.elementAt(index);
                      return ChoiceChip(
                        selected: entry.key == _selectedStatus,
                        showCheckmark: false,
                        label: Text(entry.value),
                        onSelected: (_) => _selectStatus(entry.key),
                      );
                    },
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null && _claims.isEmpty) {
      return _ClaimMessageState(
        icon: Icons.error_outline,
        title: 'Unable to load membership claims',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _fetchClaims(reset: true),
      );
    }

    if (_claims.isEmpty) {
      final search = _searchController.text.trim();
      return _ClaimMessageState(
        icon: search.isEmpty ? Icons.assignment_outlined : Icons.search_off,
        title: search.isEmpty ? 'No membership claims' : 'No matching claims',
        message: search.isEmpty
            ? 'There are no ${_statuses[_selectedStatus]!.toLowerCase()} claims to display.'
            : 'No claims match “$search”. Try another search term.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchClaims(reset: true),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _claims.length + (_isLoadingMore ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    final theme = Theme.of(context);
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
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openClaim(claim),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withOpacity(.55),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.assignment_ind_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          claim.claimNo.isEmpty ? 'Membership claim' : claim.claimNo,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_titleCase(claim.claimType)} • ${AppDateUtils.displayDate(claim.claimDate)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'R ${claim.claimAmount.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _statusChip(claim.status),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Wrap(
                spacing: 22,
                runSpacing: 12,
                children: [
                  _meta(
                    Icons.person_outline,
                    'Member',
                    claim.memberName,
                    memberReference.isEmpty ? null : 'ID / Reg: $memberReference',
                  ),
                  _meta(
                    Icons.card_membership_outlined,
                    'Membership',
                    claim.membershipNo,
                    null,
                  ),
                  _meta(
                    Icons.person_off_outlined,
                    'Deceased',
                    claim.deceasedName,
                    deceasedReference.isEmpty ? null : 'ID / Reg: $deceasedReference',
                  ),
                  _meta(
                    Icons.event_outlined,
                    'Date of death',
                    AppDateUtils.displayDate(claim.dateOfDeath),
                    null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(
    IconData icon,
    String label,
    String value,
    String? supporting,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 340),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                Text(
                  value.trim().isEmpty ? 'Not available' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                if (supporting != null)
                  Text(
                    supporting,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _firstNonEmpty(String first, String second) {
    if (first.trim().isNotEmpty) return first.trim();
    return second.trim();
  }

  String _titleCase(String value) {
    if (value.trim().isEmpty) return 'Claim';
    return value
        .replaceAll('_', ' ')
        .toLowerCase()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _statusChip(String status) {
    final color = switch (status.toUpperCase()) {
      'PAID' || 'APPROVED' => Colors.green,
      'REJECTED' || 'CANCELLED' || 'PAYMENT_FAILED' => Colors.red,
      'SUBMITTED' || 'PAYMENT_PENDING' || 'PAYMENT_PROCESSING' => Colors.orange,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        _titleCase(status),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _ClaimMessageState extends StatelessWidget {
  const _ClaimMessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
